require 'forwardable'
require 'bindata/base'
require 'bindata/sanitize'

module BinData
  # A Choice is a collection of data objects of which only one is active
  # at any particular time.  Method calls will be delegated to the active
  # choice.
  #
  #   require 'bindata'
  #
  #   type1 = [:string, {:value => "Type1"}]
  #   type2 = [:string, {:value => "Type2"}]
  #
  #   choices = {5 => type1, 17 => type2}
  #   a = BinData::Choice.new(:choices => choices, :selection => 5)
  #   a.value # => "Type1"
  #
  #   choices = [ type1, type2 ]
  #   a = BinData::Choice.new(:choices => choices, :selection => 1)
  #   a.value # => "Type2"
  #
  #   choices = [ nil, nil, nil, type1, nil, type2 ]
  #   a = BinData::Choice.new(:choices => choices, :selection => 3)
  #   a.value # => "Type1"
  #
  #   mychoice = 'big'
  #   choices = {'big' => :uint16be, 'little' => :uint16le}
  #   a = BinData::Choice.new(:choices => choices,
  #                           :selection => lambda { mychoice })
  #   a.value  = 256
  #   a.to_s #=> "\001\000"
  #   mychoice.replace 'little'
  #   a.selection #=> 'little'
  #   a.to_s #=> "\000\001"
  #
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:choices</tt>::   Either an array or a hash specifying the possible
  #                       data objects.  The format of the array/hash.values is
  #                       a list of symbols representing the data object type.
  #                       If a choice is to have params passed to it, then it
  #                       should be provided as [type_symbol, hash_params].
  #                       An implementation constraint is that the hash may not
  #                       contain symbols as keys.
  # <tt>:selection</tt>:: An index/key into the :choices array/hash which
  #                       specifies the currently active choice.
  class Choice < BinData::Base
    extend Forwardable

    register(self.name, self)

    bindata_mandatory_parameters :choices, :selection

    class << self

      def sanitize_parameters!(sanitizer, params)
        if params.has_key?(:choices)
          choices = choices_as_hash(params[:choices])
          ensure_valid_keys(choices)
          params[:choices] = sanitized_choices(sanitizer, choices)
        end

        super(sanitizer, params)
      end

      #-------------
      private

      def choices_as_hash(choices)
        if choices.respond_to?(:to_ary)
          key_array_by_index(choices.to_ary)
        else
          choices
        end
      end

      def key_array_by_index(array)
        result = {}
        array.each_with_index do |el, i|
          result[i] = el unless el.nil?
        end
        result
      end

      def ensure_valid_keys(choices)
        if choices.has_key?(nil)
          raise ArgumentError, ":choices hash may not have nil key"
        end
        if choices.keys.detect { |k| Symbol === k }
          raise ArgumentError, ":choices hash may not have symbols for keys"
        end
      end

      def sanitized_choices(sanitizer, choices)
        result = {}
        choices.each_pair do |key, val|
          type, param = val
          the_class = sanitizer.lookup_class(type)
          sanitized_params = sanitizer.sanitized_params(the_class, param)
          result[key] = [the_class, sanitized_params]
        end
        result
      end
    end

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @choices = {}
      @last_selection = nil
    end

    # A convenience method that returns the current selection.
    def selection
      eval_param(:selection)
    end

    # This method does not exist. This stub only exists to document why.
    # There is no #selection= method to complement the #selection method.
    # This is deliberate to promote the declarative nature of BinData.
    #
    # If you really *must* be able to programmatically adjust the selection
    # then try something like the following.
    #
    #   class ProgrammaticChoice < BinData::MultiValue
    #     choice :data, :choices => :choices, :selection => :selection
    #     attrib_accessor :selection
    #   end
    #
    #   type1 = [:string, {:value => "Type1"}]
    #   type2 = [:string, {:value => "Type2"}]
    #
    #   choices = {5 => type1, 17 => type2}
    #   pc = ProgrammaticChoice.new(:choices => choices)
    #
    #   pc.selection = 5
    #   pc.data #=> "Type1"
    #
    #   pc.selection = 17
    #   pc.data #=> "Type2"
    def selection=(v)
      raise NoMethodError
    end

    # A choice represents a specific object.
    def obj
      #TODO: this should be as written, but I can't work out how to make
      # a failing test case with just "return current_choice"
      current_choice.obj
    end

    def_delegators :current_choice, :clear, :clear?, :single_value?
    def_delegators :current_choice, :_do_read, :_done_read, :_do_write
    def_delegators :current_choice, :_do_num_bytes, :_snapshot

    def respond_to?(symbol, include_private = false)
      super || current_choice.respond_to?(symbol, include_private)
    end

    def method_missing(symbol, *args, &block)
      if current_choice.respond_to?(symbol)
        current_choice.__send__(symbol, *args, &block)
      else
        super
      end
    end

    #---------------
    private

    def current_choice
      selection = eval_param(:selection)
      raise IndexError, ":selection returned nil value" if selection.nil?

      obj = get_or_instantiate_choice(selection)
      retain_previous_value_if_single(selection, obj)

      obj
    end

    def get_or_instantiate_choice(selection)
      obj = @choices[selection]
      if obj.nil?
        obj = instantiate_choice(selection)
        @choices[selection] = obj
      end
      obj
    end

    def instantiate_choice(selection)
      choice_class, choice_params = no_eval_param(:choices)[selection]
      if choice_class.nil?
        raise IndexError, "selection #{selection} does not exist in :choices"
      end
      choice_class.new(choice_params, self)
    end

    def retain_previous_value_if_single(selection, obj)
      prev = get_previous_choice(selection)
      if should_retain_value?(prev, obj)
        obj.value = prev.value
      end
      remember_current_selection(selection)
    end

    def should_retain_value?(prev, cur)
      prev != nil and prev.single_value? and cur.single_value?
    end

    def get_previous_choice(selection)
      if selection != @last_selection and @last_selection != nil
        @choices[@last_selection]
      else
        nil
      end
    end

    def remember_current_selection(selection)
      if selection != @last_selection
        @last_selection = selection
      end
    end
  end
end
