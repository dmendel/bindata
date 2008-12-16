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
                %w{array element index offset value} ).uniq

    # A hash that can be accessed via attributes.
    class Snapshot < Hash #:nodoc:
      def method_missing(symbol, *args)
        self[symbol.id2name] || super
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

      @field_names = no_eval_param(:fields).collect { |k, n, p| n }
      @field_objs  = []
    end

    def single_value?
      return false
    end

    # Clears the field represented by +name+.  If no +name+
    # is given, clears all fields in the struct.
    def clear(name = nil)
      if name.nil?
        @field_objs.each { |f| f.clear unless f.nil? }
      else
        obj = find_obj_for_name(name)
        obj.clear unless obj.nil?
      end
    end

    # Returns if the field represented by +name+ is clear?.  If no +name+
    # is given, returns whether all fields are clear.
    def clear?(name = nil)
      if name.nil?
        @field_objs.each do |f|
          return false unless f.nil? or f.clear?
        end
        true
      else
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

    def offset_of(field)
      idx = @field_names.index(field.to_s)
      if idx
        instantiate_all_objs

        offset = 0
        (0...idx).each do |i|
          this_offset = @field_objs[i].do_num_bytes
          if ::Float === offset and ::Integer === this_offset
            offset = offset.ceil
          end
          offset += this_offset
        end
        offset
      else
        nil
      end
    end

    def respond_to?(symbol, include_private = false)
      super(symbol, include_private) ||
        field_names(true).include?(symbol.id2name.chomp("="))
    end

    def method_missing(symbol, *args, &block)
      obj = find_obj_for_name(symbol)
      if obj
        invoke_field(obj, symbol, args)
      else
        super
      end
    end

    #---------------
    private

    def invoke_field(obj, symbol, args)
      name = symbol.id2name
      is_writer = (name[-1, 1] == "=")

      if obj.single_value? and is_writer
        obj.value = *args
      elsif obj.single_value?
        obj.value
      else
        obj
      end
    end

    def find_obj_for_name(name)
      field_name = name.to_s.chomp("=")
      idx = @field_names.index(field_name)
      if idx
        instantiate_obj_at(idx)
        @field_objs[idx].obj
      else
        nil
      end
    end

    def instantiate_all_objs
      @field_names.each_index { |i| instantiate_obj_at(i) }
    end

    def instantiate_obj_at(idx)
      if @field_objs[idx].nil?
        fclass, fname, fparams = no_eval_param(:fields)[idx]
        @field_objs[idx] = fclass.new(fparams, self)
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
        (@field_objs.inject(0) { |sum, f| sum + f.do_num_bytes }).ceil
      else
        obj = find_obj_for_name(name)
        obj.nil? ? 0 : obj.do_num_bytes
      end
    end

    def _snapshot
      # Returns a snapshot of this struct as a hash.
      hash = Snapshot.new
      field_names.each do |name|
        ss = find_obj_for_name(name).snapshot
        hash[name] = ss unless ss.nil?
      end
      hash
    end
  end
end
