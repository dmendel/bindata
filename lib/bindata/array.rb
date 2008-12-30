require 'bindata/base'
require 'bindata/sanitize'

module BinData
  # An Array is a list of data objects of the same type.
  #
  #   require 'bindata'
  #
  #   data = "\x03\x04\x05\x06\x07\x08\x09"
  #
  #   obj = BinData::Array.new(:type => :int8, :initial_length => 6)
  #   obj.read(data)
  #   obj.snapshot #=> [3, 4, 5, 6, 7, 8]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #                            :read_until => lambda { index == 1 })
  #   obj.read(data)
  #   obj.snapshot #=> [3, 4]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #                            :read_until => lambda { element >= 6 })
  #   obj.read(data)
  #   obj.snapshot #=> [3, 4, 5, 6]
  #
  #   obj = BinData::Array.new(:type => :int8,
  #           :read_until => lambda { array[index] + array[index - 1] == 13 })
  #   obj.read(data)
  #   obj.snapshot #=> [3, 4, 5, 6, 7]
  #
  #   obj = BinData::Array.new(:type => :int8, :read_until => :eof)
  #   obj.read(data)
  #   obj.snapshot #=> [3, 4, 5, 6, 7, 8, 9]
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
  #                            this parameter.  If the value of this parameter
  #                            is the symbol :eof, then the array will read
  #                            as much data from the stream as possible.
  #
  # Each data object in an array has the variable +index+ made available
  # to any lambda evaluated as a parameter of that data object.
  class Array < BinData::Base
    include Enumerable

    register(self.name, self)

    bindata_mandatory_parameter :type
    bindata_optional_parameters :initial_length, :read_until
    bindata_mutually_exclusive_parameters :initial_length, :read_until

    class << self

      def sanitize_parameters!(sanitizer, params)
        unless params.has_key?(:initial_length) or params.has_key?(:read_until)
          # ensure one of :initial_length and :read_until exists
          params[:initial_length] = 0
        end

        if params.has_key?(:read_length)
          warn ":read_length is not used with arrays.  " +
               "You probably want to change this to :initial_length"
        end

        if params.has_key?(:type)
          type, el_params = params[:type]
          klass = sanitizer.lookup_class(type)
          sanitized_params = sanitizer.sanitized_params(klass, el_params)
          params[:type] = [klass, sanitized_params]
        end

        super(sanitizer, params)
      end
    end

    def initialize(params = {}, parent = nil)
      super(params, parent)

      el_class, el_params = no_eval_param(:type)

      @element_list    = []
      @element_class   = el_class
      @element_params  = el_params
    end

    def single_value?
      return false
    end

    # Returns if the element at position +index+ is clear?.  If +index+
    # is not given, then returns whether all elements are clear.
    def clear?(index = nil)
      if index.nil?
        elements.inject(true) { |all_clear, f| all_clear and f.clear? }
      elsif index < elements.length
        elements[index].clear?
      else
        true
      end
    end

    # Clears the element at position +index+.  If +index+ is not given, then
    # the internal state of the array is reset to that of a newly created
    # object.
    def clear(index = nil)
      if index.nil?
        @element_list.clear
      elsif index < elements.length
        elements[index].clear
      end
    end

    # Returns the first index of +obj+ in self.
    #
    # a = BinData::String.new; a.value = "a"
    # b = BinData::String.new; b.value = "b"
    # c = BinData::String.new; c.value = "c"
    #
    # arr = BinData::Array.new(:type => :string)
    # arr.push(a, b, c)
    #
    # arr.find_index("b") #=> 1
    # arr.find_index(c) #=> 2
    #
    def find_index(obj)
      if obj.is_a?(BinData::Base)
        elements.find_index(obj)
      else
        elements.find_index { |el| el.single_value? ? el.value == obj : false }
      end
    end
    alias_method :index, :find_index


    def push(*args)
      insert(-1, *args)
      self
    end
    alias_method :<<, :push

    def unshift(*args)
      insert(0, *args)
      self
    end

    def concat(array)
      insert(-1, *array.to_ary)
      self
    end

    def insert(index, *objs)
      extend_array(index - 1)
      elements.insert(index, *to_storage_formats(objs))
      self
    end

    def append(value = nil)
      warn "#append is deprecated, use push or slice instead"
      if value.nil?
        slice(length)
      else
        push(value)
      end
      self.last
    end

    # Returns the element at +index+.  If the element is a single_value
    # then the value of the element is returned instead.
    def [](arg1, arg2 = nil)
      if arg1.respond_to?(:to_int) and arg2.nil?
        slice_index(arg1.to_int)
      elsif arg1.respond_to?(:to_int) and arg2.respond_to?(:to_int)
        slice_start_length(arg1.to_int, arg2.to_int)
      elsif arg1.is_a?(Range) and arg2.nil?
        slice_range(arg1)
      else
        raise TypeError, "can't convert #{arg1} into Integer" unless arg1.respond_to?(:to_int)
        raise TypeError, "can't convert #{arg2} into Integer" unless arg2.respond_to?(:to_int)
      end
    end
    alias_method :slice, :[]

    def slice_index(index)
      extend_array(index)
      at(index)
    end

    def slice_start_length(start, length)
      from_storage_formats(elements[start, length])
    end

    def slice_range(range)
      from_storage_formats(elements[range])
    end
    private :slice_index, :slice_start_length, :slice_range

    # Returns the element at +index+.  If the element is a single_value
    # then the value of the element is returned instead.  Unlike +slice+,
    # if +index+ is out of range the array will not be automatically extended.
    def at(index)
      from_storage_format(elements[index])
    end

    # Sets the element at +index+.  If the array type is a single_value
    # then the value of the element will be set.
    def []=(index, value)
      extend_array(index)
      elements[index] = to_storage_format(value)
    end

    # Returns the first element, or the first +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def first(n = nil)
      if n.nil? and empty?
        # explicitly return nil as arrays grow automatically
        nil
      elsif n.nil?
        self[0]
      else
        self[0, n]
      end
    end

    # Returns the last element, or the last +n+ elements, of the array.
    # If the array is empty, the first form returns nil, and the second
    # form returns an empty array.
    def last(n = nil)
      if n.nil?
        self[-1]
      else
        n = length if n > length
        self[-n, n]
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

    # Iterate over each element in the array.  If the elements are
    # single_values then the values of the elements are iterated instead.
    def each
      elements.each { |el| yield from_storage_format(el) }
    end

    #---------------
    private

    def extend_array(max_index)
      max_length = max_index + 1
      while elements.length < max_length
        append_new_element
      end
    end

    def to_storage_formats(els)
      els.collect { |el| to_storage_format(el) }
    end

    def to_storage_format(obj)
      if obj.is_a?(BinData::Base) and obj.class != @element_class
        warn "maybe this will work, maybe not"
      end

      if obj.is_a?(BinData::Base)
        obj.parent = self
        obj
      else
        element = new_element
        element.value = obj
        element
      end
    rescue
      raise ArgumentError, "Can not convert #{obj} to BinData::Base"
    end

    def from_storage_formats(els)
      return nil if els.nil?

      els.collect { |el| from_storage_format(el) }
    end

    def from_storage_format(el)
      if el and el.single_value?
        el.value
      else
        el
      end
    end


    def _do_read(io)
      if has_param?(:initial_length)
        elements.each { |f| f.do_read(io) }
      elsif has_param?(:read_until)
        read_until(io)
      end
    end

    def read_until(io)
      if no_eval_param(:read_until) == :eof
        read_until_eof(io)
      else
        read_until_condition(io)
      end
    end

    def read_until_eof(io)
      finished = false
      while not finished
        element = append_new_element
        begin
          element.do_read(io)
        rescue
          @element_list.pop
          finished = true
        end
      end
    end

    def read_until_condition(io)
      finished = false
      while not finished
        element = append_new_element
        element.do_read(io)
        variables = { :index => self.length - 1, :element => self.last,
                      :array => self }
        finished = eval_param(:read_until, variables)
      end
    end

    def _done_read
      elements.each { |f| f.done_read }
    end

    def _do_write(io)
      elements.each { |f| f.do_write(io) }
    end

    def _do_num_bytes(index)
      if index.nil?
        total = elements.inject(0) { |sum, f| sum + f.do_num_bytes }
        total.ceil
      elsif index < elements.length
        elements[index].do_num_bytes
      else
        0
      end
    end

    def _snapshot
      elements.collect { |e| e.snapshot }
    end

    def elements
      if @element_list.empty? and has_param?(:initial_length)
        eval_param(:initial_length).times do
          @element_list << new_element
        end
      end
      @element_list
    end

    def append_new_element
      element = new_element
      elements << element
      element
    end

    def new_element
      @element_class.new(@element_params, self)
    end
  end
end
