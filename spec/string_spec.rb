#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/io'
require 'bindata/string'

describe BinData::String, "with mutually exclusive parameters" do
  it ":value and :initial_value" do
    params = {:value => "", :initial_value => ""}
    expect { BinData::String.new(params) }.to raise_error(ArgumentError)
  end

  it ":length and :read_length" do
    params = {:length => 5, :read_length => 5}
    expect { BinData::String.new(params) }.to raise_error(ArgumentError)
  end

  it ":value and :length" do
    params = {:value => "", :length => 5}
    expect { BinData::String.new(params) }.to raise_error(ArgumentError)
  end
end

describe BinData::String, "when assigning" do
  let(:small) { BinData::String.new(:length => 3, :pad_byte => "A") }
  let(:large) { BinData::String.new(:length => 5, :pad_byte => "B") }

  it "copies data from small to large" do
    large.assign(small)
    large.should == "AAABB"
  end

  it "copies data from large to small" do
    small.assign(large)
    small.should == "BBB"
  end
end

describe BinData::String do
  subject { BinData::String.new("testing") }

  it "compares with regexp" do
    (/es/ =~ subject).should == 1
  end

  it "compares with regexp" do
    (subject =~ /es/).should == 1
  end
end

describe BinData::String, "with :read_length" do
  subject { BinData::String.new(:read_length => 5) }

  its(:num_bytes) { should == 0 }
  its(:value) { should == "" }

  it "reads :read_length bytes" do
    subject.read("abcdefghij")
    subject.should == "abcde"
  end

  it "remembers :read_length after value is cleared" do
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

  it "retains :length after value is set" do
    subject.assign("abcdefghij")
    subject.num_bytes.should == 5
  end

  it "reads :length bytes" do
    subject.read("abcdefghij")
    subject.should == "abcde"
  end

  it "pads values less than :length" do
    subject.assign("abc")
    subject.should == "abc\0\0"
  end

  it "accepts values exactly :length" do
    subject.assign("abcde")
    subject.should == "abcde"
  end

  it "truncates values greater than :length" do
    subject.assign("abcdefghij")
    subject.should == "abcde"
  end
end

describe BinData::String, "with :read_length and :initial_value" do
  subject { BinData::String.new(:read_length => 5, :initial_value => "abcdefghij") }

  its(:num_bytes) { should == 10 }
  its(:value) { should == "abcdefghij" }

  it "uses :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
   end

  it "forgets :initial_value after reading" do
    subject.read("ABCDEFGHIJKLMNOPQRST")
    subject.num_bytes.should == 5
    subject.should == "ABCDE"
  end
end

describe BinData::String, "with :read_length and :value" do
  subject { BinData::String.new(:read_length => 5, :value => "abcdefghij") }

  its(:num_bytes) { should == 10 }
  its(:value) { should == "abcdefghij" }

  it "uses :read_length for reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
  end

  context "after reading" do
    before(:each) do
      subject.read("ABCDEFGHIJKLMNOPQRST")
    end

    it "is not affected by :read_length after reading" do
      subject.num_bytes.should == 10
      subject.should == "abcdefghij"
    end

    it "returns read value while reading" do
      subject.stub(:reading?).and_return(true)
      subject.should == "ABCDE"
    end
  end
end

describe BinData::String, "with :length and :initial_value" do
  subject { BinData::String.new(:length => 5, :initial_value => "abcdefghij") }

  its(:num_bytes) { should == 5 }
  its(:value) { should == "abcde" }

  it "forgets :initial_value after reading" do
    io = StringIO.new("ABCDEFGHIJKLMNOPQRST")
    subject.read(io)
    io.pos.should == 5
    subject.num_bytes.should == 5
    subject.should == "ABCDE"
  end
end

describe BinData::String, "with :pad_byte" do
  it "accepts a numeric value for :pad_byte" do
    str = BinData::String.new(:length => 5, :pad_byte => 6)
    str.assign("abc")
    str.should == "abc\x06\x06"
  end

  it "accepts a character for :pad_byte" do
    str = BinData::String.new(:length => 5, :pad_byte => "R")
    str.assign("abc")
    str.should == "abcRR"
  end

  it "does not accept a string for :pad_byte" do
    params = {:length => 5, :pad_byte => "RR"}
    lambda { BinData::String.new(params) }.should raise_error(ArgumentError)
  end
end

describe BinData::String, "with :trim_padding" do
  it "set false is the default" do
    str1 = BinData::String.new(:length => 5)
    str2 = BinData::String.new(:length => 5, :trim_padding => false)
    str1.assign("abc")
    str2.assign("abc")
    str1.should == "abc\0\0"
    str2.should == "abc\0\0"
  end

  context "trim padding set" do
    subject { BinData::String.new(:pad_byte => 'R', :trim_padding => true) }

    it "trims the value" do
      subject.assign("abcRR")
      subject.should == "abc"
    end

    it "does not affect num_bytes" do
      subject.assign("abcRR")
      subject.num_bytes.should == 5
    end

    it "trims if last char is :pad_byte" do
      subject.assign("abcRR")
      subject.should == "abc"
    end

    it "does not trim if value contains :pad_byte not at the end" do
      subject.assign("abcRRde")
      subject.should == "abcRRde"
    end
  end
end

describe BinData::String, "with :pad_front" do
  it "set false is the default" do
    str1 = BinData::String.new(:length => 5)
    str2 = BinData::String.new(:length => 5, :pad_front => false)
    str1.assign("abc")
    str2.assign("abc")
    str1.should == "abc\0\0"
    str2.should == "abc\0\0"
  end

  it "pads to the front" do
    str = BinData::String.new(:length => 5, :pad_byte => 'R', :pad_front => true)
    str.assign("abc")
    str.should == "RRabc"
  end

  it "can alternatively be accesses by :pad_left" do
    str = BinData::String.new(:length => 5, :pad_byte => 'R', :pad_left => true)
    str.assign("abc")
    str.should == "RRabc"
  end

  context "and :trim_padding" do
    subject { BinData::String.new(:length => 5, :pad_byte => 'R', :pad_front => true, :trim_padding => true) }

    it "assigns" do
      subject.assign("abc")
      subject.should == "abc"
    end

    it "has to_binary_s" do
      subject.assign("abc")
      subject.to_binary_s.should == "RRabc"
    end

    it "reads" do
      subject.read "RRabc"
      subject.should == "abc"
    end
  end
end

describe BinData::String, "with Ruby 1.9 encodings" do
  if RUBY_VERSION >= "1.9"
    class UTF8String < BinData::String
      def snapshot
        super.force_encoding('UTF-8')
      end
    end

    subject { UTF8String.new }
    let(:binary_str) { "\xC3\x85\xC3\x84\xC3\x96" }
    let(:utf8_str) { binary_str.dup.force_encoding('UTF-8') }

    it "stores assigned values as binary" do
      subject.assign(utf8_str)
      subject.to_binary_s.should == binary_str
    end

    it "stores read values as binary" do
      subject = UTF8String.new(:read_length => binary_str.length)
      subject.read(binary_str)

      subject.to_binary_s.should == binary_str
    end

    it "returns values in correct encoding" do
      subject.assign(utf8_str)

      subject.snapshot.should == utf8_str
    end

    it "has correct num_bytes" do
      subject.assign(utf8_str)

      subject.num_bytes.should == binary_str.length
    end
  end
end

