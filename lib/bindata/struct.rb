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
  #                                           [:tuple, :nil] ])
  #    obj.field_names   =># ["b", "x", "y", "z"]
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
  #                      type.  Name is the name of this field.  Name may be
  #                      nil as in the example above.  Params is an optional
  #                      hash of parameters to pass to this field when
  #                      instantiating it.
  # <tt>:hide</tt>::     A list of the names of fields that are to be hidden
  #                      from the outside world.  Hidden fields don't appear
  #                      in #snapshot or #field_names but are still accessible
  #                      by name.
  # <tt>:endian</tt>::   Either :little or :big.  This specifies the default
  #                      endian of any numerics in this struct, or in any
  #                      nested data objects.
  class Struct < BinData::Base

    # Register this class
    register(self.name, self)

    # A hash that can be accessed via attributes.
    class Snapshot < Hash #:nodoc:
      def method_missing(symbol, *args)
        self[symbol.id2name] || super
      end
    end

    class << self
      #### DEPRECATION HACK to allow inheriting from BinData::Struct
      #
      def inherited(subclass) #:nodoc:
        if subclass != MultiValue
          # warn about deprecated method - remove before releasing 1.0
          warn "warning: inheriting from BinData::Struct in deprecated. Inherit from BinData::MultiValue instead."

          register(subclass.name, subclass)
        end
      end
      def endian(endian = nil)
        @endian ||= nil
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError, "unknown value for endian '#{endian}'"
        end
        @endian
      end
      def hide(*args)
        # note that fields are stored in an instance variable not a class var
        @hide ||= []
        args.each do |name|
          next if name.nil?
          @hide << name.to_s
        end
        @hide
      end
      def fields
        @fields || []
      end
      def method_missing(symbol, *args)
        name, params = args

        type = symbol
        name = (name.nil? or name == "") ? nil : name.to_s
        params ||= {}

        # note that fields are stored in an instance variable not a class var
        @fields ||= []

        # check that type is known
        if lookup(type, endian).nil?
          raise TypeError, "unknown type '#{type}' for #{self}", caller
        end

        # check that name is okay
        if name != nil
          # check for duplicate names
          @fields.each do |t, n, p|
            if n == name
              raise SyntaxError, "duplicate field '#{name}' in #{self}", caller
            end
          end

          # check that name doesn't shadow an existing method
          if self.instance_methods.include?(name)
            raise NameError.new("", name),
                  "field '#{name}' shadows an existing method", caller
          end

          # check that name isn't reserved
          if ::Hash.instance_methods.include?(name)
            raise NameError.new("", name),
                  "field '#{name}' is a reserved name", caller
          end
        end

        # remember this field.  These fields will be recalled upon creating
        # an instance of this class
        @fields.push([type, name, params])
      end
      def deprecated_hack(params, endian = nil)
        params = params.dup

        # possibly override endian
        endian = params[:endian] || self.endian || endian
        unless endian.nil?
          params[:endian] = endian
        end

        params[:fields] = params[:fields] || self.fields
        params[:hide] = params[:hide] || self.hide

        [params, endian]
      end
      #
      #### DEPRECATION HACK to allow inheriting from BinData::Struct


      # Returns a sanitized +params+ that is of the form expected
      # by #initialize.
      def sanitize_parameters(params, endian = nil)
        #### DEPRECATION HACK to allow inheriting from BinData::Struct
        #
        params, endian = deprecated_hack(params, endian)
        #
        #### DEPRECATION HACK to allow inheriting from BinData::Struct

        params = params.dup

        # possibly override endian
        endian = params[:endian] || endian
        if endian != nil
          unless [:little, :big].include?(endian)
            raise ArgumentError, "unknown value for endian '#{endian}'"
          end

          params[:endian] = endian
        end

        if params.has_key?(:fields)
          # ensure the names of fields are strings and that params is sanitized
          all_fields = params[:fields].collect do |ftype, fname, fparams|
            fname = fname.nil? ? "" : fname.to_s
            klass = lookup(ftype, endian)
            raise TypeError, "unknown type '#{ftype}' for #{self}" if klass.nil?
            [klass, fname, SanitizedParameters.new(klass, fparams, endian)]
          end
          params[:fields] = all_fields

          # collect all hidden names that correspond to a field name
          hide = []
          if params.has_key?(:hide)
            hidden = params[:hide] || []
            hidden.each do |h|
              next if h.nil? or h == ""
              h = h.to_s
              hide << h if all_fields.find { |k,n,p| n == h }
            end
          end
          params[:hide] = hide
        end

        # obtain SanitizedParameters
        params = super(params, endian)

        # now params are sanitized, check that parameter names are okay

        field_names = []
        instance_methods = self.instance_methods
        reserved_names = ::Hash.instance_methods

        params[:fields].each do |fklass, fname, fparams|

          # check that name doesn't shadow an existing method
          if instance_methods.include?(fname)
            raise NameError.new("field '#{fname}' shadows an existing method in #{self}. Rename it.", fname)
          end

          # check that name isn't reserved
          if reserved_names.include?(fname)
            raise NameError.new("field '#{fname}' is a reserved name in #{self}. Rename it.", fname)
          end

          if fname == ""
            fklass.all_possible_field_names(fparams).each do |name|
              if field_names.include?(name)
                raise NameError.new("field '#{name}' is defined multiple times in #{self}.", name)
              end
              field_names << name
            end
          else
            if field_names.include?(fname)
              raise NameError.new("field '#{fname}' is defined multiple times in #{self}.", fname)
            end
            field_names << fname
          end
        end

        params
      end

      # Returns a list of the names of all possible field names for a Struct
      # created with +sanitized_params+.  Hidden names will not be included
      # in the returned list.
      def all_possible_field_names(sanitized_params)
        unless SanitizedParameters === sanitized_params
          raise ArgumentError, "parameters aren't sanitized"
        end

        hidden_names = sanitized_params[:hide]

        names = []
        sanitized_params[:fields].each do |fklass, fname, fparams|
          if fname == ""
            names.concat(fklass.all_possible_field_names(fparams))
          else
            names << fname unless hidden_names.include?(fname)
          end
        end

        names
      end
    end

    # These are the parameters used by this class.
    mandatory_parameter :fields
    optional_parameters :endian, :hide

    # Creates a new Struct.
    def initialize(params = {}, env = nil)
      super(params, env)

      # create instances of the fields
      @fields = param(:fields).collect do |fklass, fname, fparams|
        [fname, fklass.new(fparams, create_env)]
      end
    end

    # Clears the field represented by +name+.  If no +name+
    # is given, clears all fields in the struct.
    def clear(name = nil)
      if name.nil?
        bindata_objects.each { |f| f.clear }
      else
        find_obj_for_name(name.to_s).clear
      end
    end

    # Returns if the field represented by +name+ is clear?.  If no +name+
    # is given, returns whether all fields are clear.
    def clear?(name = nil)
      if name.nil?
        bindata_objects.each { |f| return false if not f.clear? }
        true
      else
        find_obj_for_name(name.to_s).clear?
      end
    end

    # Reads the values for all fields in this object from +io+.
    def _do_read(io)
      bindata_objects.each { |f| f.do_read(io) }
    end

    # To be called after calling #read.
    def done_read
      bindata_objects.each { |f| f.done_read }
    end

    # Writes the values for all fields in this object to +io+.
    def _do_write(io)
      bindata_objects.each { |f| f.do_write(io) }
    end

    # Returns the number of bytes it will take to write the field represented
    # by +name+.  If +name+ is nil then returns the number of bytes required
    # to write all fields.
    def _num_bytes(name)
      if name.nil?
        bindata_objects.inject(0) { |sum, f| sum + f.num_bytes }
      else
        find_obj_for_name(name.to_s).num_bytes
      end
    end

    # Returns a snapshot of this struct as a hash.
    def snapshot
      hash = Snapshot.new
      field_names.each do |name|
        hash[name] = find_obj_for_name(name).snapshot
      end
      hash
    end

    # Returns whether this data object contains a single value.  Single
    # value data objects respond to <tt>#value</tt> and <tt>#value=</tt>.
    def single_value?
      return false
    end

    # Returns a list of the names of all fields accessible through this
    # object.  +include_hidden+ specifies whether to include hidden names
    # in the listing.
    def field_names(include_hidden = false)
      # collect field names
      names = []
      hidden = param(:hide)
      @fields.each do |name, obj|
        if name != ""
          if include_hidden or not hidden.include?(name)
            names << name
          end
        else
          names.concat(obj.field_names)
        end
      end
      names
    end

    # Returns the data object that stores values for +name+.
    def find_obj_for_name(name)
      @fields.each do |n, o|
        if n == name
          return o
        elsif n == "" and o.field_names.include?(name)
          return o.find_obj_for_name(name)
        end
      end
      nil
    end

    def offset_of(field)
      field_name = field.to_s
      offset = 0
      @fields.each do |name, obj|
        if name != ""
          break if name == field_name
          offset += obj.num_bytes
        elsif obj.field_names.include?(field_name)
          offset += obj.offset_of(field)
          break
        end
      end
      offset
    end

    # Override to include field names
    alias_method :orig_respond_to?, :respond_to?
    def respond_to?(symbol, include_private = false)
      orig_respond_to?(symbol, include_private) ||
        field_names(true).include?(symbol.id2name.chomp("="))
    end

    def method_missing(symbol, *args, &block)
      name = symbol.id2name

      is_writer = (name[-1, 1] == "=")
      name.chomp!("=")

      # find the object that is responsible for name
      if (obj = find_obj_for_name(name))
        # pass on the request
        if obj.single_value? and is_writer
          obj.value = *args
        elsif obj.single_value?
          obj.value
        else
          obj
        end
      else
        super
      end
    end

    #---------------
    private

    # Returns a list of all the bindata objects for this struct.
    def bindata_objects
      @fields.collect { |f| f[1] }
    end
  end
end
