#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/io'
require 'bindata/string'

describe BinData::String, "with mutually exclusive parameters" do
  it ":value and :initial_value" do
    params = {:value => "", :initial_value => ""}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  it ":length and :read_length" do
    params = {:length => 5, :read_length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  it ":value and :length" do
    params = {:value => "", :length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

describe BinData::String, "with deprecated parameters" do
  it "should substitude :trim_padding for :trim_value" do
    obj = BinData::String.new(:trim_value => true)
    obj.value = "abc\0"
    obj.value.should == "abc"
  end
end

describe BinData::String, "when assigning" do
  before(:each) do
    @small = BinData::String.new(:length => 3, :pad_char => "A")
    @large = BinData::String.new(:length => 5, :pad_char => "B")
  end

  it "should copy data from small to large" do
    @large.value = @small
    @large.value.should == "AAABB"
  end

  it "should copy data from large to small" do
    @small.value = @large
    @small.value.should == "BBB"
  end
end

describe BinData::String, "with :read_length" do
  before(:each) do
    @str = BinData::String.new(:read_length => 5)
  end

  it "should have default value" do
    @str.num_bytes.should == 0
    @str.value.should == ""
  end

  it "should read :read_length bytes" do
    @str.read("abcdefghij")
    @str.value.should == "abcde"
  end

  it "should remember :read_length after value is cleared" do
    @str.value = "abc"
    @str.num_bytes.should == 3
    @str.clear

    @str.read("abcdefghij")
    @str.value.should == "abcde"
  end
end

describe BinData::String, "with :length" do
  before(:each) do
    @str = BinData::String.new(:length => 5)
  end

  it "should set num_bytes" do
    @str.num_bytes.should == 5
  end

  it "should fill value with pad_char" do
    @str.value.should == "\0\0\0\0\0"
  end

  it "should retain :length after value is set" do
    @str.value = "abcdefghij"
    @str.num_bytes.should == 5
  end

  it "should read :length bytes" do
    @str.read("abcdefghij")
    @str.value.should == "abcde"
  end

  it "should pad values less than :length" do
    @str.value = "abc"
    @str.value.should == "abc\0\0"
  end

  it "should accept values exactly :length" do
    @str.value = "abcde"
    @str.value.should == "abcde"
  end

  it "should truncate values greater than :length" do
    @str.value = "abcdefg"
    @str.value.should == "abcde"
  end
end

describe BinData::String, "with :read_length and :initial_value" do
  before(:each) do
    @str = BinData::String.new(:read_length => 5, :initial_value => "abcdefghij")
  end

  it "should use :initial_value before value is read" do
    @str.num_bytes.should == 10
    @str.value.should == "abcdefghij"
  end

  it "should use :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should == 5
   end

  it "should forget :initial_value after reading" do
    @str.read("ABCDEFGHIJKLMNOPQRST")
    @str.num_bytes.should == 5
    @str.value.should == "ABCDE"
  end

end

describe BinData::String, "with :read_length and :value" do
  before(:each) do
    @str = BinData::String.new(:read_length => 5, :value => "abcdefghij")
    @str.expose_methods_for_testing
  end

  it "should not be affected by :read_length before value is read" do
    @str.num_bytes.should == 10
    @str.value.should == "abcdefghij"
  end

  it "should use :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should == 5
   end

  it "should not be affected by :read_length after reading" do
    @str.read("ABCDEFGHIJKLMNOPQRST")
    @str.num_bytes.should == 10
    @str.value.should == "abcdefghij"
  end

  it "should return read value before calling done_read" do
    @str.do_read(BinData::IO.new("ABCDEFGHIJKLMNOPQRST"))
    @str.value.should == "ABCDE"

    @str.done_read
    @str.value.should == "abcdefghij"
  end
end

describe BinData::String, "with :length and :initial_value" do
  before(:each) do
    @str = BinData::String.new(:length => 5, :initial_value => "abcdefghij")
  end

  it "should apply :length to :initial_value" do
    @str.num_bytes.should == 5
    @str.value.should == "abcde"
  end

  it "should forget :initial_value after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should == 5
    @str.num_bytes.should == 5
    @str.value.should == "ABCDE"
  end
end

describe BinData::String, "with :pad_char" do
  it "should accept a numeric value for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => 6)
    @str.value = "abc"
    @str.value.should == "abc\x06\x06"
  end

  it "should accept a character for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => "R")
    @str.value = "abc"
    @str.value.should == "abcRR"
  end

  it "should not accept a string for :pad_char" do
    params = {:length => 5, :pad_char => "RR"}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

describe BinData::String, "with :trim_padding" do
  it "set false is the default" do
    str1 = BinData::String.new(:length => 5)
    str2 = BinData::String.new(:length => 5, :trim_padding => false)
    str1.value = "abc"
    str2.value = "abc"
    str1.value.should == "abc\0\0"
    str2.value.should == "abc\0\0"
  end

  it "should trim the value" do
    str = BinData::String.new(:pad_char => 'R', :trim_padding => true)
    str.value = "abcRR"
    str.value.should == "abc"
  end

  it "should not affect num_bytes" do
    str = BinData::String.new(:pad_char => 'R', :trim_padding => true)
    str.value = "abcRR"
    str.num_bytes.should == 5
  end

  it "should trim if last char is :pad_char" do
    str = BinData::String.new(:pad_char => 'R', :trim_padding => true)
    str.value = "abcRR"
    str.value.should == "abc"
  end

  it "should not trim if value contains :pad_char not at the end" do
    str = BinData::String.new(:pad_char => 'R', :trim_padding => true)
    str.value = "abcRRde"
    str.value.should == "abcRRde"
  end
end
