require 'bindata/base'

module BinData
  # A BinData::Multi object is a container that may contain multiple
  # BinData::Single or BinData::Multi objects.  This container is used
  # to group and structure the contained objects.
  class Multi < Base
    # Register the names of all subclasses of this class.
    def self.inherited(subclass) #:nodoc:
      register(subclass.name, subclass)
    end

    # Returns the class matching a previously registered +name+.
    def klass_lookup(name)
      @cache ||= {}
      klass = @cache[name]
      if klass.nil?
        klass = self.class.lookup(name)
        if klass.nil? and @env.parent_data_object != nil
          # lookup failed so retry in the context of the parent data object
          klass = @env.parent_data_object.klass_lookup(name)
        end
        @cache[name] = klass
      end
      klass
    end

    #---------------
    private

    # Creates a new LazyEvalEnv for use by a child data object.
    def create_env
      LazyEvalEnv.new(@env)
    end
  end
end
