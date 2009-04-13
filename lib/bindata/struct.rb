require 'bindata/base'
require 'bindata/sanitize'

module BinData
  # A Struct is an ordered collection of named data objects.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::MultiValue
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
      #### DEPRECATION HACK to warn about inheriting from BinData::Struct
      #
      def inherited(subclass) #:nodoc:
        if subclass != MultiValue
          # warn about deprecated method - remove before releasing 1.0
          fail "error: inheriting from BinData::Struct has been deprecated. Inherit from BinData::MultiValue instead."
        end
      end
      #
      #### DEPRECATION HACK to allow inheriting from BinData::Struct


      def sanitize_parameters!(sanitizer, params)
        ensure_valid_endian(params)

        if params.has_key?(:fields)
          sfields = sanitized_fields(sanitizer, params[:fields], params[:endian])
          field_names = sanitized_field_names(sfields)
          hfield_names = hidden_field_names(params[:hide])

          ensure_field_names_are_valid(field_names)

          params[:fields] = sfields
          params[:hide]   = (hfield_names & field_names)
        end

        super(sanitizer, params)
      end

      #-------------
      private

      def ensure_valid_endian(params)
        if params.has_key?(:endian)
          endian = params[:endian]
          unless [:little, :big].include?(endian)
            raise ArgumentError, "unknown value for endian '#{endian}'"
          end
        end
      end

      def sanitized_fields(sanitizer, fields, endian)
        result = nil
        sanitizer.with_endian(endian) do
          result = fields.collect do |ftype, fname, fparams|
            sanitized_field(sanitizer, ftype, fname, fparams)
          end
        end
        result
      end

      def sanitized_field(sanitizer, ftype, fname, fparams)
        fname = fname.to_s
        fclass = sanitizer.lookup_class(ftype)
        sanitized_fparams = sanitizer.sanitized_params(fclass, fparams)
        [fclass, fname, sanitized_fparams]
      end

      def sanitized_field_names(sanitized_fields)
        sanitized_fields.collect { |fclass, fname, fparams| fname }
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

    bindata_mandatory_parameter :fields
    bindata_optional_parameters :endian, :hide

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @field_names = no_eval_param(:fields).collect { |c, n, p| n }
      @field_objs  = []
    end

    # Clears the field represented by +name+.  If no +name+
    # is given, clears all fields in the struct.
    def clear(name = nil)
      if name.nil?
        @field_objs.each { |f| f.clear unless f.nil? }
      else
        warn "'obj.clear(name)' is deprecated.  Use 'obj.name.clear' instead"
        obj = find_obj_for_name(name)
        obj.clear unless obj.nil?
      end
    end

    # Returns if the field represented by +name+ is clear?.  If no +name+
    # is given, returns whether all fields are clear.
    def clear?(name = nil)
      if name.nil?
        @field_objs.inject(true) { |all_clear, f| all_clear and (f.nil? or f.clear?) }
      else
        warn "'obj.clear?(name)' is deprecated.  Use 'obj.name.clear?' instead"
        obj = find_obj_for_name(name)
        obj.nil? ? true : obj.clear?
      end
    end

    # Returns a list of the names of all fields accessible through this
    # object.  +include_hidden+ specifies whether to include hidden names
    # in the listing.
    def field_names(include_hidden = false)
      if include_hidden
        @field_names.dup
      else
        hidden = no_eval_param(:hide)
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
      if child.class == ::String
        fail "error: 'offset_of(\"fieldname\")' is deprecated.  Use 'fieldname.offset' instead"
      end

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
        fclass, fname, fparams = no_eval_param(:fields)[index]
        @field_objs[index] = fclass.new(fparams, self)
      end
    end

    def _do_read(io)
      instantiate_all_objs
      @field_objs.each { |f| f.do_read(io) }
    end

    def _done_read
      @field_objs.each { |f| f.done_read }
    end

    def _do_write(io)
      instantiate_all_objs
      @field_objs.each { |f| f.do_write(io) }
    end

    def _do_num_bytes(name)
      if name.nil?
        instantiate_all_objs
        sum_num_bytes_for_all_fields.ceil
      else
        warn "'obj.num_bytes(name)' is deprecated.  Use 'obj.name.num_bytes' instead"
        obj = find_obj_for_name(name)
        obj.nil? ? 0 : obj.do_num_bytes
      end
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
        ss = find_obj_for_name(name).snapshot
        snapshot[name] = ss unless ss.nil?
      end
      snapshot
    end

    def sum_num_bytes_for_all_fields
      sum_num_bytes_below_index(@field_objs.length)
    end

    def sum_num_bytes_below_index(index)
      sum = 0
      (0...index).each do |i|
        nbytes = @field_objs[i].do_num_bytes
        sum = ((::Integer === nbytes) ? sum.ceil : sum) + nbytes
      end

      sum
    end
  end
end
