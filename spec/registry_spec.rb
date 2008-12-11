#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/registry'

describe BinData::Registry do
  before(:each) do
    @r = BinData::Registry.instance
  end

  it "should be a singleton" do
    BinData::Registry.instance.should == BinData::Registry.instance
  end

  it "should lookup registered names" do
    A = Class.new
    B = Class.new
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
