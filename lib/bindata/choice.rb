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
  #                       An implementation gotcha is that the hash may not
  #                       contain symbols as keys.
  # <tt>:selection</tt>:: An index/key into the :choices array/hash which
  #                       specifies the currently active choice.
  class Choice < BinData::Base
    extend Forwardable

    # Register this class
    register(self.name, self)

    # These are the parameters used by this class.
    mandatory_parameters :choices, :selection

    class << self

      # Ensures that +params+ is of the form expected by #initialize.
      def sanitize_parameters!(sanitizer, params)
        if params.has_key?(:choices)
          choices = params[:choices]

          # convert array to hash keyed by index
          if ::Array === choices
            tmp = {}
            choices.each_with_index do |el, i|
              tmp[i] = el unless el.nil?
            end
            choices = tmp
          end

          # ensure valid hash keys
          if choices.has_key?(nil)
            raise ArgumentError, ":choices hash may not have nil key"
          end
          if choices.keys.detect { |k| Symbol === k }
            raise ArgumentError, ":choices hash may not have symbols for keys"
          end

          # sanitize each choice
          new_choices = {}
          choices.each_pair do |key, val|
            type, param = val
            klass = sanitizer.lookup_klass(type)
            sanitized_params = sanitizer.sanitize_params(klass, param)
            new_choices[key] = [klass, sanitized_params]
          end
          params[:choices] = new_choices
        end

        super(sanitizer, params)
      end
    end

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @choices  = {}
      @last_key = nil
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
      the_choice
    end

    def_delegators :the_choice, :clear, :clear?, :single_value?
    def_delegators :the_choice, :done_read, :_snapshot
    def_delegators :the_choice, :_do_read, :_do_write, :_do_num_bytes

    # Override to include selected data object.
    def respond_to?(symbol, include_private = false)
      super || the_choice.respond_to?(symbol, include_private)
    end

    def method_missing(symbol, *args, &block)
      if the_choice.respond_to?(symbol)
        the_choice.__send__(symbol, *args, &block)
      else
        super
      end
    end

    #---------------
    private

    # Returns the selected data object.
    def the_choice
      key = eval_param(:selection)

      if key.nil?
        raise IndexError, ":selection returned nil value"
      end

      obj = @choices[key]
      if obj.nil?
        # instantiate choice object
        choice_klass, choice_params = no_eval_param(:choices)[key]
        if choice_klass.nil?
          raise IndexError, "selection #{key} does not exist in :choices"
        end
        obj = choice_klass.new(choice_params, self)
        @choices[key] = obj
      end

      # for single_values copy the value when the selected object changes
      if key != @last_key
        if @last_key != nil
          prev = @choices[@last_key]
          if prev != nil and prev.single_value? and obj.single_value?
            obj.value = prev.value
          end
        end
        @last_key = key
      end

      obj
    end
  end
end
