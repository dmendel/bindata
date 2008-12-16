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

      @element_list    = nil
      @element_class   = el_class
      @element_params  = el_params
    end

    def single_value?
      return false
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
        (index < elements.length) ? elements[index].clear? : true
      end
    end

    # Clears the element at position +index+.  If +index+ is not given, then
    # the internal state of the array is reset to that of a newly created
    # object.
    def clear(index = nil)
      if @element_list.nil?
        # do nothing as the array is already clear
      elsif index.nil?
        @element_list = nil
      elsif index < elements.length
        elements[index].clear
      end
    end

    # Appends a new element to the end of the array.  If the array contains
    # single_values then the +value+ may be provided to the call.
    # Returns the appended object, or value in the case of single_values.
    def append(value = nil)
      # TODO: deprecate #append as it can be replaced with #push
      append_new_element
      self[-1] = value unless value.nil?
      self.last
    end

    def index(obj)
      if obj.is_a?(BinData::Base)
        elements.index(obj)
      else
        elements.find_index { |el| el.single_value? ? el.value == obj : false }
      end
    end

    # Pushes the given object(s) on to the end of this array. 
    # This expression returns the array itself, so several appends may 
    # be chained together.
    def push(*args)
      args.each do |arg|
        if @element_class == arg.class
          # TODO: need to modify arg.env to add_variable(:index) and
          # to link arg.env to self.env
          elements.push(arg)
        else
          append(arg)
        end
      end
      self
    end
    alias_method :<<, :push

    # Returns the element at +index+.  If the element is a single_value
    # then the value of the element is returned instead.
    def [](*args)
      if args.length == 1 and ::Integer === args[0]
        # extend array automatically
        while args[0] >= elements.length
          append_new_element
        end
      end

      data = elements[*args]
      if args.length > 1 or ::Range === args[0]
        data.collect { |el| (el && el.single_value?) ? el.value : el }
      else
        (data && data.single_value?) ? data.value : data
      end
    end
    alias_method :slice, :[]

    # Sets the element at +index+.  If the element is a single_value
    # then the value of the element is set instead.
    def []=(index, value)
      # extend array automatically
      while elements.length <= index
        append_new_element
      end

      obj = elements[index]
      unless obj.single_value?
        # TODO: allow setting objects, not just values
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
      if n.nil? and elements.empty?
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

    #---------------
    private

    def _do_read(io)
      if has_param?(:initial_length)
        elements.each { |f| f.do_read(io) }
      elsif has_param?(:read_until)
        if no_eval_param(:read_until) == :eof
          @element_list = nil
          loop do
            element = append_new_element
            begin
              element.do_read(io)
            rescue
              @element_list.pop
              break
            end
          end
        else
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
    end

    def _done_read
      elements.each { |f| f.done_read }
    end

    def _do_write(io)
      elements.each { |f| f.do_write(io) }
    end

    def _do_num_bytes(index)
      if index.nil?
        (elements.inject(0) { |sum, f| sum + f.do_num_bytes }).ceil
      else
        elements[index].do_num_bytes
      end
    end

    def _snapshot
      elements.collect { |e| e.snapshot }
    end

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

      element = @element_class.new(@element_params, self)
      @element_list << element
      element
    end

    def new_element
      @element_class.new(@element_params, self)
    end
  end
end
