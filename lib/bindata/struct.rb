require 'bindata/base'

module BinData

  class Base
    optional_parameter :onlyif  # Used by Struct
  end

  # A Struct is an ordered collection of named data objects.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::Record
  #      int8  :x
  #      int8  :y
  #      int8  :z
  #    end
  #
  #    obj = BinData::Struct.new(:hide => :a,
  #                              :fields => [ [:int32le, :a],
  #                                           [:int16le, :b],
  #                                           [:tuple, :s] ])
  #    obj.field_names   =># [:b, :s]
  #
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:fields</tt>::   An array specifying the fields for this struct.
  #                      Each element of the array is of the form [type, name,
  #                      params].  Type is a symbol representing a registered
  #                      type.  Name is the name of this field.  Params is an
  #                      optional hash of parameters to pass to this field
  #                      when instantiating it.  If name is "" or nil, then
  #                      that field is anonymous and behaves as a hidden field.
  # <tt>:hide</tt>::     A list of the names of fields that are to be hidden
  #                      from the outside world.  Hidden fields don't appear
  #                      in #snapshot or #field_names but are still accessible
  #                      by name.
  # <tt>:endian</tt>::   Either :little or :big.  This specifies the default
  #                      endian of any numerics in this struct, or in any
  #                      nested data objects.
  #
  # == Field Parameters
  #
  # Fields may have have extra parameters as listed below:
  #
  # [<tt>:onlyif</tt>]   Used to indicate a data object is optional.
  #                      if +false+, this object will not be included in any
  #                      calls to #read, #write, #num_bytes or #snapshot.
  class Struct < BinData::Base

    mandatory_parameter :fields
    optional_parameters :endian, :hide

    # These reserved words may not be used as field names
    RESERVED = Hash[*
                 (Hash.instance_methods +
                  %w{alias and begin break case class def defined do else elsif
                     end ensure false for if in module next nil not or redo
                     rescue retry return self super then true undef unless until
                     when while yield} +
                  %w{array element index value} ).collect { |name| name.to_sym }.
                  uniq.collect { |key| [key, true] }.flatten
               ]

    class << self

      def sanitize_parameters!(params) #:nodoc:
        sanitize_endian(params)
        sanitize_fields(params)
        sanitize_hide(params)
      end

      #-------------
      private

      def sanitize_endian(params)
        if params.needs_sanitizing?(:endian)
          endian = params.create_sanitized_endian(params[:endian])
          params[:endian] = endian
          params.endian   = endian # sync params[:endian] and params.endian
        end
      end

      def sanitize_fields(params)
        if params.needs_sanitizing?(:fields)
          fields = params[:fields]

          params[:fields] = params.create_sanitized_fields
          fields.each do |ftype, fname, fparams|
            params[:fields].add_field(ftype, fname, fparams)
          end

          field_names = sanitized_field_names(params[:fields])
          ensure_field_names_are_valid(field_names)
        end
      end

      def sanitize_hide(params)
        if params.needs_sanitizing?(:hide) and params.has_parameter?(:fields)
          field_names  = sanitized_field_names(params[:fields])
          hfield_names = hidden_field_names(params[:hide])

          params[:hide] = (hfield_names & field_names)
        end
      end

      def sanitized_field_names(sanitized_fields)
        sanitized_fields.field_names.compact
      end

      def hidden_field_names(hidden)
        (hidden || []).collect { |h| h.to_sym }
      end

      def ensure_field_names_are_valid(field_names)
        reserved_names = RESERVED

        field_names.each do |name|
          if self.class.method_defined?(name)
            raise NameError.new("Rename field '#{name}' in #{self}, " +
                                "as it shadows an existing method.", name)
          end
          if reserved_names.include?(name)
            raise NameError.new("Rename field '#{name}' in #{self}, " +
                                "as it is a reserved name.", name)
          end
          if field_names.count(name) != 1
            raise NameError.new("field '#{name}' in #{self}, " +
                                "is defined multiple times.", name)
          end
        end
      end
    end

    def initialize_shared_instance
      @field_names = get_parameter(:fields).field_names.freeze
      super
    end

    def initialize_instance
      @field_objs  = []
    end

    def clear #:nodoc:
      @field_objs.each { |f| f.clear unless f.nil? }
    end

    def clear? #:nodoc:
      @field_objs.all? { |f| f.nil? or f.clear? }
    end

    def assign(val)
      clear
      assign_fields(val)
    end

    def snapshot
      snapshot = Snapshot.new
      field_names.each do |name|
        obj = find_obj_for_name(name)
        snapshot[name] = obj.snapshot if include_obj(obj)
      end
      snapshot
    end

    # Returns a list of the names of all fields accessible through this
    # object.  +include_hidden+ specifies whether to include hidden names
    # in the listing.
    def field_names(include_hidden = false)
      if include_hidden
        @field_names.compact
      else
        hidden = get_parameter(:hide) || []
        @field_names.compact - hidden
      end
    end

    def respond_to?(symbol, include_private = false) #:nodoc:
      @field_names.include?(base_field_name(symbol)) || super
    end

    def method_missing(symbol, *args, &block) #:nodoc:
      obj = find_obj_for_name(symbol)
      if obj
        invoke_field(obj, symbol, args)
      else
        super
      end
    end

    def debug_name_of(child) #:nodoc:
      field_name = @field_names[find_index_of(child)]
      "#{debug_name}.#{field_name}"
    end

    def offset_of(child) #:nodoc:
      instantiate_all_objs
      sum = sum_num_bytes_below_index(find_index_of(child))
      child.do_num_bytes.is_a?(Integer) ? sum.ceil : sum.floor
    end

    def do_read(io) #:nodoc:
      instantiate_all_objs
      @field_objs.each { |f| f.do_read(io) if include_obj(f) }
    end

    def do_write(io) #:nodoc
      instantiate_all_objs
      @field_objs.each { |f| f.do_write(io) if include_obj(f) }
    end

    def do_num_bytes #:nodoc:
      instantiate_all_objs
      sum_num_bytes_for_all_fields
    end

    def [](key)
      find_obj_for_name(key)
    end

    def []=(key, value)
      obj = find_obj_for_name(key)
      if obj
        obj.assign(value)
      end
    end

    def has_key?(key)
      @field_names.index(base_field_name(key))
    end

    def each_pair
      @field_names.compact.each do |name|
        yield [name, find_obj_for_name(name)]
      end
    end

    #---------------
    private

    def base_field_name(name)
      name.to_s.chomp("=").to_sym
    end

    def invoke_field(obj, symbol, args)
      name = symbol.to_s
      is_writer = (name[-1, 1] == "=")

      if is_writer
        obj.assign(*args)
      else
        obj
      end
    end

    def find_index_of(obj)
      @field_objs.index { |el| el.equal?(obj) }
    end

    def find_obj_for_name(name)
      index = @field_names.index(base_field_name(name))
      if index
        instantiate_obj_at(index)
        @field_objs[index]
      else
        nil
      end
    end

    def instantiate_all_objs
      @field_names.each_index { |i| instantiate_obj_at(i) }
    end

    def instantiate_obj_at(index)
      if @field_objs[index].nil?
        field = get_parameter(:fields)[index]
        @field_objs[index] = field.instantiate(nil, self)
      end
    end

    def assign_fields(val)
      src = as_stringified_hash(val)

      @field_names.compact.each do |name|
        obj = find_obj_for_name(name)
        if obj and src.has_key?(name)
          obj.assign(src[name])
        end
      end
    end

    def as_stringified_hash(val)
      if BinData::Struct === val
        val
      elsif val.nil?
        {}
      else
        hash = Snapshot.new
        val.each_pair { |k,v| hash[k] = v }
        hash
      end
    end

    def sum_num_bytes_for_all_fields
      sum_num_bytes_below_index(@field_objs.length)
    end

    def sum_num_bytes_below_index(index)
      sum = 0
      (0...index).each do |i|
        obj = @field_objs[i]
        if include_obj(obj)
          nbytes = obj.do_num_bytes
          sum = (nbytes.is_a?(Integer) ? sum.ceil : sum) + nbytes
        end
      end

      sum
    end

    def include_obj(obj)
      not obj.has_parameter?(:onlyif) or obj.eval_parameter(:onlyif)
    end

    # A hash that can be accessed via attributes.
    class Snapshot < ::Hash #:nodoc:
      def []=(key, value)
        super(key, value) unless value.nil?
      end

      def respond_to?(symbol, include_private = false)
        has_key?(symbol) || super
      end

      def method_missing(symbol, *args)
        self[symbol] || super
      end
    end
  end
end
