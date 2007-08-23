#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/string'

describe "Test mutual exclusion of parameters" do
  it ":value and :initial_value" do
    params = {:value => "", :initial_value => ""}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  it ":length and :initial_length" do
    params = {:length => 5, :initial_length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  it ":initial_value and :initial_length" do
    params = {:initial_value => "", :initial_length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  it ":value and :length" do
    params = {:value => "", :length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

describe "A String with :initial_length" do
  before(:each) do
    @str = BinData::String.new(:initial_length => 5)
  end

  it "should set num_bytes" do
    @str.num_bytes.should eql(5)
  end

  it "should fill value with pad_char" do
    @str.value.should eql("\0\0\0\0\0")
  end

  it "should read :initial_length bytes" do
    io = StringIO.new("abcdefghij")
    @str.read(io)
    @str.value.should eql("abcde")
  end

  it "should forget :initial_length after value is set" do
    @str.value = "abc"
    @str.num_bytes.should eql(3)
  end

  it "should remember :initial_length after value is cleared" do
    @str.value = "abc"
    @str.num_bytes.should eql(3)
    @str.clear
    @str.num_bytes.should eql(5)
  end
end

describe "A String with :length" do
  before(:each) do
    @str = BinData::String.new(:length => 5)
  end

  it "should set num_bytes" do
    @str.num_bytes.should eql(5)
  end

  it "should fill value with pad_char" do
    @str.value.should eql("\0\0\0\0\0")
  end

  it "should retain :length after value is set" do
    @str.value = "abcdefghij"
    @str.num_bytes.should eql(5)
  end

  it "should read :length bytes" do
    io = StringIO.new("abcdefghij")
    @str.read(io)
    @str.value.should eql("abcde")
  end

  it "should pad values less than :length" do
    @str.value = "abc"
    @str.value.should eql("abc\0\0")
  end

  it "should accept values exactly :length" do
    @str.value = "abcde"
    @str.value.should eql("abcde")
  end

  it "should truncate values greater than :length" do
    @str.value = "abcdefg"
    @str.value.should eql("abcde")
  end
end

describe "A String with :initial_length and :value" do
  before(:each) do
    @str = BinData::String.new(:initial_length => 5, :value => "abcdefghij")
  end

  it "should use :initial_length before value is read" do
    @str.num_bytes.should eql(5)
    @str.value.should eql("abcde")
  end

  it "should use :initial_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should eql(5)
   end

  it "should forget :initial_length after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    @str.num_bytes.should eql(10)
    @str.value.should eql("abcdefghij")
  end

  it "should return read value before calling done_read" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")

    @str.do_read(io)
    @str.value.should eql("ABCDE")

    @str.done_read
    @str.value.should eql("abcdefghij")
  end
end

describe "A String with :length and :initial_value" do
  before(:each) do
    @str = BinData::String.new(:length => 5, :initial_value => "abcdefghij")
  end

  it "should apply :length to :initial_value" do
    @str.num_bytes.should eql(5)
    @str.value.should eql("abcde")
  end

  it "should forget :initial_value after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should eql(5)
    @str.num_bytes.should eql(5)
    @str.value.should eql("ABCDE")
  end
end

describe "A String with :pad_char" do
  it "should accept a numeric value for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => 6)
    @str.value = "abc"
    @str.value.should eql("abc\x06\x06")
  end

  it "should accept a character for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => "R")
    @str.value = "abc"
    @str.value.should eql("abcRR")
  end

  it "should not accept a string for :pad_char" do
    params = {:length => 5, :pad_char => "RR"}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

describe "A String with :trim_value" do
  it "set false is the default" do
    str1 = BinData::String.new(:length => 5)
    str2 = BinData::String.new(:length => 5, :trim_value => false)
    str1.value = "abc"
    str2.value = "abc"
    str1.value.should eql("abc\0\0")
    str2.value.should eql("abc\0\0")
  end

  it "should trim the value" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.value.should eql("abc")
  end

  it "should not affect num_bytes" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.num_bytes.should eql(5)
  end

  it "should trim if last char is :pad_char" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.value.should eql("abc")
  end

  it "should not trim if value contains :pad_char not at the end" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRRde"
    str.value.should eql("abcRRde")
  end
end
