require 'bindata'
require 'forwardable'

# An example of a reader / writer for the GZIP file format as per rfc1952.
# Note that compression is not implemented to keep the example small.
class Gzip
  extend Forwardable

  # Known compression methods
  DEFLATE = 8

  class Extra < BinData::Record
    endian :little

    uint16 :len,  :length => lambda { data.length }
    string :data, :read_length => :len
  end

  class Header < BinData::Record
    endian :little

    uint16  :ident,      :value => 0x8b1f, :check_value => 0x8b1f
    uint8   :compression_method, :initial_value => DEFLATE

    bit3    :freserved,  :value => 0, :check_value => 0
    bit1    :fcomment,   :value => lambda { comment.length > 0 ? 1 : 0 }
    bit1    :ffile_name, :value => lambda { file_name.length > 0 ? 1 : 0 }
    bit1    :fextra,     :value => lambda { extra.len > 0 ? 1 : 0 }
    bit1    :fcrc16,     :value => 0  # see comment below
    bit1    :ftext

    # Never include header crc.  This is because the current versions of the
    # command-line version of gzip (up through version 1.3.x) do not
    # support header crc's, and will report that it is a "multi-part gzip
    # file" and give up.

    uint32  :mtime
    uint8   :extra_flags
    uint8   :os,         :initial_value => 255   # unknown OS

    # These fields are optional depending on the bits in flags
    extra   :extra,      :onlyif => lambda { fextra.nonzero? }
    stringz :file_name,  :onlyif => lambda { ffile_name.nonzero? }
    stringz :comment,    :onlyif => lambda { fcomment.nonzero? }
    uint16  :crc16,      :onlyif => lambda { fcrc16.nonzero? }
  end

  class Footer < BinData::Record
    endian :little

    uint32 :crc32
    uint32 :uncompressed_size
  end

  def initialize
    @header = Header.new
    @footer = Footer.new
  end

  attr_accessor :compressed
  def_delegators :@header, :file_name=, :file_name
  def_delegators :@header, :comment=, :comment
  def_delegators :@header, :compression_method
  def_delegators :@footer, :crc32, :uncompressed_size

  def mtime
    Time.at(@header.mtime.snapshot)
  end

  def mtime=(tm)
    @header.mtime = tm.to_i
  end

  def total_size
    @header.num_bytes + @compressed.size + @footer.num_bytes
  end

  def compressed_data
    @compressed
  end

  def set_compressed_data(compressed, crc32, uncompressed_size)
    @compressed               = compressed
    @footer.crc32             = crc32
    @footer.uncompressed_size = uncompressed_size
  end

  def read(file_name)
    File.open(file_name, "r") do |io|
      @header.read(io)

      # Determine the size of the compressed data.  This is needed because
      # we don't actually uncompress the data.  Ideally the uncompression
      # method would read the correct number of bytes from the IO and the
      # IO would be positioned ready to read the footer.

      pos = io.pos
      io.seek(-@footer.num_bytes, IO::SEEK_END)
      compressed_size = io.pos - pos
      io.seek(pos)

      @compressed = io.read(compressed_size)
      @footer.read(io)
    end
  end

  def write(file_name)
    File.open(file_name, "w") do |io|
      @header.write(io)
      io.write(@compressed)
      @footer.write(io)
    end
  end
end

if __FILE__ == $0
  # Write a gzip file.
  print "Creating a gzip file ... "
  g = Gzip.new
  # Uncompressed data is "the cat sat on the mat"
  g.set_compressed_data("+\311HUHN,Q(\006\342\374<\205\022 77\261\004\000",
                        3464689835, 22)
  g.file_name = "poetry"
  g.mtime = Time.now
  g.comment = "A stunning piece of prose"
  g.write("poetry.gz")
  puts "done."
  puts

  # Read the created gzip file.
  print "Reading newly created gzip file ... "
  g = Gzip.new
  g.read("poetry.gz")
  puts "done."
  puts

  puts "Printing gzip file details in the format of gzip -l -v"

  # compression ratio
  ratio = 100.0 * (g.uncompressed_size - g.compressed.size) /
            g.uncompressed_size

  comp_meth = (g.compression_method == Gzip::DEFLATE) ? "defla" : ""

  # Output using the same format as gzip -l -v
  puts "method  crc     date  time           compressed        " +
       "uncompressed  ratio uncompressed_name"
  puts "%5s %08x %6s %5s %19s %19s %5.1f%% %s"  % [comp_meth,
                                                   g.crc32,
                                                   g.mtime.strftime('%b %d'),
                                                   g.mtime.strftime('%H:%M'),
                                                   g.total_size,
                                                   g.uncompressed_size,
                                                   ratio,
                                                   g.file_name]
  puts "Comment: #{g.comment}" if g.comment != ""
  puts

  puts "Executing gzip -l -v"
  puts `gzip -l -v poetry.gz`
end
