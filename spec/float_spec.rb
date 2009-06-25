#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/float'

describe "A FloatLe" do
  before(:each) do
    @obj = BinData::FloatLe.new
    @obj.value = Math::PI
  end

  it "should be 4 bytes in size" do
    @obj.num_bytes.should == 4
  end

  it "should write the expected value" do
    written_value(@obj).should == [Math::PI].pack('e')
  end

  it "should read the same value as written" do
    value_read_from_written(@obj).should be_close(Math::PI, 0.000001)
  end
end

describe "A FloatBe" do
  before(:each) do
    @obj = BinData::FloatBe.new
    @obj.value = Math::PI
  end

  it "should be 4 bytes in size" do
    @obj.num_bytes.should == 4
  end

  it "should write the expected value" do
    written_value(@obj).should == [Math::PI].pack('g')
  end

  it "should read the same value as written" do
    value_read_from_written(@obj).should be_close(Math::PI, 0.000001)
  end
end

describe "A DoubleLe" do
  before(:each) do
    @obj = BinData::DoubleLe.new
    @obj.value = Math::PI
  end

  it "should be 8 bytes in size" do
    @obj.num_bytes.should == 8
  end

  it "should write the expected value" do
    written_value(@obj).should == [Math::PI].pack('E')
  end

  it "should read the same value as written" do
    value_read_from_written(@obj).should be_close(Math::PI, 0.0000000000000001)
  end
end


describe "A DoubleBe" do
  before(:each) do
    @obj = BinData::DoubleBe.new
    @obj.value = Math::PI
  end

  it "should be 8 bytes in size" do
    @obj.num_bytes.should == 8
  end

  it "should write the expected value" do
    written_value(@obj).should == [Math::PI].pack('G')
  end

  it "should read the same value as written" do
    value_read_from_written(@obj).should be_close(Math::PI, 0.0000000000000001)
  end
end

def written_value(obj)
  obj.to_binary_s
end

def value_read_from_written(obj)
  obj.class.read(obj.to_binary_s)
end
