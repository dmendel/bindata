require 'bindata/base'

module BinData
  # An Array is a list of data objects of the same type.
  #
  #   require 'bindata'
  #   require 'stringio'
  #
  #   a = BinData::Array.new(:type => :int8, :initial_length => 5)
  #   io = StringIO.new("\x03\x04\x05\x06\x07")
  #   a.read(io)
  #   a.snapshot #=> [3, 4, 5, 6, 7]
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:type</tt>::           The symbol representing the data type of the
  #                            array elements.  If the type is to have params
  #                            passed to it, then it should be provided as
  #                            <tt>[type_symbol, hash_params]</tt>.
  # <tt>:initial_length</tt>:: The initial length of the array.
  # <tt>:read_until</tt>::     While reading, elements are read until this
  #                            condition is true.  This is typically used to
  #                            read an array until a sentinel value is found.
  #                            The variables +index+, +element+ and +array+
  #                            are made available to any lambda assigned to
  #                            this parameter.
  #
  # Each data object in an array has the variable +index+ made available
  # to any lambda evaluated as a parameter of that data object.
  class Array < Base
    include Enumerable

    # Register this class
    register(self.name, self)

    # These are the parameters used by this class.
    mandatory_parameter :type
    optional_parameters :initial_length, :read_until

    # Creates a new Array
    def initialize(params = {}, env = nil)
      super(cleaned_params(params), env)
      ensure_mutual_exclusion(:initial_length, :read_until)

      type, el_params = param(:type)
      klass = klass_lookup(type)
      raise TypeError, "unknown type '#{type}' for #{self}" if klass.nil?

      @element_list    = nil
      @element_klass   = klass
      @element_params  = el_params || {}
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
      if has_param?(:initial_length)
        elements.each { |f| f.do_read(io) }
      else # :read_until
        @element_list = nil
        loop do
          element = append_new_element
          element.do_read(io)
          variables = { :index => self.length - 1, :element => self.last,
                        :array => self }
          finished = eval_param(:read_until, variables)
          break if finished
        end
      end
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

    # Appends a new element to the end of the array.  If the array contains
    # single_values then the +value+ may be provided to the call.
    # Returns the appended object, or value in the case of single_values.
    def append(value = nil)
      append_new_element
      self[self.length - 1] = value unless value.nil?
      self.last
    end

    # Returns the element at +index+.  If the element is a single_value
    # then the value of the element is returned instead.
    def [](*index)
      data = elements[*index]
      if data.respond_to?(:each)
        data.collect { |el| el.single_value? ? el.value : el }
      else
        data.single_value? ? data.value : data
      end
    end
    alias_method :slice, :[]

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

    # Returns the first element, or the first +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def first(n = nil)
      if n.nil?
        self.length.zero? ? nil : self[0]
      else
        array = []
        [n, self.length].min.times do |i|
          array.push(self[i])
        end
        array
      end
    end

    # Returns the last element, or the last +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def last(n = nil)
      if n.nil?
        self.length.zero? ? nil : self[self.length - 1]
      else
        array = []
        start = self.length - [n, self.length].min
        start.upto(self.length - 1) do |i|
          array.push(self[i])
        end
        array
      end
    end

    # The number of elements in this array.
    def length
      elements.length
    end
    alias_method :size, :length

    # Returns true if self array contains no elements.
    def empty?
      length.zero?
    end

    # Allow this object to be used in array context.
    def to_ary
      snapshot
    end

    #---------------
    private

    # Returns the list of all elements in the array.  The elements
    # will be instantiated on the first call to this method.
    def elements
      if @element_list.nil?
        @element_list = []
        if has_param?(:initial_length)
          # create the desired number of instances
          eval_param(:initial_length).times do
            append_new_element
          end
        end
      end
      @element_list
    end

    # Creates a new element and appends it to the end of @element_list.
    # Returns the newly created element
    def append_new_element
      # ensure @element_list is initialised
      elements()

      env = create_env
      env.add_variable(:index, @element_list.length)
      element = @element_klass.new(@element_params, env)
      @element_list << element
      element
    end

    # Returns a hash of cleaned +params+.  Cleaning means that param
    # values are converted to a desired format.
    def cleaned_params(params)
      unless params.has_key?(:initial_length) or params.has_key?(:read_until)
        # ensure one of :initial_length and :read_until exists
        new_params = params.dup
        new_params[:initial_length] = 0
        params = new_params
      end
      params
    end
  end
end
