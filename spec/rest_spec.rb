#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/rest'

describe BinData::Rest do
  it "should read till end of stream" do
    data = "abcdefghij"
    BinData::Rest.read(data).should == data
  end
end

