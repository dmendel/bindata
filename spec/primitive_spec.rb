#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::Primitive, "when subclassing" do
  class SubClassOfPrimitive < BinData::Primitive
    expose_methods_for_testing
  end

  before(:each) do
    @obj = SubClassOfPrimitive.new
  end

  it "should raise errors on unimplemented methods" do
    lambda { @obj.set(nil) }.should raise_error(NotImplementedError)
    lambda { @obj.get }.should raise_error(NotImplementedError)
  end
end

describe BinData::Primitive, "when defining with errors" do
  it "should fail on non registered types" do
    lambda {
      class BadTypePrimitive < BinData::Primitive
        non_registered_type :a
      end
    }.should raise_error_on_line(TypeError, 2) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BadTypePrimitive}"
    }
  end

  it "should fail on duplicate names" do
    lambda {
      class DuplicateNamePrimitive < BinData::Primitive
        int8 :a
        int8 :b
        int8 :a
      end
    }.should raise_error_on_line(SyntaxError, 4) { |err|
      err.message.should == "duplicate field 'a' in #{DuplicateNamePrimitive}"
    }
  end

  it "should fail when field name shadows an existing method" do
    lambda {
      class ExistingNamePrimitive < BinData::Primitive
        int8 :object_id
      end
    }.should raise_error_on_line(NameError, 2) { |err|
      err.message.should == "field 'object_id' shadows an existing method in #{ExistingNamePrimitive}"
    }
  end

  it "should fail on unknown endian" do
    lambda {
      class BadEndianPrimitive < BinData::Primitive
        endian 'a bad value'
      end
    }.should raise_error_on_line(ArgumentError, 2) { |err|
      err.message.should == "unknown value for endian 'a bad value' in #{BadEndianPrimitive}"
    }
  end
end

describe BinData::Primitive do
  class PrimitiveWithEndian < BinData::Primitive
    endian :little
    int16 :a
    def get; self.a; end
    def set(v); self.a = v; end
  end

  before(:each) do
    @obj = PrimitiveWithEndian.new
  end

  it "should support endian" do
    @obj.value = 5
    @obj.to_binary_s.should == "\x05\x00"
  end

  it "should set value" do
    @obj.value = 5
    @obj.to_binary_s.should == "\x05\x00"
  end

  it "should read value" do
    @obj.read("\x00\x01")
    @obj.value.should == 0x100
  end

  it "should accept standard parameters" do
    obj = PrimitiveWithEndian.new(:initial_value => 2)
    obj.to_binary_s.should == "\x02\x00"
  end

  it "should return num_bytes" do
    @obj.num_bytes.should == 2
  end

  it "should raise error on missing methods" do
    lambda {
      @obj.does_not_exist
    }.should raise_error(NoMethodError)
  end

  it "should use read value whilst reading" do
    obj = PrimitiveWithEndian.new(:value => 2)
    obj.read "\x05\x00"
    obj.value.should == 2

    def obj.reading?; true; end
    obj.value.should == 5
  end
end

describe BinData::Primitive, "requiring custom parameters" do
  class PrimitiveWithCustom < BinData::Primitive
    int8 :a, :initial_value => :iv
    def get; self.a; end
    def set(v); self.a = v; end
  end

  it "should pass parameters correctly" do
    obj = PrimitiveWithCustom.new(:iv => 5)
    obj.value.should == 5
  end
end

describe BinData::Primitive, "with custom mandatory parameters" do
  class MandatoryPrimitive < BinData::Primitive
    mandatory_parameter :arg1

    uint8 :a, :value => :arg1
    def get; self.a; end
    def set(v); self.a = v; end
  end

  it "should raise error if mandatory parameter is not supplied" do
    lambda { MandatoryPrimitive.new }.should raise_error(ArgumentError)
  end

  it "should use mandatory parameter" do
    obj = MandatoryPrimitive.new(:arg1 => 5)
    obj.value.should == 5
  end
end

describe BinData::Primitive, "with custom default parameters" do
  class DefaultPrimitive < BinData::Primitive
    default_parameter :arg1 => 5

    uint8 :a, :value => :arg1
    def get; self.a; end
    def set(v); self.a = v; end
  end

  it "should not raise error if default parameter is not supplied" do
    lambda { DefaultPrimitive.new }.should_not raise_error(ArgumentError)
  end

  it "should use default parameter" do
    obj = DefaultPrimitive.new
    obj.value.should == 5
  end

  it "should be able to override default parameter" do
    obj = DefaultPrimitive.new(:arg1 => 7)
    obj.value.should == 7
  end
end

describe BinData::Primitive, "derived classes" do
  class ParentDerivedPrimitive < BinData::Primitive
    uint16be :a
    def get; self.a; end
    def set(v); self.a = v; end
  end

  class ChildDerivedPrimitive < ParentDerivedPrimitive
  end

  it "should derive" do
    a = ChildDerivedPrimitive.new
    a.value = 7
    a.to_binary_s.should == "\000\007"
  end
end
