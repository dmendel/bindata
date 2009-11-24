#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/bits'
require 'bindata/int'
require 'bindata/float'
require 'bindata/registry'

describe BinData::Registry do
  A = Class.new
  B = Class.new
  C = Class.new
  D = Class.new

  before(:each) do
    @r = BinData::Registry.new
  end

  it "should determine if a name is registered" do
    @r.register('A', A)

    @r.is_registered?('a').should be_true
  end

  it "should determine if a name is not registered" do
    @r.is_registered?('xyz').should be_false
  end

  it "should lookup registered names" do
    @r.register('ASubClass', A)
    @r.register('AnotherSubClass', B)

    @r.lookup('a_sub_class').should == A
    @r.lookup('another_sub_class').should  == B
  end

  it "should not lookup unregistered names" do
    @r.lookup('a_non_existent_sub_class').should be_nil
  end

  it "should allow overriding of registered classes" do
    @r.register('A', A)
    @r.register('A', B)

    @r.lookup('a').should == B
  end

  it "should convert CamelCase to underscores" do
    @r.underscore_name('CamelCase').should == 'camel_case'
  end

  it "should convert adjacent caps camelCase to underscores" do
    @r.underscore_name('XYZCamelCase').should == 'xyz_camel_case'
  end

  it "should ignore the outer nestings of classes" do
    @r.underscore_name('A::B::C').should == 'c'
  end
end

describe BinData::Registry, "with numerics" do
  before(:each) do
    @r = BinData::RegisteredClasses
  end

  it "should lookup integers with endian" do
    @r.lookup("int24", :big).to_s.should == "BinData::Int24be"
    @r.lookup("int24", :little).to_s.should == "BinData::Int24le"
    @r.lookup("uint24", :big).to_s.should == "BinData::Uint24be"
    @r.lookup("uint24", :little).to_s.should == "BinData::Uint24le"
  end

  it "should not lookup integers without endian" do
    @r.lookup("int24").should be_nil
  end

  it "should not lookup non byte based integers" do
    @r.lookup("int3").should be_nil
    @r.lookup("int3", :big).should be_nil
    @r.lookup("int3", :little).should be_nil
  end

  it "should lookup floats with endian" do
    @r.lookup("float", :big).to_s.should == "BinData::FloatBe"
    @r.lookup("float", :little).to_s.should == "BinData::FloatLe"
    @r.lookup("double", :big).to_s.should == "BinData::DoubleBe"
    @r.lookup("double", :little).to_s.should == "BinData::DoubleLe"
  end

  it "should lookup bits" do
    @r.lookup("bit5").to_s.should == "BinData::Bit5"
    @r.lookup("bit6le").to_s.should == "BinData::Bit6le"
  end

  it "should lookup bits by ignoring endian" do
    @r.lookup("bit2", :big).to_s.should == "BinData::Bit2"
    @r.lookup("bit3le", :big).to_s.should == "BinData::Bit3le"
    @r.lookup("bit2", :little).to_s.should == "BinData::Bit2"
    @r.lookup("bit3le", :little).to_s.should == "BinData::Bit3le"
  end
end
