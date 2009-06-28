#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'
require 'bindata/wrapper'

describe BinData::Wrapper, "with errors" do
  it "should not wrap more than one type" do
    lambda {
      eval <<-END
        class WrappedMultipleTypes < BinData::Wrapper
          uint8
          uint8
        end
      END
    }.should raise_error(SyntaxError)
  end
end

describe BinData::Wrapper, "around a Primitive" do
  before(:all) do
    eval <<-END
      class WrappedPrimitive < BinData::Wrapper
        default_parameter :a => 3

        uint8 :initial_value => :a
      end
    END
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
  before(:all) do
    eval <<-END
      class WrappedIntArray < BinData::Wrapper
        endian :big
        default_parameter :initial_element_value => 0
        array :type => [:uint16, {:initial_value => :initial_element_value}]
      end
    END
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
  before(:all) do
    eval <<-END
      class WrappedChoice < BinData::Wrapper
        endian :big
        choice :choices => { 'a' => :uint8, 'b' => :uint16 }
      end
    END
  end

  it "should forward parameters" do
    obj = WrappedChoice.new(:selection => 'b')
    obj.num_bytes.should == 2
  end
end
