#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/stringz'

describe BinData::Stringz, "when empty" do
  its(:value) { should == "" }
  its(:num_bytes) { should == 1 }
  its(:to_binary_s) { should == "\0" }
end

describe BinData::Stringz, "with value set" do
  subject { BinData::Stringz.new("abcd") }

  its(:value) { should == "abcd" }
  its(:num_bytes) { should == 5 }
  its(:to_binary_s) { should == "abcd\0" }
end

describe BinData::Stringz, "when reading" do
  it "should stop at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    subject.read(io)
    io.pos.should == 5
    subject.should == "abcd"
  end

  it "should handle a zero length string" do
    io = StringIO.new("\0abcd")
    subject.read(io)
    io.pos.should == 1
    subject.should == ""
  end

  it "should fail if no zero byte is found" do
    lambda {subject.read("abcd") }.should raise_error(EOFError)
  end
end

describe BinData::Stringz, "when setting the value" do
  it "should include the zero byte in num_bytes total" do
    subject.value = "abcd"
    subject.num_bytes.should == 5
  end

  it "should accept empty strings" do
    subject.value = ""
    subject.should == ""
  end

  it "should accept strings that aren't zero terminated" do
    subject.value = "abcd"
    subject.should == "abcd"
  end

  it "should accept strings that are zero terminated" do
    subject.value = "abcd\0"
    subject.should == "abcd"
  end

  it "should accept up to the first zero byte" do
    subject.value = "abcd\0xyz\0"
    subject.should == "abcd"
  end
end

describe BinData::Stringz, "with max_length" do
  subject { BinData::Stringz.new(:max_length => 5) }

  it "should read less than max_length" do
    io = StringIO.new("abc\0xyz")
    subject.read(io)
    subject.should == "abc"
  end

  it "should read exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    subject.read(io)
    subject.should == "abcd"
  end

  it "should read no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    subject.read(io)
    io.pos.should == 5
    subject.should == "abcd"
  end

  it "should accept values less than max_length" do
    subject.value = "abc"
    subject.should == "abc"
  end

  it "should accept values exactly max_length" do
    subject.value = "abcd"
    subject.should == "abcd"
  end

  it "should trim values greater than max_length" do
    subject.value = "abcde"
    subject.should == "abcd"
  end

  it "should write values greater than max_length" do
    subject.value = "abcde"
    subject.to_binary_s.should == "abcd\0"
  end

  it "should write values less than max_length" do
    subject.value = "abc"
    subject.to_binary_s.should == "abc\0"
  end

  it "should write values exactly max_length" do
    subject.value = "abcd"
    subject.to_binary_s.should == "abcd\0"
  end
end
