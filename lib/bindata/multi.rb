require 'bindata/base'

module BinData
  # A BinData::Multi object is a container that may contain multiple
  # BinData::Single objects.  This container is used to group and structure
  # the contained objects.
  #
  class Multi < Base
    # Register the names of all subclasses of this class.
    def self.inherited(subclass) #:nodoc:
      register(subclass.name, subclass)
    end
  end
end
