#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require File.expand_path(File.dirname(__FILE__)) + '/example'
require 'bindata'

describe BinData::SingleValue, "when defining" do
  it "should allow inheriting from deprecated SingleValue" do
    lambda {
      eval <<-END
        class SubclassSingleValue < BinData::SingleValue
        end
      END
    }.should_not raise_error
  end
end

describe BinData::MultiValue, "when defining" do
  it "should allow inheriting from deprecated MultiValue" do
    lambda {
      eval <<-END
        class SubclassMultiValue < BinData::MultiValue
        end
      END
    }.should_not raise_error
  end
end

describe BinData::Array, "with several elements" do
  before(:each) do
    type = [:example_single, {:initial_value => lambda { index + 1 }}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  it "should clear a single element" do
    @data[1] = 8
    @data.clear(1)
    @data[1].should == 2
  end

  it "should test clear status of individual elements" do
    @data[1] = 8
    @data.clear?(0).should be_true
    @data.clear?(1).should be_false
  end

  it "should have correct num_bytes for individual elements" do
    @data.num_bytes(0).should == ExampleSingle.new.num_bytes
  end

  it "should not extend on clear" do
    @data.clear(9)
    @data.length.should == 5
  end

  it "should not extend on clear?" do
    @data.clear?(9).should be_true
    @data.length.should == 5
  end

  it "should not extend on num_bytes" do
    @data.num_bytes(9).should == 0
    @data.length.should == 5
  end
end

describe BinData::String, "with deprecated parameters" do
  it "should substitude :trim_padding for :trim_value" do
    obj = BinData::String.new(:trim_value => true)
    obj.value = "abc\0"
    obj.value.should == "abc"
  end
end

describe BinData::Struct, "with multiple fields" do
  before(:each) do
    @params = { :fields => [ [:int8, :a], [:int8, :b] ] }
    @obj = BinData::Struct.new(@params)
    @obj.a = 1
    @obj.b = 2
  end

  it "should return num_bytes" do
    @obj.num_bytes(:a).should == 1
    @obj.num_bytes(:b).should == 1
    @obj.num_bytes.should     == 2
  end

  it "should clear individual elements" do
    @obj.a = 6
    @obj.b = 7
    @obj.clear(:a)
    @obj.should be_clear(:a)
    @obj.should_not be_clear(:b)
  end
end
