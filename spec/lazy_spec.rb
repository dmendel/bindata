#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/lazy'

# A mock data object with customizable fields.
class MockDataObject
  def initialize(methods = {}, params = {}, parent = nil)
    methods.each do |k,v|
      meta = class << self ; self; end
      meta.send(:define_method, k.to_sym) { v }
    end
    @parameters = params
    @parent = parent
  end
  attr_accessor :parent

  def has_parameter?(k)
    @parameters.has_key?(k)
  end

  def get_parameter(k)
    @parameters[k]
  end
end

describe BinData::LazyEvaluator, "with no parents" do
  before(:each) do
    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    obj = MockDataObject.new(methods, params)
    @ev = BinData::LazyEvaluator.new(obj)
  end

  it "should evaluate raw value" do
    @ev.lazy_eval(5).should == 5
  end

  it "should evaluate value" do
    @ev.lazy_eval(lambda { 5 }).should == 5
  end

  it "should evaluate overrides" do
    @ev.lazy_eval(lambda { o1 }, :o1 => 'o1').should == 'o1'
  end

  it "should not resolve any unknown methods" do
    lambda { @ev.lazy_eval(lambda { unknown }) }.should raise_error(NameError)
    lambda { @ev.lazy_eval(lambda { m1 }) }.should raise_error(NameError)
    lambda { @ev.lazy_eval(lambda { p1 }) }.should raise_error(NameError)
  end

  it "should not have a parent" do
    @ev.lazy_eval(lambda { parent }).should be_nil
  end

  it "should not resolve #index" do
    lambda { @ev.lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end

describe BinData::LazyEvaluator, "with one parent" do
  before(:each) do
    parent_methods = {:m1 => 'Pm1', :com => 'PmC', :mm => 3}
    parent_params  = {:p1 => 'Pp1', :com => 'PpC'}
    parent_obj = MockDataObject.new(parent_methods, parent_params)

    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    obj = MockDataObject.new(methods, params, parent_obj)

    @ev = BinData::LazyEvaluator.new(obj)
  end

  it "should evaluate raw value" do
    @ev.lazy_eval(5).should == 5
  end

  it "should evaluate value" do
    @ev.lazy_eval(lambda { 5 }).should == 5
  end

  it "should evaluate overrides before params" do
    @ev.lazy_eval(lambda { p1 }, :p1 => 'o1').should == 'o1'
  end

  it "should evaluate overrides before methods" do
    @ev.lazy_eval(lambda { m1 }, :m1 => 'o1').should == 'o1'
  end

  it "should not resolve any unknown methods" do
    lambda { @ev.lazy_eval(lambda { unknown }) }.should raise_error(NameError)
  end

  it "should resolve parameters in the parent" do
    @ev.lazy_eval(lambda { p1 }).should == 'Pp1'
  end

  it "should resolve methods in the parent" do
    @ev.lazy_eval(lambda { m1 }).should == 'Pm1'
  end

  it "should resolve parameters in preference to methods in the parent" do
    @ev.lazy_eval(lambda { com }).should == 'PpC'
  end

  it "should have a parent" do
    @ev.lazy_eval(lambda { parent }).should_not be_nil
  end

  it "should not resolve #index" do
    lambda { @ev.lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end

describe BinData::LazyEvaluator, "with nested parents" do
  before(:each) do
    pparent_methods = {:m1 => 'PPm1', :m2 => 'PPm2', :com => 'PPmC'}
    pparent_params  = {:p1 => 'PPp1', :p2 => 'PPp2', :com => 'PPpC'}
    pparent_obj = MockDataObject.new(pparent_methods, pparent_params)

    parent_methods = {:m1 => 'Pm1', :com => 'PmC', :sym1 => :m2, :sym2 => lambda { m2 }}
    parent_params  = {:p1 => 'Pp1', :com => 'PpC'}
    parent_obj = MockDataObject.new(parent_methods, parent_params, pparent_obj)

    methods = {:m1 => 'm1', :com => 'mC'}
    params  = {:p1 => 'p1', :com => 'pC'}
    obj = MockDataObject.new(methods, params, parent_obj)

    @ev = BinData::LazyEvaluator.new(obj)
  end

  it "should accept symbols as a shortcut to lambdas" do
    @ev.lazy_eval(:p1).should == 'Pp1'
    @ev.lazy_eval(:p2).should == 'PPp2'
    @ev.lazy_eval(:m1).should == 'Pm1'
    @ev.lazy_eval(:m2).should == 'PPm2'
  end

  it "should not resolve any unknown methods" do
    lambda { @ev.lazy_eval(lambda { unknown }) }.should raise_error(NameError)
  end

  it "should resolve parameters in the parent" do
    @ev.lazy_eval(lambda { p1 }).should == 'Pp1'
  end

  it "should resolve methods in the parent" do
    @ev.lazy_eval(lambda { m1 }).should == 'Pm1'
  end

  it "should resolve parameters in the parent's parent" do
    @ev.lazy_eval(lambda { p2 }).should == 'PPp2'
  end

  it "should resolve methods in the parent's parent" do
    @ev.lazy_eval(lambda { m2 }).should == 'PPm2'
  end

  it "should resolve parameters in preference to methods in the parent" do
    @ev.lazy_eval(lambda { com }).should == 'PpC'
  end

  it "should resolve methods in the parent explicitly" do
    @ev.lazy_eval(lambda { parent.m1 }).should == 'PPm1'
  end

  it "should cascade lambdas " do
    @ev.lazy_eval(lambda { sym1 }).should == 'PPm2'
    @ev.lazy_eval(lambda { sym2 }).should == 'PPm2'
  end

  it "should not resolve #index" do
    lambda { @ev.lazy_eval(lambda { index }) }.should raise_error(NoMethodError)
  end
end
