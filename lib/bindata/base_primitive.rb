require 'bindata/base'

module BinData
  # A BinData::BasePrimitive object is a container for a value that has a
  # particular binary representation.  A value corresponds to a primitive type
  # such as as integer, float or string.  Only one value can be contained by
  # this object.  This value can be read from or written to an IO stream.
  #
  #   require 'bindata'
  #
  #   obj = BinData::Uint8.new(:initial_value => 42)
  #   obj #=> 42
  #   obj.assign(5)
  #   obj #=> 5
  #   obj.clear
  #   obj #=> 42
  #
  #   obj = BinData::Uint8.new(:value => 42)
  #   obj #=> 42
  #   obj.assign(5)
  #   obj #=> 42
  #
  #   obj = BinData::Uint8.new(:check_value => 3)
  #   obj.read("\005") #=> BinData::ValidityError: value is '5' but expected '3'
  #
  #   obj = BinData::Uint8.new(:check_value => lambda { value < 5 })
  #   obj.read("\007") #=> BinData::ValidityError: value not as expected
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params include those for BinData::Base as well as:
  #
  # [<tt>:initial_value</tt>] This is the initial value to use before one is
  #                           either #read or explicitly set with #value=.
  # [<tt>:value</tt>]         The object will always have this value.
  #                           Calls to #value= are ignored when
  #                           using this param.  While reading, #value
  #                           will return the value of the data read from the
  #                           IO, not the result of the <tt>:value</tt> param.
  # [<tt>:check_value</tt>]   Raise an error unless the value read in meets
  #                           this criteria.  The variable +value+ is made
  #                           available to any lambda assigned to this
  #                           parameter.  A boolean return indicates success
  #                           or failure.  Any other return is compared to
  #                           the value just read in.
  class BasePrimitive < BinData::Base
    unregister_self

    optional_parameters :initial_value, :value, :check_value
    mutually_exclusive_parameters :initial_value, :value

    def initialize_shared_instance
      if has_parameter?(:check_value)
        class << self
          alias_method :do_read_without_check_value, :do_read
          alias_method :do_read, :do_read_with_check_value
        end
      end
      if has_parameter?(:value)
        class << self
          alias_method :_value, :_value_with_value
        end
      end
      if has_parameter?(:initial_value)
        class << self
          alias_method :_value, :_value_with_initial_value
        end
      end
    end

    def initialize_instance
      @value = nil
    end

    def clear #:nodoc:
      @value = nil
    end

    def clear? #:nodoc:
      @value.nil?
    end

    def assign(val)
      raise ArgumentError, "can't set a nil value for #{debug_name}" if val.nil?

      unless has_parameter?(:value)
        raw_val = val.respond_to?(:snapshot) ? val.snapshot : val
        @value = begin
                   raw_val.dup
                 rescue TypeError
                   # can't dup Fixnums
                   raw_val
                 end
      end
    end

    def snapshot
      _value
    end

    def value
      snapshot
    end
    alias_method :value=, :assign

    def respond_to?(symbol, include_private = false) #:nodoc:
      child = snapshot
      child.respond_to?(symbol, include_private) || super
    end

    def method_missing(symbol, *args, &block) #:nodoc:
      child = snapshot
      if child.respond_to?(symbol)
        child.__send__(symbol, *args, &block)
      else
        super
      end
    end

    def <=>(other)
      snapshot <=> other
    end

    def eql?(other)
      # double dispatch
      other.eql?(snapshot)
    end

    def hash
      snapshot.hash
    end

    def do_read(io) #:nodoc:
      @value = read_and_return_value(io)
      hook_after_do_read
    end

    def do_read_with_check_value(io) #:nodoc:
      do_read_without_check_value(io)
      check_value(snapshot)
    end

    def do_write(io) #:nodoc:
      io.writebytes(value_to_binary_string(_value))
    end

    def do_num_bytes #:nodoc:
      value_to_binary_string(_value).length
    end

    #---------------
    private

    def hook_after_do_read; end

    def check_value(current_value)
      expected = eval_parameter(:check_value, :value => current_value)
      if not expected
        raise ValidityError,
              "value '#{current_value}' not as expected for #{debug_name}"
      elsif current_value != expected and expected != true
        raise ValidityError,
              "value is '#{current_value}' but " +
              "expected '#{expected}' for #{debug_name}"
      end
    end

    # The unmodified value of this data object.  Note that #snapshot calls this
    # method.  This indirection is so that #snapshot can be overridden in
    # subclasses to modify the presentation value.
    #
    # Table of possible preconditions and expected outcome
    #   1. :value and !reading?         ->   :value
    #   2. :value and reading?          ->   @value
    #   3. :initial_value and clear?    ->   :initial_value
    #   4. :initial_value and !clear?   ->   @value
    #   5. clear?                       ->   sensible_default
    #   6. !clear?                      ->   @value

    def _value
      @value != nil ? @value : sensible_default()
    end

    def _value_with_value #:nodoc:
      if reading?
        @value
      else
        eval_parameter(:value)
      end
    end

    def _value_with_initial_value #:nodoc:
      @value != nil ? @value : eval_parameter(:initial_value)
    end

    ###########################################################################
    # To be implemented by subclasses

    # Return the string representation that +val+ will take when written.
    def value_to_binary_string(val)
      raise NotImplementedError
    end

    # Read a number of bytes from +io+ and return the value they represent.
    def read_and_return_value(io)
      raise NotImplementedError
    end

    # Return a sensible default for this data.
    def sensible_default
      raise NotImplementedError
    end

    # To be implemented by subclasses
    ###########################################################################
  end
end
