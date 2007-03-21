#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/stringz'

context "An empty Stringz data object" do
  setup do
    @str = BinData::Stringz.new
  end

  specify "should include the zero byte in num_bytes total" do
    @str.num_bytes.should eql(1)
  end

  specify "should not append the zero byte terminator to the value" do
    @str.value.should eql("")
  end

  specify "should write the zero byte terminator" do
    io = StringIO.new
    @str.write(io)
    io.rewind
    io.read.should eql("\0")
  end
end

context "A Stringz data object with value set" do
  setup do
    @str = BinData::Stringz.new
    @str.value = "abcd"
  end

  specify "should include the zero byte in num_bytes total" do
    @str.num_bytes.should eql(5)
  end

  specify "should not append the zero byte terminator to the value" do
    @str.value.should eql("abcd")
  end

  specify "should write the zero byte terminator" do
    io = StringIO.new
    @str.write(io)
    io.rewind
    io.read.should eql("abcd\0")
  end
end

context "Reading with a Stringz data object" do
  setup do
    @str = BinData::Stringz.new
  end

  specify "should stop at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    @str.read(io)
    @str.value.should eql("abcd")
    io.read(1).should eql("x")
  end

  specify "should handle a zero length string" do
    io = StringIO.new("\0abcd")
    @str.read(io)
    @str.value.should eql("")
    io.read(1).should eql("a")
  end

  specify "should fail if no zero byte is found" do
    io = StringIO.new("abcd")
    lambda {@str.read(io) }.should raise_error(EOFError)
  end
end

context "Setting the value of a Stringz data object" do
  setup do
    @str = BinData::Stringz.new
  end

  specify "should include the zero byte in num_bytes total" do
    @str.value = "abcd"
    @str.num_bytes.should eql(5)
  end

  specify "should accept empty strings" do
    @str.value = ""
    @str.value.should eql("")
  end

  specify "should accept strings that aren't zero terminated" do
    @str.value = "abcd"
    @str.value.should eql("abcd")
  end

  specify "should accept strings that are zero terminated" do
    @str.value = "abcd\0"
    @str.value.should eql("abcd")
  end

  specify "should accept up to the first zero byte" do
    @str.value = "abcd\0xyz\0"
    @str.value.should eql("abcd")
  end
end

context "A Stringz data object with max_length" do
  setup do
    @str = BinData::Stringz.new(:max_length => 5)
  end

  specify "should read less than max_length" do
    io = StringIO.new("abc\0xyz")
    @str.read(io)
    @str.value.should eql("abc")
  end

  specify "should read exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    @str.read(io)
    @str.value.should eql("abcd")
  end

  specify "should read no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    @str.read(io)
    @str.value.should eql("abcd")
    io.read(1).should eql("f")
  end

  specify "should accept values less than max_length" do
    @str.value = "abc"
    @str.value.should eql("abc")
  end

  specify "should accept values exactly max_length" do
    @str.value = "abcd"
    @str.value.should eql("abcd")
  end

  specify "should trim values greater than max_length" do
    @str.value = "abcde"
    @str.value.should eql("abcd")
  end

  specify "should write values less than max_length" do
    io = StringIO.new
    @str.value = "abc"
    @str.write(io)
    io.rewind
    io.read.should eql("abc\0")
  end

  specify "should write values exactly max_length" do
    io = StringIO.new
    @str.value = "abcd"
    @str.write(io)
    io.rewind
    io.read.should eql("abcd\0")
  end
end
