#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Section do
  it "transforms data byte at a time" do
    require 'bindata/transform/xor'

    obj = BinData::Section.new(transform: -> { BinData::Transform::Xor.new(0xff) },
                               type: [:string, read_length: 5])

    _(obj.read("\x97\x9A\x93\x93\x90")).must_equal "hello"
  end

  begin
    require 'brotli'
    it "transform brotli" do
      require 'bindata/transform/brotli'

      class BrotliRecord < BinData::Record
        int32le :len, value: -> { s.num_bytes }
        section :s, transform: -> { BinData::Transform::Brotli.new(len) } do
          int32le :str_len, value: -> { str.length }
          string :str, read_length: :str_len

        end
      end

      obj = BrotliRecord.new
      data = "highly compressible" * 100
      obj.s.str = data
      _(obj.len).must_be :<, (data.length / 10)

      str =  obj.to_binary_s
      obj = BrotliRecord.read(str)
      _(obj.s.str).must_equal data
    end
  rescue LoadError; end

  begin
    require 'extlz4'
    it "transform lz4" do
      require 'bindata/transform/lz4'

      class LZ4Record < BinData::Record
        int32le :len, value: -> { s.num_bytes }
        section :s, transform: -> { BinData::Transform::LZ4.new(len) } do
          int32le :str_len, value: -> { str.length }
          string :str, read_length: :str_len

        end
      end

      obj = LZ4Record.new
      data = "highly compressible" * 100
      obj.s.str = data
      _(obj.len).must_be :<, (data.length / 10)

      str =  obj.to_binary_s
      obj = LZ4Record.read(str)
      _(obj.s.str).must_equal data
    end
  rescue LoadError; end

  it "transform zlib" do
    require 'bindata/transform/zlib'

    class ZlibRecord < BinData::Record
      int32le :len, value: -> { s.num_bytes }
      section :s, transform: -> { BinData::Transform::Zlib.new(len) } do
        int32le :str_len, value: -> { str.length }
        string :str, read_length: :str_len

      end
    end

    obj = ZlibRecord.new
    data = "highly compressible" * 100
    obj.s.str = data
    _(obj.len).must_be :<, (data.length / 10)

    str =  obj.to_binary_s
    obj = ZlibRecord.read(str)
    _(obj.s.str).must_equal data
  end

  begin
    require 'zstd-ruby'
    it "transform zstd" do
      require 'bindata/transform/zstd'

      class ZstdRecord < BinData::Record
        int32le :len, value: -> { s.num_bytes }
        section :s, transform: -> { BinData::Transform::Zstd.new(len) } do
          int32le :str_len, value: -> { str.length }
          string :str, read_length: :str_len

        end
      end

      obj = ZstdRecord.new
      data = "highly compressible" * 100
      obj.s.str = data
      _(obj.len).must_be :<, (data.length / 10)

      str =  obj.to_binary_s
      obj = ZstdRecord.read(str)
      _(obj.s.str).must_equal data
    end
  rescue LoadError; end
end
