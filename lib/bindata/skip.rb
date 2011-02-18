require "bindata/base_primitive"

module BinData
  # Skip will skip over bytes from the input stream.  If the stream is not
  # seekable, then the bytes are consumed and discarded.
  #
  # When writing, skip will write <tt>:length</tt> number of zero bytes.
  #
  #   require 'bindata'
  #
  #   class A < BinData::Record
  #     skip :length => 5
  #     string :a, :read_length => 5
  #   end
  #
  #   obj = A.read("abcdefghij")
  #   obj.a #=> "fghij"
  #
  # == Parameters
  #
  # Skip objects accept all the params that BinData::BasePrimitive
  # does, as well as the following:
  #
  # <tt>:length</tt>:: The number of bytes to skip.
  #
  class Skip < BinData::BasePrimitive

    mandatory_parameter :length

    #---------------
    private

    def value_to_binary_string(val)
      len = eval_parameter(:length)
      "\000" * len
    end

    def read_and_return_value(io)
      len = eval_parameter(:length)
      io.seekbytes(len)
      ""
    end

    def sensible_default
      ""
    end
  end
end
