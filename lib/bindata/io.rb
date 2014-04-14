require 'stringio'

module BinData
  # A wrapper around an IO object.  The wrapper provides a consistent
  # interface for BinData objects to use when accessing the IO.
  module IO
    # Creates a StringIO around +str+.
    def self.create_string_io(str = "")
      StringIO.new(str.dup.force_encoding(Encoding::BINARY))
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
      def initialize(io)
        raise ArgumentError, "io must not be a BinData::IO::Read" if BinData::IO::Read === io

        # wrap strings in a StringIO
        if io.respond_to?(:to_str)
          io = BinData::IO.create_string_io(io.to_str)
        end

        @raw_io = io

        # bits when reading
        @rnbits  = 0
        @rval    = 0
        @rendian = nil

        @buffer_end_pos = nil

        extend seekable? ? SeekableStream : UnSeekableStream
      end

      # Sets a buffer of +n+ bytes on the io stream.  Any reading or seeking
      # calls inside the +block+ will be contained within this buffer.
      def with_buffer(n, &block)
        prev = @buffer_end_pos
        if prev
          avail = prev - offset
          n = avail if n > avail
        end
        @buffer_end_pos = offset + n
        begin
          block.call
          read
        ensure
          @buffer_end_pos = prev
        end
      end

      # Seek +n+ bytes from the current position in the io stream.
      def seekbytes(n)
        reset_read_bits
        seek(n)
      end

      # Reads exactly +n+ bytes from +io+.
      #
      # If the data read is nil an EOFError is raised.
      #
      # If the data read is too short an IOError is raised.
      def readbytes(n)
        reset_read_bits

        str = read(n)
        raise EOFError, "End of file reached" if str.nil?
        raise IOError, "data truncated" if str.size < n
        str
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

      def seekable?
        @raw_io.pos
      rescue NoMethodError, Errno::ESPIPE, Errno::EPIPE
        nil
      end

      def seek(n)
        seek_raw(buffer_limited_n(n))
      end

      def read(n = nil)
        read_raw(buffer_limited_n(n))
      end

      def buffer_limited_n(n)
        if @buffer_end_pos
          max = @buffer_end_pos - offset
          n = max if n.nil? or n > max
        end

        n
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
        byte = read(1)
        raise EOFError, "End of file reached" if byte.nil?
        byte = byte.unpack('C').at(0) & 0xff

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
        byte = read(1)
        raise EOFError, "End of file reached" if byte.nil?
        byte = byte.unpack('C').at(0) & 0xff

        @rval = @rval | (byte << @rnbits)
        @rnbits += 8
      end

      def mask(nbits)
        (1 << nbits) - 1
      end

      # Use #seek and #pos on seekable streams
      module SeekableStream
        # Returns the current offset of the io stream.  Offset will be rounded
        # up when reading bitfields.
        def offset
          raw_io.pos - @initial_pos
        end

        # The number of bytes remaining in the input stream.
        def num_bytes_remaining
          mark = raw_io.pos
          raw_io.seek(0, ::IO::SEEK_END)
          bytes_remaining = raw_io.pos - mark
          raw_io.seek(mark, ::IO::SEEK_SET)

          bytes_remaining
        end

        #-----------
        private

        def read_raw(n)
          raw_io.read(n)
        end

        def seek_raw(n)
          raw_io.seek(n, ::IO::SEEK_CUR)
        end

        def raw_io
          @initial_pos ||= @raw_io.pos
          @raw_io
        end
      end

      # Manually keep track of offset for unseekable streams.
      module UnSeekableStream
        # Returns the current offset of the io stream.  Offset will be rounded
        # up when reading bitfields.
        def offset
          @read_count ||= 0
        end

        # The number of bytes remaining in the input stream.
        def num_bytes_remaining
          raise IOError, "stream is unseekable"
        end

        #-----------
        private

        def read_raw(n)
          @read_count ||= 0

          data = @raw_io.read(n)
          @read_count += data.size if data
          data
        end

        def seek_raw(n)
          raise IOError, "stream is unseekable" if n < 0

          # skip over data in 8k blocks
          while n > 0
            bytes_to_read = [n, 8192].min
            read_raw(bytes_to_read)
            n -= bytes_to_read
          end
        end
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
      def initialize(io)
        if BinData::IO::Write === io
          raise ArgumentError, "io must not be a BinData::IO::Write"
        end

        # wrap strings in a StringIO
        if io.respond_to?(:to_str)
          io = BinData::IO.create_string_io(io.to_str)
        end

        @raw_io = io

        @wnbits  = 0
        @wval    = 0
        @wendian = nil

        @write_count = 0

        @bytes_remaining = nil
      end

      # Sets a buffer of +n+ bytes on the io stream.  Any writes inside the
      # +block+ will be contained within this buffer.  If less than +n+ bytes
      # are written inside the block, the remainder will be padded with '\0'
      # bytes.
      def with_buffer(n, &block)
        prev = @bytes_remaining
        if prev
          n = prev if n > prev
          prev -= n
        end

        @bytes_remaining = n
        begin
          block.call
          write_raw("\0" * @bytes_remaining)
        ensure
          @bytes_remaining = prev
        end
      end

      # Returns the current offset of the io stream.  Offset will be rounded
      # up when writing bitfields.
      def offset
        @write_count + (@wnbits > 0 ? 1 : 0)
      end

      # Writes the given string of bytes to the io stream.
      def writebytes(str)
        flushbits
        write_raw(str)
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
      alias_method :flush, :flushbits

      #---------------
      private

      def write_big_endian_bits(val, nbits)
        while nbits > 0
          bits_req = 8 - @wnbits
          if nbits >= bits_req
            msb_bits = (val >> (nbits - bits_req)) & mask(bits_req)
            nbits -= bits_req
            val &= mask(nbits)

            @wval   = (@wval << bits_req) | msb_bits
            write_raw(@wval.chr)

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
            write_raw(@wval.chr)

            @wval   = 0
            @wnbits = 0
          else
            @wval   = @wval | (val << @wnbits)
            @wnbits += nbits
            nbits = 0
          end
        end
      end

      def write_raw(data)
        if @bytes_remaining
          if data.size > @bytes_remaining
            data = data[0, @bytes_remaining]
          end
          @bytes_remaining -= data.size
        end

        @write_count += data.size
        @raw_io.write(data)
      end

      def mask(nbits)
        (1 << nbits) - 1
      end
    end
  end
end
