#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/stringz'

describe BinData::Stringz, "when empty" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should include the zero byte in num_bytes total" do
    @str.num_bytes.should == 1
  end

  it "should not append the zero byte terminator to the value" do
    @str.value.should == ""
  end

  it "should write the zero byte terminator" do
    @str.to_binary_s.should == "\0"
  end
end

describe BinData::Stringz, "with value set" do
  before(:each) do
    @str = BinData::Stringz.new
    @str.value = "abcd"
  end

  it "should include the zero byte in num_bytes total" do
    @str.num_bytes.should == 5
  end

  it "should not append the zero byte terminator to the value" do
    @str.value.should == "abcd"
  end

  it "should write the zero byte terminator" do
    @str.to_binary_s.should == "abcd\0"
  end
end

describe BinData::Stringz, "when reading" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should stop at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    @str.read(io)
    @str.value.should == "abcd"
    io.read(1).should == "x"
  end

  it "should handle a zero length string" do
    io = StringIO.new("\0abcd")
    @str.read(io)
    @str.value.should == ""
    io.read(1).should == "a"
  end

  it "should fail if no zero byte is found" do
    lambda {@str.read("abcd") }.should raise_error(EOFError)
  end
end

describe BinData::Stringz, " when setting the value" do
  before(:each) do
    @str = BinData::Stringz.new
  end

  it "should include the zero byte in num_bytes total" do
    @str.value = "abcd"
    @str.num_bytes.should == 5
  end

  it "should accept empty strings" do
    @str.value = ""
    @str.value.should == ""
  end

  it "should accept strings that aren't zero terminated" do
    @str.value = "abcd"
    @str.value.should == "abcd"
  end

  it "should accept strings that are zero terminated" do
    @str.value = "abcd\0"
    @str.value.should == "abcd"
  end

  it "should accept up to the first zero byte" do
    @str.value = "abcd\0xyz\0"
    @str.value.should == "abcd"
  end
end

describe BinData::Stringz, "with max_length" do
  before(:each) do
    @str = BinData::Stringz.new(:max_length => 5)
  end

  it "should read less than max_length" do
    io = StringIO.new("abc\0xyz")
    @str.read(io)
    @str.value.should == "abc"
  end

  it "should read exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    @str.read(io)
    @str.value.should == "abcd"
  end

  it "should read no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    @str.read(io)
    @str.value.should == "abcd"
    io.read(1).should == "f"
  end

  it "should accept values less than max_length" do
    @str.value = "abc"
    @str.value.should == "abc"
  end

  it "should accept values exactly max_length" do
    @str.value = "abcd"
    @str.value.should == "abcd"
  end

  it "should trim values greater than max_length" do
    @str.value = "abcde"
    @str.value.should == "abcd"
  end

  it "should write values greater than max_length" do
    @str.value = "abcde"
    @str.to_binary_s.should == "abcd\0"
  end

  it "should write values less than max_length" do
    @str.value = "abc"
    @str.to_binary_s.should == "abc\0"
  end

  it "should write values exactly max_length" do
    @str.value = "abcd"
    @str.to_binary_s.should == "abcd\0"
  end
end
