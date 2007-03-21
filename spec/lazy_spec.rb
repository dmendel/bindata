#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/lazy'

# A mock data object that can substitute for BinData::Simple or BinData::Struct
class MockDataObject
  def initialize(value = nil, fields = {})
    @value = value
    @fields = fields
  end
  attr_accessor :value

  def field_names
    @fields.keys.collect { |k| k.to_s }
  end
  def respond_to?(symbol, include_private = false)
    field_names.include?(symbol.id2name) ? true : super
  end
  def method_missing(symbol, *args)
    @fields[symbol] || super
  end
end

context "A single environment" do
  setup do
    @do1 = MockDataObject.new('v1', :f1 => 'f1')
    @e1 = BinData::LazyEvalEnv.new
    @e1.data_object = @do1
    @e1.params = {:p1 => 'p1'}
  end

  specify "should evaluate value" do
    @e1.lazy_eval(lambda { value }).should eql('v1')
  end

  specify "should evaluate index" do
    @e1.index = 7
    @e1.lazy_eval(lambda { index }).should eql(7)
  end

  specify "should evaluate offset" do
    @e1.offset = 9
    @e1.lazy_eval(lambda { offset }).should eql(9)
  end

  specify "should not resolve any unknown fields" do
    lambda { @e1.lazy_eval(lambda { unknown }) }.should raise_error(NameError)
    lambda { @e1.lazy_eval(lambda { p1 }) }.should raise_error(NameError)
    lambda { @e1.lazy_eval(lambda { f1 }) }.should raise_error(NameError)
  end

  specify "should accept symbols as a shortcut to lambda" do
    @e1.index  = 7
    @e1.offset = 9
    @e1.lazy_eval(:value).should eql('v1')
    @e1.lazy_eval(:index).should eql(7)
    @e1.lazy_eval(:offset).should eql(9)
  end
end

context "An environment with one parent" do
  setup do
    @do2 = MockDataObject.new(nil, :f2 => 'f2', :common => 'field2')
    @do1 = MockDataObject.new

    @e2 = BinData::LazyEvalEnv.new
    @e1 = BinData::LazyEvalEnv.new(@e2)

    @e2.data_object = @do2
    @e1.data_object = @do1

    @e2.params = {:p2 => 'p2', :l2 => lambda { 'l2' }, :common => 'param2'}
  end

  specify "should evaluate parent parameter" do
    @e1.lazy_eval(:p2).should eql('p2')
  end

  specify "should evaluate parent field" do
    @e1.lazy_eval(:f2).should eql('f2')
  end

  specify "should prefer parent param over parent field" do
    @e1.lazy_eval(:common).should eql('param2')
  end
end

context "A nested environment" do
  setup do
    @do4 = MockDataObject.new(nil, :f4 => 'f4')
    @do3 = MockDataObject.new(nil, :f3 => 'f3')
    @do2 = MockDataObject.new(nil, :f2 => 'f2')
    @do1 = MockDataObject.new(nil, :f1 => 'f1')

    @e4 = BinData::LazyEvalEnv.new
    @e3 = BinData::LazyEvalEnv.new(@e4)
    @e2 = BinData::LazyEvalEnv.new(@e3)
    @e1 = BinData::LazyEvalEnv.new(@e2)

    @e4.data_object = @do4
    @e3.data_object = @do3
    @e2.data_object = @do2
    @e1.data_object = @do1

    @e4.params = {:p4 => 'p4', :s4 => 's4', :l4 => 'l4'}
    @e3.params = {:p3 => 'p3', :s3 => :s4, :l3 => lambda { l4 }}
    @e2.params = {:p2 => 'p2', :s2 => :s3, :l2 => lambda { l3 }}
  end

  specify "should access parent environments" do
    @e1.lazy_eval(lambda { parent.p3 }).should eql('p3')
    @e1.lazy_eval(lambda { parent.parent.p4 }).should eql('p4')
  end

  specify "should cascade lambdas" do
    @e1.lazy_eval(lambda { l2 }).should eql('l4')
    @e1.lazy_eval(lambda { s2 }).should eql('s4')
  end
end
