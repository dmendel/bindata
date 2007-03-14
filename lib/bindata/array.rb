require 'bindata/base'

module BinData
  # An Array is a list of data objects of the same type.
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:type</tt>::           The symbol representing the data type of the
  #                            array elements.  If the type is to have params
  #                            passed to it, then it should be provided as
  #                            [type_symbol, hash_params].
  # <tt>:initial_length</tt>:: The initial length of the array.
  class Array < Base
    include Enumerable

    # Register this class
    register(self.name, self)

    # These are the parameters used by this class.
    mandatory_parameters :type, :initial_length

    # Creates a new Array
    def initialize(params = {}, env = nil)
      super(params, env)

      type, el_params = param(:type)
      klass = self.class.lookup(type)
      raise TypeError, "unknown type '#{type}' for #{self}" if klass.nil?

      @element_list    = nil
      @element_klass   = klass
      @element_params  = el_params || {}

      # TODO: how to increase the size of the array?
    end

    # Clears the element at position +index+.  If +index+ is not given, then
    # the internal state of the array is reset to that of a newly created
    # object.
    def clear(index = nil)
      if @element_list.nil?
        # do nothing as the array is already clear
      elsif index.nil?
        @element_list = nil
      else
        elements[index].clear
      end
    end

    # Returns if the element at position +index+ is clear?.  If +index+
    # is not given, then returns whether all fields are clear.
    def clear?(index = nil)
      if @element_list.nil?
        true
      elsif index.nil?
        elements.each { |f| return false if not f.clear? }
        true
      else
        elements[index].clear?
      end
    end

    # Reads the values for all fields in this object from +io+.
    def _do_read(io)
      elements.each { |f| f.do_read(io) }
    end

    # To be called after calling #do_read.
    def done_read
      elements.each { |f| f.done_read }
    end

    # Writes the values for all fields in this object to +io+.
    def _write(io)
      elements.each { |f| f.write(io) }
    end

    # Returns the number of bytes it will take to write the element at
    # +index+.  If +index+, then returns the number of bytes required
    # to write all fields.
    def _num_bytes(index)
      if index.nil?
        elements.inject(0) { |sum, f| sum + f.num_bytes }
      else
        elements[index].num_bytes
      end
    end

    # Returns a snapshot of the data in this array.
    def snapshot
      elements.collect { |e| e.snapshot }
    end

    # An array has no fields.
    def field_names
      []
    end

    # Returns the element at +index+.  If the element is a single_value
    # then the value of the element is returned instead.
    def [](index)
      obj = elements[index]
      obj.single_value? ? obj.value : obj
    end

    # Sets the element at +index+.  If the element is a single_value
    # then the value of the element is set instead.
    def []=(index, value)
      obj = elements[index]
      unless obj.single_value?
        raise NoMethodError, "undefined method `[]=' for #{self}", caller
      end
      obj.value = value
    end

    # Iterate over each element in the array.  If the elements are
    # single_values then the values of the elements are iterated instead.
    def each
      elements.each do |el|
        yield(el.single_value? ? el.value : el)
      end
    end

    # The number of elements in this array.
    def length
      elements.length
    end
    alias_method :size, :length

    #---------------
    private

    # Returns the list of all elements in the array.  The elements
    # will be instantiated on the first call to this method.
    def elements
      if @element_list.nil?
        @element_list = []

        # create the desired number of instances
        eval_param(:initial_length).times do |i|
          env = create_env
          env.index = i
          @element_list << @element_klass.new(@element_params, env)
        end
      end
      @element_list
    end
  end
end
