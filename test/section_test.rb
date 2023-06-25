#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Section do
  it "transforms data byte at a time" do
    class XorTransform < BinData::IO::Transform
      def initialize(xor)
        super()
        @xor = xor
      end

      def read(n)
        chain_read(n).bytes.map { |byte| (byte ^ @xor).chr }.join
      end

      def write(data)
        chain_write(data.bytes.map { |byte| (byte ^ @xor).chr }.join)
      end
    end

    obj = BinData::Section.new(transform: -> { XorTransform.new(0xff) },
                               type: [:string, read_length: 5])

    _(obj.read("\x97\x9A\x93\x93\x90")).must_equal "hello"
  end

  it "expands data" do
    class ZlibTransform < BinData::IO::Transform
      require 'zlib'

      transform_changes_stream_length!

      def initialize(read_length)
        super()
        @length = read_length
      end

      def read(n)
        @read ||= Zlib::Inflate.inflate(chain_read(@length))
        @read.slice!(0...n)
      end

      def write(data)
        @write ||= create_empty_binary_string
        @write << data
      end

      def after_read_transform
        raise IOError, "didn't read all data" unless @read.empty?
      end

      def after_write_transform
        chain_write(Zlib::Deflate.deflate(@write))
      end
    end

    class ZlibRecord < BinData::Record
      int32le :len, value: -> { s.num_bytes }
      section :s, transform: -> { ZlibTransform.new(len) } do
        int32le :str_len, value: -> { str.length }
        string :str, read_length: :str_len

      end
    end

    obj = ZlibRecord.new
    data = "highly compressable" * 100
    obj.s.str = data
    _(obj.len).must_be :<, (data.length / 10)

    str =  obj.to_binary_s
    obj = ZlibRecord.read(str)
    _(obj.s.str).must_equal data
  end
end
