require 'bindata/base'
require 'bindata/single'

class ExampleSingle < BinData::Single
  register(self.name, self)

  private

  def value_to_string(val)
    [val].pack("V")
  end

  def read_and_return_value(io)
    io.readbytes(4).unpack("V").at(0)
  end

  def sensible_default
    0
  end
end

class ExampleMulti < BinData::Base
  register(self.name, self)

  def initialize(params = {}, parent = nil)
    super(params, parent)

    @a = ExampleSingle.new
    @b = ExampleSingle.new
  end

  def set_value(a, b)
    @a.value = a
    @b.value = b
  end

  def get_value
    [@a.value, @b.value]
  end

  def single_value?
    false
  end

  def clear
    @a.clear
    @b.clear
  end

  def clear?
    @a.clear? and @b.clear?
  end

  #-----------------
  private

  def _do_read(io)
    @a.do_read(io)
    @b.do_read(io)
  end

  def _done_read
    @a.done_read
    @b.done_read
  end

  def _do_write(io)
    @a.do_write(io)
    @b.done_read
  end

  def _do_num_bytes(what)
    @a.do_num_bytes + @b.do_num_bytes
  end

  def _snapshot
    [@a.snapshot, @b.snapshot]
  end
end
