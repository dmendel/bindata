require 'bindata/base'

module BinData
  # A Struct is an ordered collection of named data objects.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::Struct
  #      int8  :x
  #      int8  :y
  #      int8  :z
  #    end
  #
  #    class SomeStruct < BinData::Struct
  #      hide 'a'
  #
  #      int32le :a
  #      int16le :b
  #      tuple   nil
  #    end
  #
  #    obj = SomeStruct.new
  #    obj.field_names   =># ["b", "x", "y", "z"]
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:fields</tt>:: An array specifying the fields for this struct.  Each
  #                    element of the array is of the form
  #                    [type, name, params].  Type is a symbol representing
  #                    a registered type.  Name is the name of this field.
  #                    Name may be nil as in the example above.  Params is an
  #                    optional hash of parameters to pass to this field when
  #                    instantiating it.
  # <tt>:hide</tt>::   A list of the names of fields that are to be hidden
  #                    from the outside world.  Hidden fields don't appear
  #                    in #snapshot or #field_names but are still accessible
  #                    by name.
  class Struct < Base
    # A hash that can be accessed via attributes.
    class Snapshot < Hash #:nodoc:
      def method_missing(symbol, *args)
        self[symbol.id2name] || super
      end
    end

    # Register this class
    register(self.name, self)

    class << self
      # Register the names of all subclasses of this class.
      def inherited(subclass) #:nodoc:
        register(subclass.name, subclass)
      end

      # Returns or sets the endianess of numerics used in this stucture.
      # Endianess is applied to the fields of this structure.
      # Valid values are :little and :big.
      def endian(endian = nil)
        @endian ||= nil
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError, "unknown value for endian '#{endian}'"
        end
        @endian
      end

      # Returns the names of any hidden fields in this struct.  Any given args
      # are appended to the hidden list.
      def hide(*args)
        # note that fields are stored in an instance variable not a class var
        @hide ||= []
        args.each do |name|
          next if name.nil?
          @hide << name.to_s
        end
        @hide
      end

      # Used to define fields for this structure.
      def method_missing(symbol, *args)
        name, params = args

        type = symbol
        name = name.to_s unless name.nil?
        params ||= {}

        if lookup(type).nil?
          raise TypeError, "unknown type '#{type}' for #{self}", caller
        end

        # note that fields are stored in an instance variable not a class var

        # check for duplicate names
        @fields ||= []
        if @fields.detect { |t, n, p| n == name and n != nil }
          raise SyntaxError, "duplicate field '#{name}' in #{self}", caller
        end

        # check that name doesn't shadow an existing method
        if self.instance_methods.include?(name)
          raise NameError.new("", name),
                "field '#{name}' shadows an existing method", caller
        end

        # check that name isn't reserved
        if Hash.instance_methods.include?(name)
          raise NameError.new("", name),
                "field '#{name}' is a reserved name", caller
        end

        # remember this field.  These fields will be recalled upon creating
        # an instance of this class
        @fields.push([type, name, params])
      end

      # Returns all stored fields.  Should only be called by #cleaned_params.
      def fields
        @fields || []
      end
    end

    # These are the parameters used by this class.
    mandatory_parameter :fields
    optional_parameter :endian, :hide

    # Creates a new Struct.
    def initialize(params = {}, env = nil)
      super(cleaned_params(params), env)

      all_methods = methods
      all_reserved_methods = Hash.instance_methods - all_methods

      # create instances of the fields
      @fields = param(:fields).collect do |type, name, params|
        klass = klass_lookup(type)
        raise TypeError, "unknown type '#{type}' for #{self}" if klass.nil?
        if all_methods.include?(name)
          raise NameError.new("field '#{name}' shadows an existing method",name)
        end
        if all_reserved_methods.include?(name)
          raise NameError.new("field '#{name}' is a reserved name",name)
        end
        [name, klass.new(params, create_env)]
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
    def _write(io)
      bindata_objects.each { |f| f.write(io) }
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
      # allow structs to masquerade as single value
      return value if single_value?

      hash = Snapshot.new
      field_names.each do |name|
        hash[name] = find_obj_for_name(name).snapshot
      end
      hash
    end

    # Returns a list of the names of all fields accessible through this
    # object.  +include_hidden+ specifies whether to include hidden names
    # in the listing.
    def field_names(include_hidden = false)
      # single values don't have any fields
      return [] if single_value? and include_hidden == false

      names = []
      @fields.each do |name, obj|
        if name != ""
          names << name unless (param(:hide).include?(name) and !include_hidden)
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

    # Override to include field names.
    alias_method :orig_respond_to?, :respond_to?
    def respond_to?(symbol, include_private = false)
      orig_respond_to?(symbol, include_private) ||
        field_names(true).include?(symbol.id2name.chomp("="))
    end

    # Returns whether this data object contains a single value.  Single
    # value data objects respond to <tt>#value</tt> and <tt>#value=</tt>.
    def single_value?
      # need to use original respond_to? to prevent infinite recursion
      orig_respond_to?(:value)
    end

    def method_missing(symbol, *args)
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

    # Returns a hash of cleaned +params+.  Cleaning means that param
    # values are converted to a desired format.
    def cleaned_params(params)
      new_params = params.dup

      # use fields defined in this class if no fields are passed as params
      fields = new_params[:fields] || self.class.fields

      # ensure the names of fields are strings and that params is a hash
      new_params[:fields] = fields.collect do |t, n, p|
        [t, n.to_s, (p || {}).dup]
      end

      # collect all non blank field names
      field_names = new_params[:fields].collect { |f| f[1] }
      field_names = field_names.delete_if { |n| n == "" }

      # collect all hidden names that correspond to a field name
      hide = []
      (new_params[:hide] || self.class.hide).each do |h|
        h = h.to_s
        hide << h if field_names.include?(h)
      end
      new_params[:hide] = hide

      new_params
    end
  end
end
