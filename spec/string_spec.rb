#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
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

describe BinData::String, "when assigning" do
  let(:small) { BinData::String.new(:length => 3, :pad_char => "A") }
  let(:large) { BinData::String.new(:length => 5, :pad_char => "B") }

  it "should copy data from small to large" do
    large.assign(small)
    large.should == "AAABB"
  end

  it "should copy data from large to small" do
    small.assign(large)
    small.should == "BBB"
  end
end

describe BinData::String, "with :read_length" do
  subject { BinData::String.new(:read_length => 5) }

  its(:num_bytes) { should == 0 }
  its(:value) { should == "" }

  it "should read :read_length bytes" do
    subject.read("abcdefghij")
    subject.should == "abcde"
  end

  it "should remember :read_length after value is cleared" do
    subject.assign("abc")
    subject.num_bytes.should == 3
    subject.clear

    subject.read("abcdefghij")
    subject.should == "abcde"
  end
end

describe BinData::String, "with :length" do
  subject { BinData::String.new(:length => 5) }

  its(:num_bytes) { should == 5 }
  its(:value) { should == "\0\0\0\0\0" }

  it "should retain :length after value is set" do
    subject.assign("abcdefghij")
    subject.num_bytes.should == 5
  end

  it "should read :length bytes" do
    subject.read("abcdefghij")
    subject.should == "abcde"
  end

  it "should pad values less than :length" do
    subject.assign("abc")
    subject.should == "abc\0\0"
  end

  it "should accept values exactly :length" do
    subject.assign("abcde")
    subject.should == "abcde"
  end

  it "should truncate values greater than :length" do
    subject.assign("abcdefghij")
    subject.should == "abcde"
  end
end

describe BinData::String, "with :read_length and :initial_value" do
  subject { BinData::String.new(:read_length => 5, :initial_value => "abcdefghij") }

  its(:num_bytes) { should == 10 }
  its(:value) { should == "abcdefghij" }

  it "should use :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
   end

  it "should forget :initial_value after reading" do
    subject.read("ABCDEFGHIJKLMNOPQRST")
    subject.num_bytes.should == 5
    subject.should == "ABCDE"
  end
end

describe BinData::String, "with :read_length and :value" do
  subject { BinData::String.new(:read_length => 5, :value => "abcdefghij") }

  its(:num_bytes) { should == 10 }
  its(:value) { should == "abcdefghij" }

  it "should use :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
  end

  context "after reading" do
    before(:each) do
      subject.read("ABCDEFGHIJKLMNOPQRST")
    end

    it "should not be affected by :read_length after reading" do
      subject.num_bytes.should == 10
      subject.should == "abcdefghij"
    end

    it "should return read value while reading" do
      subject.stub(:reading?).and_return(true)
      subject.should == "ABCDE"
    end
  end
end

describe BinData::String, "with :length and :initial_value" do
  subject { BinData::String.new(:length => 5, :initial_value => "abcdefghij") }

  its(:num_bytes) { should == 5 }
  its(:value) { should == "abcde" }

  it "should forget :initial_value after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
    subject.num_bytes.should == 5
    subject.should == "ABCDE"
  end
end

describe BinData::String, "with :pad_char" do
  it "should accept a numeric value for :pad_char" do
    str = BinData::String.new(:length => 5, :pad_char => 6)
    str.assign("abc")
    str.should == "abc\x06\x06"
  end

  it "should accept a character for :pad_char" do
    str = BinData::String.new(:length => 5, :pad_char => "R")
    str.assign("abc")
    str.should == "abcRR"
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
    str1.should == "abc\0\0"
    str2.should == "abc\0\0"
  end

  context "trim padding set" do
    subject { BinData::String.new(:pad_char => 'R', :trim_padding => true) }

    it "should trim the value" do
      subject.value = "abcRR"
      subject.should == "abc"
    end

    it "should not affect num_bytes" do
      subject.value = "abcRR"
      subject.num_bytes.should == 5
    end

    it "should trim if last char is :pad_char" do
      subject.value = "abcRR"
      subject.should == "abc"
    end

    it "should not trim if value contains :pad_char not at the end" do
      subject.value = "abcRRde"
      subject.should == "abcRRde"
    end
  end
end
