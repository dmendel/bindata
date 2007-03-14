#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/string'

context "Test mutual exclusion of parameters" do
  specify ":value and :initial_value" do
    params = {:value => "", :initial_value => ""}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  specify ":length and :initial_length" do
    params = {:length => 5, :initial_length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  specify ":initial_value and :initial_length" do
    params = {:initial_value => "", :initial_length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end

  specify ":value and :length" do
    params = {:value => "", :length => 5}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

context "A String with :initial_length" do
  setup do
    @str = BinData::String.new(:initial_length => 5)
  end

  specify "should set num_bytes" do
    @str.num_bytes.should == 5
  end

  specify "should fill value with pad_char" do
    @str.value.should == "\0\0\0\0\0"
  end

  specify "should read :initial_length bytes" do
    io = StringIO.new("abcdefghij")
    @str.read(io)
    @str.value.should == "abcde"
  end

  specify "should forget :initial_length after value is set" do
    @str.value = "abc"
    @str.num_bytes.should == 3
  end

  specify "should remember :initial_length after value is cleared" do
    @str.value = "abc"
    @str.num_bytes.should == 3
    @str.clear
    @str.num_bytes.should == 5
  end
end

context "A String with :length" do
  setup do
    @str = BinData::String.new(:length => 5)
  end

  specify "should set num_bytes" do
    @str.num_bytes.should == 5
  end

  specify "should fill value with pad_char" do
    @str.value.should == "\0\0\0\0\0"
  end

  specify "should retain :length after value is set" do
    @str.value = "abcdefghij"
    @str.num_bytes.should == 5
  end

  specify "should read :length bytes" do
    io = StringIO.new("abcdefghij")
    @str.read(io)
    @str.value.should == "abcde"
  end

  specify "should pad values less than :length" do
    @str.value = "abc"
    @str.value.should == "abc\0\0"
  end

  specify "should accept values exactly :length" do
    @str.value = "abcde"
    @str.value.should == "abcde"
  end

  specify "should truncate values greater than :length" do
    @str.value = "abcdefg"
    @str.value.should == "abcde"
  end
end

context "A String with :initial_length and :value" do
  setup do
    @str = BinData::String.new(:initial_length => 5, :value => "abcdefghij")
  end

  specify "should use :initial_length before value is read" do
    @str.num_bytes.should == 5
    @str.value.should == "abcde"
  end

  specify "should use :initial_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should == 5
   end

  specify "should forget :initial_length after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    @str.num_bytes.should == 10
    @str.value.should == "abcdefghij"
  end

  specify "should return read value before calling done_read" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")

    @str.do_read(io)
    @str.value.should == "ABCDE"

    @str.done_read
    @str.value.should == "abcdefghij"
  end
end

context "A String with :length and :initial_value" do
  setup do
    @str = BinData::String.new(:length => 5, :initial_value => "abcdefghij")
  end

  specify "should apply :length to :initial_value" do
    @str.num_bytes.should == 5
    @str.value.should == "abcde"
  end

  specify "should forget :initial_value after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    @str.read(io)
    io.pos.should == 5
    @str.num_bytes.should == 5
    @str.value.should == "ABCDE"
  end
end

context "A String with :pad_char" do
  specify "should accept a numeric value for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => 6)
    @str.value = "abc"
    @str.value.should == "abc\x06\x06"
  end

  specify "should accept a character for :pad_char" do
    @str = BinData::String.new(:length => 5, :pad_char => "R")
    @str.value = "abc"
    @str.value.should == "abcRR"
  end

  specify "should not accept a string for :pad_char" do
    params = {:length => 5, :pad_char => "RR"}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

context "A String with :trim_value" do
  specify "set false is the default" do
    str1 = BinData::String.new(:length => 5)
    str2 = BinData::String.new(:length => 5, :trim_value => false)
    str1.value = "abc"
    str2.value = "abc"
    str1.value.should == "abc\0\0"
    str2.value.should == "abc\0\0"
  end

  specify "should trim the value" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.value.should == "abc"
  end

  specify "should not affect num_bytes" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.num_bytes.should == 5
  end

  specify "should trim if last char is :pad_char" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRR"
    str.value.should == "abc"
  end

  specify "should not trim if value contains :pad_char not at the end" do
    str = BinData::String.new(:pad_char => 'R', :trim_value => true)
    str.value = "abcRRde"
    str.value.should == "abcRRde"
  end
end
