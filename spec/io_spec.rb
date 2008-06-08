#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/io'

describe BinData::IO do
  it "should wrap strings in StringIO" do
    io = BinData::IO.new("abcd")
    io.raw_io.class.should == StringIO
  end

  it "should not wrap IO objects" do
    stream = StringIO.new
    io = BinData::IO.new(stream)
    io.raw_io.should == stream
  end

  it "should return correct offset" do
    stream = StringIO.new("abcdefghij")
    stream.seek(3, IO::SEEK_CUR)

    io = BinData::IO.new(stream)
    io.offset.should == 0
    io.readbytes(4)
    io.offset.should == 4
  end

  it "should seek" do
    stream = StringIO.new("abcdefghij")
    io = BinData::IO.new(stream)

    io.seekbytes(2)
    io.readbytes(4).should == "cdef"
  end

  it "should raise error when reading at eof" do
    stream = StringIO.new("abcdefghij")
    io = BinData::IO.new(stream)
    io.seekbytes(10)
    lambda {
      io.readbytes(3)
    }.should raise_error(EOFError)
  end

  it "should raise error on short reads" do
    stream = StringIO.new("abcdefghij")
    io = BinData::IO.new(stream)
    lambda {
      io.readbytes(20)
    }.should raise_error(IOError)
  end

  it "should write" do
    stream = StringIO.new
    io = BinData::IO.new(stream)
    io.write("abcd")

    stream.rewind
    stream.read.should == "abcd"
  end
end
