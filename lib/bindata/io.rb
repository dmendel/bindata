require 'stringio'

module BinData
  # A wrapper around an IO object.  The wrapper provides a consistent
  # interface for BinData objects to use when accessing the IO.
  module IO

    # Creates a StringIO around +str+.
    def self.create_string_io(str = "")
      bin_str = str.dup.force_encoding(Encoding::BINARY)
      StringIO.new(bin_str).tap(&:binmode)
    end

    # An IO stream may be transformed before processing.
    # e.g. encoding, compression, buffered.
    #
    # Multiple transforms can be chained together.
    #
    # Subclass +Transform+ and customise.  Then call +transform+
    # to apply.
    class Transform
      def initialize
        @chain_io = nil
      end

      # Chains +io+ to this +Transform+.  Returns self.
      def chained(io)
        @chain_io = io
        self
      end

      # Is the IO seekable?
      def seekable?
        @chain_io.seekable?
      end

      # How many bytes are available for reading?
      def num_bytes_remaining
        @chain_io.num_bytes_remaining
      end

      # The current offset within the stream.
      def offset
        @chain_io.offset
      end

      # Skips forward +n+ bytes in the input stream.
      def skip(n)
        @chain_io.skip(n)
      end

      # Seeks to the given absolute position.
      def seek_abs(n)
        @chain_io.seek_abs(n)
      end

      # Reads +n+ bytes from the stream.
      def read(n)
        @chain_io.read(n)
      end

      # Writes +data+ to the stream.
      def write(data)
        @chain_io.write(data)
      end
    end

    # Common operations for both Read and Write.
    module Common
      def initialize(io)
        if self.class === io
          raise ArgumentError, "io must not be a #{self.class}"
        end

        # wrap strings in a StringIO
        if io.respond_to?(:to_str)
          io = BinData::IO.create_string_io(io.to_str)
        end

        # wrap steam with standard accessor methods
        wrapper_class = seekable?(io) ? SeekableIO : UnSeekableIO
        @io = wrapper_class.new(io)
      end

      # Allow transforming data in the input stream.
      # See +BinData::Buffer+ as an example.
      #
      # +io+ must be an instance of +Transform+.
      #
      # yields +self+ and +io+ to the given block
      def transform(io)
        saved = @io
        @io = io.chained(@io)
        yield(self, io)
      ensure
        @io = saved
      end

      #-------------
      private

      def seekable?(io)
        io.pos
      rescue NoMethodError, Errno::ESPIPE, Errno::EPIPE, Errno::EINVAL
        nil
      end
    end

    # Create a new IO Read wrapper around +io+.  +io+ must provide #read,
    # #pos if reading the current stream position and #seek if setting the
    # current stream position.  If +io+ is a string it will be automatically
    # wrapped in an StringIO object.
    #
    # The IO can handle bitstreams in either big or little endian format.
    #
    #      M  byte1   L      M  byte2   L
    #      S 76543210 S      S fedcba98 S
    #      B          B      B          B
    #
    # In big endian format:
    #   readbits(6), readbits(5) #=> [765432, 10fed]
    #
    # In little endian format:
    #   readbits(6), readbits(5) #=> [543210, a9876]
    #
    class Read
      include Common

      def initialize(io)
        super(io)

        # bits when reading
        @rnbits  = 0
        @rval    = 0
        @rendian = nil
      end

      # The number of bytes remaining in the io steam.
      def num_bytes_remaining
        @io.num_bytes_remaining
      end

      # Seek +n+ bytes from the current position in the io stream.
      def skipbytes(n)
        reset_read_bits
        @io.skip(n)
      end

      # Seek to an absolute offset within the io stream.
      def seek_to_abs_offset(n)
        @io.seek_abs(n)
      end

      # Reads exactly +n+ bytes from +io+.
      #
      # If the data read is nil an EOFError is raised.
      #
      # If the data read is too short an IOError is raised.
      def readbytes(n)
        reset_read_bits
        read(n)
      end

      # Reads all remaining bytes from the stream.
      def read_all_bytes
        reset_read_bits
        read
      end

      # Reads exactly +nbits+ bits from the stream. +endian+ specifies whether
      # the bits are stored in +:big+ or +:little+ endian format.
      def readbits(nbits, endian)
        if @rendian != endian
          # don't mix bits of differing endian
          reset_read_bits
          @rendian = endian
        end

        if endian == :big
          read_big_endian_bits(nbits)
        else
          read_little_endian_bits(nbits)
        end
      end

      # Discards any read bits so the stream becomes aligned at the
      # next byte boundary.
      def reset_read_bits
        @rnbits = 0
        @rval   = 0
      end

      #---------------
      private

      def read(n = nil)
        str = @io.read(n)
        if n
          raise EOFError, "End of file reached" if str.nil?
          raise IOError, "data truncated" if str.size < n
        end
        str
      end

      def read_big_endian_bits(nbits)
        while @rnbits < nbits
          accumulate_big_endian_bits
        end

        val     = (@rval >> (@rnbits - nbits)) & mask(nbits)
        @rnbits -= nbits
        @rval   &= mask(@rnbits)

        val
      end

      def accumulate_big_endian_bits
        byte = read(1).unpack1('C') & 0xff
        @rval = (@rval << 8) | byte
        @rnbits += 8
      end

      def read_little_endian_bits(nbits)
        while @rnbits < nbits
          accumulate_little_endian_bits
        end

        val     = @rval & mask(nbits)
        @rnbits -= nbits
        @rval   >>= nbits

        val
      end

      def accumulate_little_endian_bits
        byte = read(1).unpack1('C') & 0xff
        @rval = @rval | (byte << @rnbits)
        @rnbits += 8
      end

      def mask(nbits)
        (1 << nbits) - 1
      end
    end

    # Create a new IO Write wrapper around +io+.  +io+ must provide #write.
    # If +io+ is a string it will be automatically wrapped in an StringIO
    # object.
    #
    # The IO can handle bitstreams in either big or little endian format.
    #
    # See IO::Read for more information.
    class Write
      include Common
      def initialize(io)
        super(io)

        @wnbits  = 0
        @wval    = 0
        @wendian = nil
      end

      # Seek to an absolute offset within the io stream.
      def seek_to_abs_offset(n)
        raise IOError, "stream is unseekable" unless @io.seekable?

        flushbits
        @io.seek_abs(n)
      end

      # Writes the given string of bytes to the io stream.
      def writebytes(str)
        flushbits
        write(str)
      end

      # Writes +nbits+ bits from +val+ to the stream. +endian+ specifies whether
      # the bits are to be stored in +:big+ or +:little+ endian format.
      def writebits(val, nbits, endian)
        if @wendian != endian
          # don't mix bits of differing endian
          flushbits
          @wendian = endian
        end

        clamped_val = val & mask(nbits)

        if endian == :big
          write_big_endian_bits(clamped_val, nbits)
        else
          write_little_endian_bits(clamped_val, nbits)
        end
      end

      # To be called after all +writebits+ have been applied.
      def flushbits
        raise "Internal state error nbits = #{@wnbits}" if @wnbits >= 8

        if @wnbits > 0
          writebits(0, 8 - @wnbits, @wendian)
        end
      end
      alias flush flushbits

      #---------------
      private

      def write(data)
        @io.write(data)
      end

      def write_big_endian_bits(val, nbits)
        while nbits > 0
          bits_req = 8 - @wnbits
          if nbits >= bits_req
            msb_bits = (val >> (nbits - bits_req)) & mask(bits_req)
            nbits -= bits_req
            val &= mask(nbits)

            @wval   = (@wval << bits_req) | msb_bits
            write(@wval.chr)

            @wval   = 0
            @wnbits = 0
          else
            @wval = (@wval << nbits) | val
            @wnbits += nbits
            nbits = 0
          end
        end
      end

      def write_little_endian_bits(val, nbits)
        while nbits > 0
          bits_req = 8 - @wnbits
          if nbits >= bits_req
            lsb_bits = val & mask(bits_req)
            nbits -= bits_req
            val >>= bits_req

            @wval   = @wval | (lsb_bits << @wnbits)
            write(@wval.chr)

            @wval   = 0
            @wnbits = 0
          else
            @wval   = @wval | (val << @wnbits)
            @wnbits += nbits
            nbits = 0
          end
        end
      end

      def mask(nbits)
        (1 << nbits) - 1
      end
    end

    class SeekableIO
      def initialize(io)
        @io = io
        @initial_pos = io.pos
      end

      def seekable?
        true
      end

      def num_bytes_remaining
        start_mark = @io.pos
        @io.seek(0, ::IO::SEEK_END)
        end_mark = @io.pos
        @io.seek(start_mark, ::IO::SEEK_SET)

        end_mark - start_mark
      end

      def offset
        @io.pos - @initial_pos
      end

      def skip(n)
        raise IOError, "can not skip backwards" if n.negative?
        @io.seek(n, ::IO::SEEK_CUR)
      end

      def seek_abs(n)
        @io.seek(n + @initial_pos, ::IO::SEEK_SET)
      end

      def read(n)
        @io.read(n)
      end

      def write(data)
        @io.write(data)
      end
    end

    class UnSeekableIO
      def initialize(io)
        @io = io
        @pos = 0
      end

      def seekable?
        false
      end

      def num_bytes_remaining
        raise IOError, "stream is unseekable"
      end

      def offset
        @pos
      end

      def skip(n)
        raise IOError, "can not skip backwards" if n.negative?

        # skip over data in 8k blocks
        while n > 0
          bytes_to_read = [n, 8192].min
          read(bytes_to_read)
          n -= bytes_to_read
        end
      end

      def seek_abs(n)
        skip(n - offset)
      end

      def read(n)
        @io.read(n).tap { |data| @pos += (data&.size || 0) }
      end

      def write(data)
        @pos += data.size
        @io.write(data)
      end
    end
  end
end
