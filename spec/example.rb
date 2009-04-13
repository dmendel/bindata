require 'bindata/base'
require 'bindata/single'

class ExampleSingle < BinData::Single
  register(self.name, self)

  private

  def value_to_binary_string(val)
    [val].pack("V")
  end

  def read_and_return_value(io)
    io.readbytes(4).unpack("V").at(0)
  end

  def sensible_default
    0
  end
end
