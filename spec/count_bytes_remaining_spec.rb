#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/count_bytes_remaining'

describe BinData::CountBytesRemaining do
  it { should == 0 }
  its(:num_bytes) { should be_zero }

  it "counts till end of stream" do
    data = "abcdefghij"
    subject.read(data).should == 10
  end

  it "does not read any data" do
    io = StringIO.new "abcdefghij"
    subject.read(io)

    io.pos.should == 0
  end

  it "does not write any data" do
    subject.to_binary_s.should == ""
  end

  it "allows setting value for completeness" do
    subject.assign("123")
    subject.should == "123"
    subject.to_binary_s.should == ""
  end

  it "accepts BinData::BasePrimitive parameters" do
    count = BinData::CountBytesRemaining.new(:check_value => 2)
    expect {
      count.read("xyz")
    }.to raise_error(BinData::ValidityError)
  end
end
