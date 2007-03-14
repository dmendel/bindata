require 'bindata/base'

module BinData
  # A BinData::Single object is a container for a value that has a particular
  # binary representation.  A value corresponds to a primitive type such as
  # as integer, float or string.  Only one value can be contained by this
  # object.  This value can be read from or written to an IO stream.
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # [<tt>:initial_value</tt>] This is the initial value to use before one is
  #                           either #read or explicitly set with #value=.
  # [<tt>:value</tt>]         The object will always have this value.
  #                           Explicitly calling #value= is prohibited when
  #                           using this param.  In the interval between
  #                           calls to #do_read and #done_read, #value
  #                           will return the value of the data read from the
  #                           IO, not the result of the <tt>:value</tt> param.
  # [<tt>:check_value</tt>]   Raise an error unless the value read in meets
  #                           this criteria.  A boolean return indicates
  #                           success or failure.  Any other return is compared
  #                           to the value just read in.
  class Single < Base
    # These are the parameters used by this class.
    optional_parameters :initial_value, :value, :check_value

    # Register the names of all subclasses of this class.
    def self.inherited(subclass) #:nodoc:
      register(subclass.name, subclass)
    end

    def initialize(params = {}, env = nil)
      super(params, env)
      ensure_mutual_exclusion(:initial_value, :value)
      clear
    end

    # Resets the internal state to that of a newly created object.
    def clear
      @value = nil
      @in_read = false
    end

    # Returns if the value of this data has been read or explicitly set.
    def clear?
      @value.nil?
    end

    # Reads the value for this data from +io+.
    def _do_read(io)
      @in_read = true
      @value   = read_val(io)

      # does the value meet expectations?
      if has_param?(:check_value)
        expected = eval_param(:check_value)
        if not expected
          raise ValidityError, "value not as expected"
        elsif @value != expected and expected != true
          raise ValidityError, "value is '#{@value}' but " +
                               "expected '#{expected}'"
        end
      end
    end

    # To be called after calling #do_read.
    def done_read
      @in_read = false
    end

    # Writes the value for this data to +io+.
    def _write(io)
      raise "can't write whilst reading" if @in_read
      io.write(val_to_str(_value))
    end

    # Returns the number of bytes it will take to write this data.
    def _num_bytes(ignored)
      val_to_str(_value).length
    end

    # Returns a snapshot of this data object.
    def snapshot
      value
    end

    # Single objects don't contain fields.
    def field_names
      []
    end

    # Returns the current value of this data.
    def value
      _value
    end

    # Sets the value of this data.
    def value=(v)
      # only allow modification if the value isn't predefined
      unless has_param?(:value)
        raise ArgumentError, "can't set a nil value" if v.nil?
        @value = v
      end
    end

    #---------------
    private

    # The unmodified value of this data object.  Note that #value calls this
    # method.  This is so that #value can be overridden in subclasses to 
    # modify the value.
    def _value
      # Table of possible preconditions and expected outcome
      #   1. :value and !in_read          ->   :value
      #   2. :value and in_read           ->   @value
      #   3. :initial_value and clear?    ->   :initial_value
      #   4. :initial_value and !clear?   ->   @value
      #   5. clear?                       ->   sensible_default
      #   6. !clear?                      ->   @value

      if not @in_read and (evaluated_value = eval_param(:value))
        # rule 1 above
        evaluated_value
      else
        # combining all other rules gives this simplified expression
        @value || eval_param(:value) ||
          eval_param(:initial_value) || sensible_default()
      end
    end

    # Usuable by subclasses

    # Reads exactly +n+ bytes from +io+.  This should be used by subclasses
    # in preference to <tt>io.read(n)</tt>.
    #
    # If the data read is nil an EOFError is raised.
    #
    # If the data read is too short an IOError is raised.
    def readbytes(io, n)
      str = io.read(n)
      raise EOFError, "End of file reached" if str == nil
      raise IOError, "data truncated" if str.size < n
      str
    end

=begin
    # To be implemented by subclasses

    # Return the string representation that +val+ will take when written.
    def val_to_str(val)
      raise NotImplementedError
    end

    # Read a number of bytes from +io+ and return the value they represent.
    def read_val(io)
      raise NotImplementedError
    end

    # Return a sensible default for this data.
    def sensible_default
      raise NotImplementedError
    end

    # To be implemented by subclasses
=end
  end
end
