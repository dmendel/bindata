#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

describe BinData::SingleValue do
  before(:all) do
    eval <<-END
      class SingleValueWithEndian < BinData::SingleValue
        endian :little
        int16 :a
        def get; self.a; end
        def set(v); self.a = v; end
      end
    END
  end

  before(:each) do
    @obj = SingleValueWithEndian.new
  end

  it "should support endian" do
    @obj.value = 5
    @obj.to_s.should == "\x05\x00"
  end

  it "should set value" do
    @obj.value = 5
    @obj.to_s.should == "\x05\x00"
  end

  it "should read value" do
    @obj.read("\x00\x01")
    @obj.value.should == 0x100
  end

  it "should accept standard parameters" do
    obj = SingleValueWithEndian.new(:initial_value => 2)
    obj.to_s.should == "\x02\x00"
  end

  it "should return num_bytes" do
    @obj.num_bytes.should == 2
  end

  it "should raise error on missing methods" do
    lambda {
      @obj.does_not_exist
    }.should raise_error(NoMethodError)
  end
end

describe BinData::SingleValue, "requiring extra parameters" do
  before(:all) do
    eval <<-END
      class SingleValueWithExtra < BinData::SingleValue
        int8 :a, :initial_value => :iv
        def get; self.a; end
        def set(v); self.a = v; end
      end
    END
  end

  it "should pass parameters correctly" do
    obj = SingleValueWithExtra.new(:iv => 5)
    obj.value.should == 5
  end
end

describe BinData::SingleValue, "when subclassing" do
  before(:all) do
    eval <<-END
      class SubClassOfSingleValue < BinData::SingleValue
        public :get, :set
      end
    END
  end

  before(:each) do
    @obj = SubClassOfSingleValue.new
  end

  it "should raise errors on unimplemented methods" do
    lambda { @obj.set(nil) }.should raise_error(NotImplementedError)
    lambda { @obj.get }.should raise_error(NotImplementedError)
  end
end

describe BinData::SingleValue, "when defining" do
  it "should fail on non registered types" do
    lambda {
      eval <<-END
        class BadTypeSingleValue < BinData::SingleValue
          non_registerd_type :a
        end
      END
    }.should raise_error(TypeError)
  end

  it "should fail on duplicate names" do
    lambda {
      eval <<-END
        class DuplicateNameSingleValue < BinData::SingleValue
          int8 :a
          int8 :b
          int8 :a
        end
      END
    }.should raise_error(SyntaxError)
  end

  it "should fail when field name shadows an existing method" do
    lambda {
      eval <<-END
        class ExistingNameSingleValue < BinData::SingleValue
          int8 :object_id
        end
      END
    }.should raise_error(NameError)
  end

  it "should fail on unknown endian" do
    lambda {
      eval <<-END
        class BadEndianSingleValue < BinData::SingleValue
          endian 'a bad value'
        end
      END
    }.should raise_error(ArgumentError)
  end
end
