#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/io'

describe BinData::IO, "reading from non seekable stream" do
  before(:each) do
    @rd, @wr = IO::pipe
    if fork
      # parent
      @wr.close
      @io = BinData::IO.new(@rd)
    else
      # child
      begin
        @rd.close
        @wr.write "a" * 5000
        @wr.write "b" * 5000
        @wr.close
      rescue Exception
        # ignore it
      ensure
        exit!
      end
    end
  end

  after(:each) do
    @rd.close
    Process.wait
  end

  it "should always have an offset of 0" do
    @io.readbytes(10)
    @io.offset.should == 0
  end

  it "should seek" do
    @io.seekbytes(4999)
    @io.readbytes(5).should == "abbbb"
  end
end

describe BinData::IO, "when reading" do
  let(:stream) { StringIO.new "abcdefghij" }
  let(:io) { BinData::IO.new(stream) }

  it "should wrap strings in StringIO" do
    io.raw_io.class.should == StringIO
  end

  it "should not wrap IO objects" do
    io.raw_io.should == stream
  end

  it "should raise error when io is BinData::IO" do
    lambda {
      BinData::IO.new(BinData::IO.new(""))
    }.should raise_error(ArgumentError)
  end

  it "should return correct offset" do
    stream.seek(3, IO::SEEK_CUR)

    io.offset.should == 0
    io.readbytes(4).should == "defg"
    io.offset.should == 4
  end

  it "should seek" do
    io.seekbytes(2)
    io.readbytes(4).should == "cdef"
  end

  it "should read all bytes" do
    io.read_all_bytes.should == "abcdefghij"
  end

  it "should raise error when reading at eof" do
    io.seekbytes(10)
    lambda {
      io.readbytes(3)
    }.should raise_error(EOFError)
  end

  it "should raise error on short reads" do
    lambda {
      io.readbytes(20)
    }.should raise_error(IOError)
  end
end

describe BinData::IO, "when writing" do
  let(:stream) { StringIO.new }
  let(:io) { BinData::IO.new(stream) }

  it "should not wrap IO objects" do
    io.raw_io.should == stream
  end

  it "should raise error when io is BinData::IO" do
    lambda {
      BinData::IO.new(BinData::IO.new(""))
    }.should raise_error(ArgumentError)
  end

  it "should write" do
    io.writebytes("abcd")

    stream.value.should == "abcd"
  end

  it "should flush" do
    io.writebytes("abcd")
    io.flush

    stream.value.should == "abcd"
  end
end

describe BinData::IO, "reading bits in big endian" do
  let(:b1) { 0b1111_1010 }
  let(:b2) { 0b1100_1110 }
  let(:b3) { 0b0110_1010 }
  let(:io) { BinData::IO.new([b1, b2, b3].pack("CCC")) }

  it "should read a bitfield less than 1 byte" do
    io.readbits(3, :big).should == 0b111
  end

  it "should read a bitfield more than 1 byte" do
    io.readbits(10, :big).should == 0b1111_1010_11
  end

  it "should read a bitfield more than 2 bytes" do
    io.readbits(17, :big).should == 0b1111_1010_1100_1110_0
  end

  it "should read two bitfields totalling less than 1 byte" do
    io.readbits(5, :big).should == 0b1111_1
    io.readbits(2, :big).should == 0b01
  end

  it "should read two bitfields totalling more than 1 byte" do
    io.readbits(6, :big).should == 0b1111_10
    io.readbits(8, :big).should == 0b10_1100_11
  end

  it "should read two bitfields totalling more than 2 bytes" do
    io.readbits(7, :big).should == 0b1111_101
    io.readbits(12, :big).should == 0b0_1100_1110_011
  end

  it "should ignore unused bits when reading bytes" do
    io.readbits(3, :big).should == 0b111
    io.readbytes(1).should == [b2].pack("C")
    io.readbits(2, :big).should == 0b01
  end

  it "should reset read bits to realign stream to next byte" do
    io.readbits(3, :big).should == 0b111
    io.reset_read_bits
    io.readbits(3, :big).should == 0b110
  end
end

describe BinData::IO, "reading bits in little endian" do
  let(:b1) { 0b1111_1010 }
  let(:b2) { 0b1100_1110 }
  let(:b3) { 0b0110_1010 }
  let(:io) { BinData::IO.new([b1, b2, b3].pack("CCC")) }

  it "should read a bitfield less than 1 byte" do
    io.readbits(3, :little).should == 0b010
  end

  it "should read a bitfield more than 1 byte" do
    io.readbits(10, :little).should == 0b10_1111_1010
  end

  it "should read a bitfield more than 2 bytes" do
    io.readbits(17, :little).should == 0b0_1100_1110_1111_1010
  end

  it "should read two bitfields totalling less than 1 byte" do
    io.readbits(5, :little).should == 0b1_1010
    io.readbits(2, :little).should == 0b11
  end

  it "should read two bitfields totalling more than 1 byte" do
    io.readbits(6, :little).should == 0b11_1010
    io.readbits(8, :little).should == 0b00_1110_11
  end

  it "should read two bitfields totalling more than 2 bytes" do
    io.readbits(7, :little).should == 0b111_1010
    io.readbits(12, :little).should == 0b010_1100_1110_1
  end

  it "should ignore unused bits when reading bytes" do
    io.readbits(3, :little).should == 0b010
    io.readbytes(1).should == [b2].pack("C")
    io.readbits(2, :little).should == 0b10
  end

  it "should reset read bits to realign stream to next byte" do
    io.readbits(3, :little).should == 0b010
    io.reset_read_bits
    io.readbits(3, :little).should == 0b110
  end
end

class BitWriterHelper
  def initialize
    @stringio = BinData::IO.create_string_io
    @io = BinData::IO.new(@stringio)
  end

  def writebits(val, nbits, endian)
    @io.writebits(val, nbits, endian)
  end

  def writebytes(val)
    @io.writebytes(val)
  end

  def value
    @io.flushbits
    @stringio.rewind
    @stringio.read
  end
end

describe BinData::IO, "writing bits in big endian" do
  let(:io) { BitWriterHelper.new }

  it "should write a bitfield less than 1 byte" do
    io.writebits(0b010, 3, :big)
    io.value.should == [0b0100_0000].pack("C")
  end

  it "should write a bitfield more than 1 byte" do
    io.writebits(0b10_1001_1101, 10, :big)
    io.value.should == [0b1010_0111, 0b0100_0000].pack("CC")
  end

  it "should write a bitfield more than 2 bytes" do
    io.writebits(0b101_1000_0010_1001_1101, 19, :big)
    io.value.should == [0b1011_0000, 0b0101_0011, 0b1010_0000].pack("CCC")
  end

  it "should write two bitfields totalling less than 1 byte" do
    io.writebits(0b1_1001, 5, :big)
    io.writebits(0b00, 2, :big)
    io.value.should == [0b1100_1000].pack("C")
  end

  it "should write two bitfields totalling more than 1 byte" do
    io.writebits(0b01_0101, 6, :big)
    io.writebits(0b001_1001, 7, :big)
    io.value.should == [0b0101_0100, 0b1100_1000].pack("CC")
  end

  it "should write two bitfields totalling more than 2 bytes" do
    io.writebits(0b01_0111, 6, :big)
    io.writebits(0b1_0010_1001_1001, 13, :big)
    io.value.should == [0b0101_1110, 0b0101_0011, 0b0010_0000].pack("CCC")
  end

  it "should pad unused bits when writing bytes" do
    io.writebits(0b101, 3, :big)
    io.writebytes([0b1011_1111].pack("C"))
    io.writebits(0b01, 2, :big)

    io.value.should == [0b1010_0000, 0b1011_1111, 0b0100_0000].pack("CCC")
  end
end

describe BinData::IO, "writing bits in little endian" do
  let(:io) { BitWriterHelper.new }

  it "should write a bitfield less than 1 byte" do
    io.writebits(0b010, 3, :little)
    io.value.should == [0b0000_0010].pack("C")
  end

  it "should write a bitfield more than 1 byte" do
    io.writebits(0b10_1001_1101, 10, :little)
    io.value.should == [0b1001_1101, 0b0000_0010].pack("CC")
  end

  it "should write a bitfield more than 2 bytes" do
    io.writebits(0b101_1000_0010_1001_1101, 19, :little)
    io.value.should == [0b1001_1101, 0b1000_0010, 0b0000_0101].pack("CCC")
  end

  it "should write two bitfields totalling less than 1 byte" do
    io.writebits(0b1_1001, 5, :little)
    io.writebits(0b00, 2, :little)
    io.value.should == [0b0001_1001].pack("C")
  end

  it "should write two bitfields totalling more than 1 byte" do
    io.writebits(0b01_0101, 6, :little)
    io.writebits(0b001_1001, 7, :little)
    io.value.should == [0b0101_0101, 0b0000_0110].pack("CC")
  end

  it "should write two bitfields totalling more than 2 bytes" do
    io.writebits(0b01_0111, 6, :little)
    io.writebits(0b1_0010_1001_1001, 13, :little)
    io.value.should == [0b0101_0111, 0b1010_0110, 0b0000_0100].pack("CCC")
  end

  it "should pad unused bits when writing bytes" do
    io.writebits(0b101, 3, :little)
    io.writebytes([0b1011_1111].pack("C"))
    io.writebits(0b01, 2, :little)

    io.value.should == [0b0000_0101, 0b1011_1111, 0b0000_0001].pack("CCC")
  end
end

describe BinData::IO, "with changing endian" do
  it "should not mix different endianess when reading" do
    b1 = 0b0110_1010
    b2 = 0b1110_0010
    str = [b1, b2].pack("CC")
    io = BinData::IO.new(str)

    io.readbits(3, :big).should == 0b011
    io.readbits(4, :little).should == 0b0010
  end

  it "should not mix different endianess when writing" do
    io = BitWriterHelper.new
    io.writebits(0b110, 3, :big)
    io.writebits(0b010, 3, :little)
    io.value.should == [0b1100_0000, 0b0000_0010].pack("CC")
  end
end
