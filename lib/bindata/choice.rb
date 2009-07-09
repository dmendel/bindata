require 'bindata/base'
require 'bindata/trace'

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
  #   a.to_binary_s #=> "\001\000"
  #   mychoice.replace 'little'
  #   a.selection #=> 'little'
  #   a.to_binary_s #=> "\000\001"
  #
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:choices</tt>::        Either an array or a hash specifying the possible
  #                            data objects.  The format of the
  #                            array/hash.values is a list of symbols
  #                            representing the data object type.  If a choice
  #                            is to have params passed to it, then it should
  #                            be provided as [type_symbol, hash_params].  An
  #                            implementation constraint is that the hash may
  #                            not contain symbols as keys.
  # <tt>:selection</tt>::      An index/key into the :choices array/hash which
  #                            specifies the currently active choice.
  # <tt>:copy_on_change</tt>:: If set to true, copy the value of the previous
  #                            selection to the current selection whenever the
  #                            selection changes.  Default is false.
  class Choice < BinData::Base

    register(self.name, self)

    mandatory_parameters :choices, :selection
    optional_parameter   :copy_on_change

    class << self

      def sanitize_parameters!(params, sanitizer)
        if params.needs_sanitizing?(:choices)
          choices = choices_as_hash(params[:choices])
          ensure_valid_keys(choices)
          params[:choices] = sanitizer.create_sanitized_choices(choices)
        end
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
        if choices.keys.detect { |key| key.is_a?(Symbol) }
          raise ArgumentError, ":choices hash may not have symbols for keys"
        end
      end
    end

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @choices = {}
      @last_selection = nil
    end

    # A convenience method that returns the current selection.
    def selection
      eval_parameter(:selection)
    end

    # This method does not exist. This stub only exists to document why.
    # There is no #selection= method to complement the #selection method.
    # This is deliberate to promote the declarative nature of BinData.
    #
    # If you really *must* be able to programmatically adjust the selection
    # then try something like the following.
    #
    #   class ProgrammaticChoice < BinData::Wrapper
    #     choice :selection => :selection
    #     attr_accessor :selection
    #   end
    #
    #   type1 = [:string, {:value => "Type1"}]
    #   type2 = [:string, {:value => "Type2"}]
    #
    #   choices = {5 => type1, 17 => type2}
    #   pc = ProgrammaticChoice.new(:choices => choices)
    #
    #   pc.selection = 5
    #   pc #=> "Type1"
    #
    #   pc.selection = 17
    #   pc #=> "Type2"
    def selection=(v)
      raise NoMethodError
    end

    def clear
      current_choice.clear
    end

    def clear?
      current_choice.clear?
    end

    def debug_name_of(child)
      debug_name
    end

    def offset_of(child)
      offset
    end

    def respond_to?(symbol, include_private = false)
      super || current_choice.respond_to?(symbol, include_private)
    end

    def method_missing(symbol, *args, &block)
      current_choice.__send__(symbol, *args, &block)
    end

    #---------------
    private

    def _do_read(io)
      trace_selection
      current_choice.do_read(io)
    end

    def trace_selection
      BinData::trace_message do |tracer|
        selection_string = eval_parameter(:selection).inspect
        if selection_string.length > 30
          selection_string = selection_string.slice(0 .. 30) + "..."
        end

        tracer.trace("#{debug_name}-selection- => #{selection_string}")
      end
    end

    def _done_read
      current_choice.done_read
    end

    def _do_write(io)
      current_choice.do_write(io)
    end

    def _do_num_bytes(deprecated)
      current_choice.do_num_bytes(deprecated)
    end

    def _assign(val)
      current_choice.assign(val)
    end

    def _snapshot
      current_choice.snapshot
    end

    def current_choice
      selection = eval_parameter(:selection)
      if selection.nil?
        raise IndexError, ":selection returned nil for #{debug_name}"
      end

      obj = get_or_instantiate_choice(selection)
      copy_previous_value_if_required(selection, obj)

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
      prototype = get_parameter(:choices)[selection]
      if prototype.nil?
        raise IndexError, "selection '#{selection}' does not exist in :choices for #{debug_name}"
      end
      prototype.instantiate(self)
    end

    def copy_previous_value_if_required(selection, obj)
      prev = get_previous_choice(selection)
      if should_copy_value?(prev, obj)
        obj.assign(prev)
      end
      remember_current_selection(selection)
    end

    def should_copy_value?(prev, cur)
      prev != nil and eval_parameter(:copy_on_change) == true
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
