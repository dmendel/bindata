#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/rest'

describe BinData::Rest do
  it "should read till end of stream" do
    data = "abcdefghij"
    BinData::Rest.read(data).should == data
  end

  it "should default to the empty string" do
    BinData::Rest.new.value.should == ""
  end

  it "should allow setting value for completeness" do
    rest = BinData::Rest.new
    rest.value = "123"
    rest.value.should == "123"
    rest.to_binary_s.should == "123"
  end

  it "should accept BinData::Single parameters" do
    rest = BinData::Rest.new(:check_value => "abc")
    lambda {
      rest.read("abc")
    }.should_not raise_error(BinData::ValidityError)
  end
end
