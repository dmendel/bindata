#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/skip'

describe BinData::Skip do
  before(:each) do
    @skip = BinData::Skip.new(:length => 5)
  end

  it "should default to the empty string" do
    @skip.should == ""
  end

  it "should skip bytes" do
    io = StringIO.new("abcdefghij")
    @skip.read(io)
    io.pos.should == 5
  end

  it "should have expected binary representation" do
    @skip.to_binary_s.should == "\000" * 5
  end

  it "should have expected binary representation after setting value" do
    @skip.value = "123"
    @skip.to_binary_s.should == "\000" * 5
  end

  it "should have expected binary representation after reading" do
    io = StringIO.new("abcdefghij")
    @skip.read(io)
    @skip.to_binary_s.should == "\000" * 5
  end
end
