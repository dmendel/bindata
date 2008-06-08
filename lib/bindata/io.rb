module BinData
  # A wrapper around an IO object.  The wrapper provides a consistent
  # interface for BinData objects to use when accessing the IO.
  class IO

    # Create a new IO wrapper around +io+.
    def initialize(io)
      raise ArgumentError, "io must not be a BinData::IO" if BinData::IO === io

      unless io.respond_to?(:read) and io.respond_to?(:write)
        # wrap strings in a StringIO
        if io.respond_to?(:to_str)
          io = StringIO.new(io)
        else
          raise ArgumentError, "io does not respond to #read and #write"
        end
      end

      @raw_io = io
      @initial_pos = io.pos
    end

    # Access to the underlying raw io.
    attr_reader :raw_io

    # Returns the current offset of the io stream.
    def offset
      @raw_io.pos - @initial_pos
    end

    # Seek +n+ bytes from the current position in the io stream.
    def seekbytes(n)
      @raw_io.seek(n, ::IO::SEEK_CUR)
    end

    # Reads exactly +n+ bytes from +io+.
    #
    # If the data read is nil an EOFError is raised.
    #
    # If the data read is too short an IOError is raised.
    def readbytes(n)
      str = @raw_io.read(n)
      raise EOFError, "End of file reached" if str == nil
      raise IOError, "data truncated" if str.size < n
      str
    end

    # Writes the given string of bytes to the io stream.
    def write(str)
      @raw_io.write(str)
    end
  end
end
