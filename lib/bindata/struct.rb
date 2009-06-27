require 'bindata/base'

module BinData
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
  #    obj.field_names   =># ["b", "s"]
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
  #                      when instantiating it.
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

    register(self.name, self)

    # These reserved words may not be used as field names
    RESERVED = (::Hash.instance_methods + 
                %w{alias and begin break case class def defined do else elsif
                   end ensure false for if in module next nil not or redo
                   rescue retry return self super then true undef unless until
                   when while yield} +
                %w{array element index value} ).uniq

    # A hash that can be accessed via attributes.
    class Snapshot < Hash #:nodoc:
      def respond_to?(symbol, include_private = false)
        has_key?(symbol.to_s) || super(symbol, include_private)
      end

      def method_missing(symbol, *args)
        self[symbol.to_s] || super
      end
    end

    class << self

      def sanitize_parameters!(params, sanitizer)
        sanitize_endian(params, sanitizer)
        sanitize_fields(params, sanitizer)
        sanitize_hide(params, sanitizer)
      end

      #-------------
      private

      def sanitize_endian(params, sanitizer)
        if params.needs_sanitizing?(:endian)
          params[:endian] = sanitizer.create_sanitized_endian(params[:endian])
        end
      end

      def sanitize_fields(params, sanitizer)
        if params.needs_sanitizing?(:fields)
          fields = params[:fields]

          params[:fields] = sanitizer.create_sanitized_fields(params[:endian])
          fields.each do |ftype, fname, fparams|
            params[:fields].add_field(ftype, fname, fparams)
          end

          field_names = sanitized_field_names(params[:fields])
          ensure_field_names_are_valid(field_names)
        end
      end

      def sanitize_hide(params, sanitizer)
        if params.needs_sanitizing?(:hide) and params.has_parameter?(:fields)
          field_names = sanitized_field_names(params[:fields])
          hfield_names = hidden_field_names(params[:hide])

          params[:hide]   = (hfield_names & field_names)
        end
      end

      def sanitized_field_names(sanitized_fields)
        sanitized_fields.field_names
      end

      def hidden_field_names(hidden)
        (hidden || []).collect { |h| h.to_s }
      end

      def ensure_field_names_are_valid(field_names)
        instance_methods = self.instance_methods
        reserved_names = RESERVED

        field_names.each do |name|
          if instance_methods.include?(name)
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

    mandatory_parameter :fields
    optional_parameters :endian, :hide

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @field_names = get_parameter(:fields).field_names
      @field_objs  = []
    end

    def clear
      @field_objs.each { |f| f.clear unless f.nil? }
    end

    def clear?
      @field_objs.inject(true) { |all_clear, f| all_clear and (f.nil? or f.clear?) }
    end

    # Returns a list of the names of all fields accessible through this
    # object.  +include_hidden+ specifies whether to include hidden names
    # in the listing.
    def field_names(include_hidden = false)
      if include_hidden
        @field_names.dup
      else
        hidden = get_parameter(:hide) || []
        @field_names - hidden
      end
    end

    def respond_to?(symbol, include_private = false)
      super(symbol, include_private) ||
        field_names(true).include?(symbol.to_s.chomp("="))
    end

    def method_missing(symbol, *args, &block)
      obj = find_obj_for_name(symbol)
      if obj
        invoke_field(obj, symbol, args)
      else
        super
      end
    end

    def debug_name_of(child)
      field_name = @field_names[find_index_of(child)]
      "#{debug_name}.#{field_name}"
    end

    def offset_of(child)
      instantiate_all_objs
      sum = sum_num_bytes_below_index(find_index_of(child))
      child_offset = (::Integer === child.do_num_bytes) ? sum.ceil : sum.floor

      offset + child_offset
    end

    #---------------
    private

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
      @field_objs.find_index { |el| el.equal?(obj) }
    end

    def find_obj_for_name(name)
      field_name = name.to_s.chomp("=")
      index = @field_names.find_index(field_name)
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
        @field_objs[index] = field.instantiate(self)
      end
    end

    def _do_read(io)
      instantiate_all_objs
      @field_objs.each { |f| f.do_read(io) if include_obj(f) }
    end

    def _done_read
      @field_objs.each { |f| f.done_read if include_obj(f) }
    end

    def _do_write(io)
      instantiate_all_objs
      @field_objs.each { |f| f.do_write(io) if include_obj(f) }
    end

    def _do_num_bytes(deprecated)
      instantiate_all_objs
      sum_num_bytes_for_all_fields.ceil
    end

    def _assign(val)
      clear
      assign_fields(as_snapshot(val))
    end

    def as_snapshot(val)
      if val.class == Hash
        snapshot = Snapshot.new
        val.each_pair { |k,v| snapshot[k.to_s] = v unless v.nil? }
        snapshot
      elsif val.nil?
        Snapshot.new
      else
        val
      end
    end

    def assign_fields(snapshot)
      field_names(true).each do |name|
        obj = find_obj_for_name(name)
        if obj and snapshot.respond_to?(name)
          obj.assign(snapshot.__send__(name))
        end
      end
    end

    def _snapshot
      snapshot = Snapshot.new
      field_names.each do |name|
        obj = find_obj_for_name(name)
        snapshot[name] = obj.snapshot if include_obj(obj)
      end
      snapshot
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
          sum = ((::Integer === nbytes) ? sum.ceil : sum) + nbytes
        end
      end

      sum
    end

    def include_obj(obj)
      not obj.has_parameter?(:onlyif) or obj.eval_parameter(:onlyif)
    end
  end
end
