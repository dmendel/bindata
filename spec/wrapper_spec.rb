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
    }.should raise_error_on_line(SyntaxError, 3) { |err|
      err.message.should == "attempting to wrap more than one type in #{WrappedMultipleTypes}"
    }
  end

  it "should fail if wrapped type has a name" do
    lambda {
      class WrappedWithName < BinData::Wrapper
        uint8 :a
      end
    }.should raise_error_on_line(SyntaxError, 2) { |err|
      err.message.should == "field must not have a name in #{WrappedWithName}"
    }
  end

  it "should fail if no types to wrap" do
    class WrappedNoTypes < BinData::Wrapper
    end

    lambda {
      WrappedNoTypes.new
    }.should raise_error(RuntimeError) { |err|
      err.message.should == "no wrapped type was specified in #{WrappedNoTypes}"
    }
  end
end

describe BinData::Wrapper, "around a Primitive" do
  class WrappedPrimitive < BinData::Wrapper
    default_parameter :a => 3

    uint8 :initial_value => :a
  end

  it "should access custom parameter" do
    subject = WrappedPrimitive.new
    subject.assign(3)
    subject.should == 3
  end

  it "should be able to override custom default parameter" do
    subject = WrappedPrimitive.new(:a => 5)
    subject.should == 5
  end

  it "should be able to override parameter" do
    subject = WrappedPrimitive.new(:initial_value => 7)
    subject.should == 7
  end

  it "should clear" do
    subject = WrappedPrimitive.new
    subject.assign(3)
    subject.should_not be_clear

    subject.clear
    subject.should be_clear
  end

  it "should read" do
    subject = WrappedPrimitive.new
    subject.assign(3)
    str = subject.to_binary_s

    WrappedPrimitive.read(str).should == 3
  end

  it "should respond_to and forward messages to the wrapped object" do
    subject = WrappedPrimitive.new
    subject.assign(5)

    subject.should respond_to(:to_int)
    subject.to_int.should == 5
  end
end

describe BinData::Wrapper, "around an Array" do
  class WrappedIntArray < BinData::Wrapper
    endian :big
    default_parameter :initial_element_value => 0
    array do
      uint16 :initial_value => :initial_element_value
    end
  end

  it "should forward parameters" do
    subject = WrappedIntArray.new(:initial_length => 7)
    subject.length.should == 7
  end

  it "should be able to override default parameters" do
    subject = WrappedIntArray.new(:initial_length => 3, :initial_element_value => 5)
    subject.to_binary_s.should == "\x00\x05\x00\x05\x00\x05"
  end
end

describe BinData::Wrapper, "around a Choice" do
  class WrappedChoice < BinData::Wrapper
    endian :big
    choice :choices => { 'a' => :uint8, 'b' => :uint16 }
  end

  it "should forward parameters" do
    subject = WrappedChoice.new(:selection => 'b')
    subject.num_bytes.should == 2
  end
end

describe BinData::Wrapper, "inside a Record" do
  class WrappedUint32le < BinData::Wrapper
    uint32le
  end

  class RecordWithWrapped < BinData::Record
    wrapped_uint32le :a, :onlyif => false, :value => 1
    wrapped_uint32le :b, :onlyif => true,  :value => 2
  end

  it "should handle onlyif" do
    subject = RecordWithWrapped.new
    subject.should == {'b' => 2}
  end
end

describe BinData::Wrapper, "around a Record" do
  class RecordToBeWrapped < BinData::Record
    default_parameter :arg => 3
    uint8 :a, :initial_value => :arg
    uint8 :b
  end

  class WrappedRecord < BinData::Wrapper
    record_to_be_wrapped
  end

  it "should forward parameters" do
    subject = WrappedRecord.new(:arg => 5)
    subject.a.should == 5
  end

  it "should assign value" do
    subject = WrappedRecord.new(:b => 5)
    subject.b.should == 5
  end

  it "should assign value and forward parameters" do
    subject = WrappedRecord.new({:b => 5}, :arg => 7)
    subject.a.should == 7
    subject.b.should == 5
  end
end

describe BinData::Wrapper, "derived classes" do
  class ParentDerivedWrapper < BinData::Wrapper
    uint32le
  end

  class ChildDerivedWrapper < ParentDerivedWrapper
  end

  it "should wrap" do
    a = ChildDerivedWrapper.new
    a.num_bytes.should == 4
  end
end
