require 'bindata/base'
require 'bindata/sanitize'

module BinData
  # A Choice is a collection of data objects of which only one is active
  # at any particular time.
  #
  #   require 'bindata'
  #
  #   choices = [ [:int8, {:value => 3}], [:int8, {:value => 5}] ]
  #   a = BinData::Choice.new(:choices => choices, :selection => 1)
  #   a.value # => 5
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:choices</tt>::   An array specifying the possible data objects.
  #                       The format of the array is a list of symbols
  #                       representing the data object type.  If a choice
  #                       is to have params passed to it, then it should be
  #                       provided as [type_symbol, hash_params].
  # <tt>:selection</tt>:: An index into the :choices array which specifies
  #                       the currently active choice.
  class Choice < BinData::Base

    # Register this class
    register(self.name, self)

    # These are the parameters used by this class.
    mandatory_parameters :choices, :selection

    class << self
      def sanitize_parameters(params, endian = nil)
        params = params.dup

        if params.has_key?(:choices)
          params[:choices].collect! do |type, param|
            klass = lookup(type, endian)
            raise TypeError, "unknown type '#{type}' for #{self}" if klass.nil?
            [klass, SanitizedParameters.new(klass, param, endian)]
          end
        end

        super(params, endian)
      end

      # Returns all the possible field names a :choice may have.
      def all_possible_field_names(sanitized_params)
        unless SanitizedParameters === sanitized_params
          raise ArgumentError, "parameters aren't sanitized"
        end

        names = []
        sanitized_params[:choices].each do |cklass, cparams|
          names << cklass.all_possible_field_names(cparams)
        end
        names
      end
    end

    def initialize(params = {}, env = nil)
      super(params, env)

      # instantiate all choices
      @choices = []
      param(:choices).each do |choice_klass, choice_params|
        @choices << choice_klass.new(choice_params, create_env)
      end
    end

    # Resets the internal state to that of a newly created object.
    def clear
      the_choice.clear
    end

    # Returns if the selected data object is clear?.
    def clear?
      the_choice.clear?
    end

    # Reads the value of the selected data object from +io+.
    def _do_read(io)
      the_choice.do_read(io)
    end

    # To be called after calling #do_read.
    def done_read
      the_choice.done_read
    end

    # Writes the value of the selected data object to +io+.
    def _write(io)
      the_choice.write(io)
    end

    # Returns the number of bytes it will take to write the
    # selected data object.
    def _num_bytes(what)
      the_choice.num_bytes(what)
    end

    # Returns a snapshot of the selected data object.
    def snapshot
      the_choice.snapshot
    end

    # Returns whether the selected data object is as single value.
    def single_value?
      the_choice.single_value?
    end

    # Returns a list of the names of all fields of the selected data object.
    def field_names
      the_choice.field_names
    end

    # Returns the data object that stores values for +name+.
    def find_obj_for_name(name)
      field_names.include?(name) ? the_choice.find_obj_for_name(name) : nil
    end

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
      index = eval_param(:selection)
      if index < 0 or index >= @choices.length
        raise IndexError, "selection #{index} is out of range"
      end
      @choices[index]
    end
  end
end
