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
  it "stops at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    subject.read(io)
    io.pos.should == 5
    subject.should == "abcd"
  end

  it "handles a zero length string" do
    io = StringIO.new("\0abcd")
    subject.read(io)
    io.pos.should == 1
    subject.should == ""
  end

  it "fails if no zero byte is found" do
    expect {subject.read("abcd") }.to raise_error(EOFError)
  end
end

describe BinData::Stringz, "when setting the value" do
  it "includes the zero byte in num_bytes total" do
    subject.assign("abcd")
    subject.num_bytes.should == 5
  end

  it "accepts empty strings" do
    subject.assign("")
    subject.should == ""
  end

  it "accepts strings that aren't zero terminated" do
    subject.assign("abcd")
    subject.should == "abcd"
  end

  it "accepts strings that are zero terminated" do
    subject.assign("abcd\0")
    subject.should == "abcd"
  end

  it "accepts up to the first zero byte" do
    subject.assign("abcd\0xyz\0")
    subject.should == "abcd"
  end
end

describe BinData::Stringz, "with max_length" do
  subject { BinData::Stringz.new(:max_length => 5) }

  it "reads less than max_length" do
    io = StringIO.new("abc\0xyz")
    subject.read(io)
    subject.should == "abc"
  end

  it "reads exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    subject.read(io)
    subject.should == "abcd"
  end

  it "reads no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    subject.read(io)
    io.pos.should == 5
    subject.should == "abcd"
  end

  it "accepts values less than max_length" do
    subject.assign("abc")
    subject.should == "abc"
  end

  it "accepts values exactly max_length" do
    subject.assign("abcd")
    subject.should == "abcd"
  end

  it "trims values greater than max_length" do
    subject.assign("abcde")
    subject.should == "abcd"
  end

  it "writes values greater than max_length" do
    subject.assign("abcde")
    subject.to_binary_s.should == "abcd\0"
  end

  it "writes values less than max_length" do
    subject.assign("abc")
    subject.to_binary_s.should == "abc\0"
  end

  it "writes values exactly max_length" do
    subject.assign("abcd")
    subject.to_binary_s.should == "abcd\0"
  end
end
