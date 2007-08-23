#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/stringz'

describe "An empty Stringz data object" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should include the zero byte in num_bytes total" do
    @str.num_bytes.should eql(1)
  end

  it "should not append the zero byte terminator to the value" do
    @str.value.should eql("")
  end

  it "should write the zero byte terminator" do
    io = StringIO.new
    @str.write(io)
    io.rewind
    io.read.should eql("\0")
  end
end

describe "A Stringz data object with value set" do
  before(:each) do
    @str = BinData::Stringz.new
    @str.value = "abcd"
  end

  it "should include the zero byte in num_bytes total" do
    @str.num_bytes.should eql(5)
  end

  it "should not append the zero byte terminator to the value" do
    @str.value.should eql("abcd")
  end

  it "should write the zero byte terminator" do
    io = StringIO.new
    @str.write(io)
    io.rewind
    io.read.should eql("abcd\0")
  end
end

describe "Reading with a Stringz data object" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should stop at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    @str.read(io)
    @str.value.should eql("abcd")
    io.read(1).should eql("x")
  end

  it "should handle a zero length string" do
    io = StringIO.new("\0abcd")
    @str.read(io)
    @str.value.should eql("")
    io.read(1).should eql("a")
  end

  it "should fail if no zero byte is found" do
    io = StringIO.new("abcd")
    lambda {@str.read(io) }.should raise_error(EOFError)
  end
end

describe "Setting the value of a Stringz data object" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should include the zero byte in num_bytes total" do
    @str.value = "abcd"
    @str.num_bytes.should eql(5)
  end

  it "should accept empty strings" do
    @str.value = ""
    @str.value.should eql("")
  end

  it "should accept strings that aren't zero terminated" do
    @str.value = "abcd"
    @str.value.should eql("abcd")
  end

  it "should accept strings that are zero terminated" do
    @str.value = "abcd\0"
    @str.value.should eql("abcd")
  end

  it "should accept up to the first zero byte" do
    @str.value = "abcd\0xyz\0"
    @str.value.should eql("abcd")
  end
end

describe "A Stringz data object with max_length" do
  before(:each) do
    @str = BinData::Stringz.new(:max_length => 5)
  end

  it "should read less than max_length" do
    io = StringIO.new("abc\0xyz")
    @str.read(io)
    @str.value.should eql("abc")
  end

  it "should read exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    @str.read(io)
    @str.value.should eql("abcd")
  end

  it "should read no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    @str.read(io)
    @str.value.should eql("abcd")
    io.read(1).should eql("f")
  end

  it "should accept values less than max_length" do
    @str.value = "abc"
    @str.value.should eql("abc")
  end

  it "should accept values exactly max_length" do
    @str.value = "abcd"
    @str.value.should eql("abcd")
  end

  it "should trim values greater than max_length" do
    @str.value = "abcde"
    @str.value.should eql("abcd")
  end

  it "should write values less than max_length" do
    io = StringIO.new
    @str.value = "abc"
    @str.write(io)
    io.rewind
    io.read.should eql("abc\0")
  end

  it "should write values exactly max_length" do
    io = StringIO.new
    @str.value = "abcd"
    @str.write(io)
    io.rewind
    io.read.should eql("abcd\0")
  end
end
