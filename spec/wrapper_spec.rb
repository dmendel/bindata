#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::Wrapper, "with errors" do
  it "should not wrap more than one type" do
    lambda {
      class WrappedMultipleTypes < BinData::Wrapper
        uint8
        uint8
      end
    }.should raise_error(SyntaxError)
  end
end

describe BinData::Wrapper, "around a Primitive" do
  class WrappedPrimitive < BinData::Wrapper
    default_parameter :a => 3

    uint8 :initial_value => :a
  end

  it "should access custom parameter" do
    obj = WrappedPrimitive.new
    obj.value.should == 3
    obj.should == 3
  end

  it "should be able to override custom default parameter" do
    obj = WrappedPrimitive.new(:a => 5)
    obj.value.should == 5
  end

  it "should be able to override parameter" do
    obj = WrappedPrimitive.new(:initial_value => 7)
    obj.value.should == 7
  end
end

describe BinData::Wrapper, "around an Array" do
  class WrappedIntArray < BinData::Wrapper
    endian :big
    default_parameter :initial_element_value => 0
    array :type => [:uint16, {:initial_value => :initial_element_value}]
  end

  it "should forward parameters" do
    obj = WrappedIntArray.new(:initial_length => 7)
    obj.length.should == 7
  end

  it "should be able to override default parameters" do
    obj = WrappedIntArray.new(:initial_length => 3, :initial_element_value => 5)
    obj.to_binary_s.should == "\x00\x05\x00\x05\x00\x05"
  end
end

describe BinData::Wrapper, "around a Choice" do
  class WrappedChoice < BinData::Wrapper
    endian :big
    choice :choices => { 'a' => :uint8, 'b' => :uint16 }
  end

  it "should forward parameters" do
    obj = WrappedChoice.new(:selection => 'b')
    obj.num_bytes.should == 2
  end
end

describe BinData::Wrapper, "inside a struct" do
  class WrappedUint32le < BinData::Wrapper
    uint32le
  end

  it "should handle onlyif" do
    field1 = [:wrapped_uint32le, :a, {:onlyif => false, :value => 1 }]
    field2 = [:wrapped_uint32le, :b, {:onlyif => true, :value => 2 }]

    obj = BinData::Struct.new(:fields => [field1, field2])
    obj.should == {'b' => 2}
  end
end
