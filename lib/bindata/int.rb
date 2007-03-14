require 'bindata/single'

module BinData
  # Provides a number of classes that contain an integer.  The integer
  # is defined by endian, signedness and number of bytes.

  module BaseUint #:nodoc: all

    def value=(val)
      super(clamp(val))
    end

    #---------------
    private

    def sensible_default
      0
    end

    def val_to_str(val)
      _val_to_str(clamp(val))
    end

    # Clamps +val+ to the range 0 .. max_val
    def clamp(val)
      v = val
      nbytes = val_num_bytes(0)
      min = 0
      max = (1 << (nbytes * 8)) - 1
      val = min if val < min
      val = max if val > max
      val
    end
  end

  module BaseInt #:nodoc: all
    def uint2int(val)
      nbytes = val_num_bytes(0)
      mask = (1 << (nbytes * 8 - 1)) - 1
      msb = (val >> (nbytes * 8 - 1)) & 0x1
      (msb == 1) ? -(((~val) & mask) + 1) : val & mask
    end

    def int2uint(val)
      nbytes = val_num_bytes(0)
      mask = (1 << (nbytes * 8)) - 1
      val & mask
    end

    def value=(val)
      super(clamp(val))
    end

    #---------------
    private

    def sensible_default
      0
    end

    def val_to_str(val)
      _val_to_str(int2uint(clamp(val)))
    end

    def read_val(io)
      uint2int(_read_val(io))
    end

    # Clamps +val+ to the range min_val .. max_val, where min and max
    # are the largest representable integers.
    def clamp(val)
      nbytes = val_num_bytes(0)
      max = (1 << (nbytes * 8 - 1)) - 1
      min = -(max + 1)
      val = min if val < min
      val = max if val > max
      val
    end
  end


  # Unsigned 1 byte integer.
  class Uint8 < Single
    include BaseUint
    private
    def val_num_bytes(val) 1 end
    def read_val(io)       readbytes(io,1)[0] end
    def _val_to_str(val)   val.chr end
  end

  # Unsigned 2 byte little endian integer.
  class Uint16le < Single
    include BaseUint
    private
    def val_num_bytes(val) 2 end
    def read_val(io)       readbytes(io,2).unpack("v")[0] end
    def _val_to_str(val)   [val].pack("v") end
  end

  # Unsigned 2 byte big endian integer.
  class Uint16be < Single
    include BaseUint
    private
    def val_num_bytes(val) 2 end
    def read_val(io)       readbytes(io,2).unpack("n")[0] end
    def _val_to_str(val)   [val].pack("n") end
  end

  # Unsigned 4 byte little endian integer.
  class Uint32le < Single
    include BaseUint
    private
    def val_num_bytes(val) 4 end
    def read_val(io)       readbytes(io,4).unpack("V")[0] end
    def _val_to_str(val)   [val].pack("V") end
  end

  # Unsigned 4 byte big endian integer.
  class Uint32be < Single
    include BaseUint
    private
    def val_num_bytes(val) 4 end
    def read_val(io)       readbytes(io,4).unpack("N")[0] end
    def _val_to_str(val)   [val].pack("N") end
  end

  # Signed 1 byte integer.
  class Int8 < Single
    include BaseInt
    private
    def val_num_bytes(val) 1 end
    def _read_val(io)      readbytes(io,1)[0] end
    def _val_to_str(val)   val.chr end
  end

  # Signed 2 byte little endian integer.
  class Int16le < Single
    include BaseInt
    private
    def val_num_bytes(val) 2 end
    def _read_val(io)      readbytes(io,2).unpack("v")[0] end
    def _val_to_str(val)   [val].pack("v") end
  end

  # Signed 2 byte big endian integer.
  class Int16be < Single
    include BaseInt
    private
    def val_num_bytes(val) 2 end
    def _read_val(io)      readbytes(io,2).unpack("n")[0] end
    def _val_to_str(val)   [val].pack("n") end
  end

  # Signed 4 byte little endian integer.
  class Int32le < Single
    include BaseInt
    private
    def val_num_bytes(val) 4 end
    def _read_val(io)      readbytes(io,4).unpack("V")[0] end
    def _val_to_str(val)   [val].pack("V") end
  end

  # Signed 4 byte big endian integer.
  class Int32be < Single
    include BaseInt
    private
    def val_num_bytes(val) 4 end
    def _read_val(io)      readbytes(io,4).unpack("N")[0] end
    def _val_to_str(val)   [val].pack("N") end
  end
end
