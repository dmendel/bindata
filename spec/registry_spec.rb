#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/bits'
require 'bindata/int'
require 'bindata/registry'

describe BinData::Registry do
  before(:all) do
    A = Class.new
    B = Class.new
    C = Class.new
    D = Class.new
  end

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

=begin
  it "should lookup integers with endian" do
    @r.register("Int24be", A)
    @r.register("Int24le", B)
    @r.register("Uint24be", C)
    @r.register("Uint24le", D)

    @r.lookup("int24", :big).should == A
    @r.lookup("int24", :little).should == B
    @r.lookup("uint24", :big).should == C
    @r.lookup("uint24", :little).should == D
  end

  it "should not lookup integers without endian" do
    @r.register("Int24be", A)

    @r.lookup("int24").should be_nil
  end

  it "should lookup floats with endian" do
    @r.register("FloatBe", A)
    @r.register("FloatLe", B)
    @r.register("DoubleBe", C)
    @r.register("DoubleLe", D)

    @r.lookup("float", :big).should == A
    @r.lookup("float", :little).should == B
    @r.lookup("double", :big).should == C
    @r.lookup("double", :little).should == D
  end

  it "should automatically create classes for integers" do
    BinData.const_defined?(:Uint40be).should be_false
    @r.lookup("uint40be")
    BinData.const_defined?(:Uint40be).should be_true
  end

  it "should automatically create classes for big endian bits" do
    BinData.const_defined?(:Bit801).should be_false
    @r.lookup("bit801")
    BinData.const_defined?(:Bit801).should be_true
  end

  it "should automatically create classes for little endian bits" do
    BinData.const_defined?(:Bit802le).should be_false
    @r.lookup("bit802le")
    BinData.const_defined?(:Bit802le).should be_true
  end
=end
end
