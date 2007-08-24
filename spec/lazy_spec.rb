#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/lazy'

# A mock data object with customizable fields.
class MockDataObject
  def initialize(fields = {})
    fields.each do |k,v|
      self.class.send(:define_method, k.to_sym) { v }
    end
  end
end

describe "A single environment" do
  before(:each) do
    @do1 = MockDataObject.new(:f1 => 'f1')
    @e1 = BinData::LazyEvalEnv.new
    @e1.data_object = @do1
    @e1.add_variable(:v1, 'v1')
  end

  it "should accept symbols as a shortcut to lambda" do
    @e1.lazy_eval(lambda { o1 }, :o1 => 'o1').should eql('o1')
    @e1.lazy_eval(lambda { v1 }).should eql('v1')
    @e1.lazy_eval(:o1, :o1 => 'o1').should eql('o1')
    @e1.lazy_eval(:v1).should eql('v1')
  end

  it "should evaluate overrides" do
    @e1.lazy_eval(:o1, :o1 => 'o1').should eql('o1')
  end

  it "should evaluate variables" do
    @e1.lazy_eval(:v1).should eql('v1')
  end

  it "should prioritise overrides over variables" do
    @e1.lazy_eval(:v1, :v1 => 'o1').should eql('o1')
  end

  it "should not resolve any unknown fields" do
    lambda { @e1.lazy_eval(:unknown) }.should raise_error(NameError)
    lambda { @e1.lazy_eval(:p1) }.should raise_error(NameError)
    lambda { @e1.lazy_eval(:f1) }.should raise_error(NameError)
  end
end

describe "An environment with one parent" do
  before(:each) do
    @do2 = MockDataObject.new(:f2 => 'f2', :common1 => 'f2', :common2 => 'f2')
    @do1 = MockDataObject.new

    @e2 = BinData::LazyEvalEnv.new
    @e1 = BinData::LazyEvalEnv.new(@e2)

    @e2.data_object = @do2
    @e1.data_object = @do1

    @e1.add_variable(:common2, 'v1')

    @e2.params = {:p2 => 'p2', :common1 => 'p2', :common2 => 'p2'}
    @e2.add_variable(:common2, 'v2')
  end

  it "should evaluate parent parameter" do
    @e1.lazy_eval(:p2).should eql('p2')
  end

  it "should evaluate parent field" do
    @e1.lazy_eval(:f2).should eql('f2')
  end

  it "should prefer parent param over parent field" do
    @e1.lazy_eval(:common1).should eql('p2')
  end

  it "should prefer variable over parent param" do
    @e1.lazy_eval(:common2).should eql('v1')
  end
end

describe "A nested environment" do
  before(:each) do
    @do4 = MockDataObject.new(:f4 => 'f4')
    @do3 = MockDataObject.new(:f3 => 'f3')
    @do2 = MockDataObject.new(:f2 => 'f2', :fs2 => :s3)
    @do1 = MockDataObject.new(:f1 => 'f1')

    @e4 = BinData::LazyEvalEnv.new
    @e3 = BinData::LazyEvalEnv.new(@e4)
    @e2 = BinData::LazyEvalEnv.new(@e3)
    @e1 = BinData::LazyEvalEnv.new(@e2)

    @e4.data_object = @do4
    @e3.data_object = @do3
    @e2.data_object = @do2
    @e1.data_object = @do1

    @e4.params = {:p4 => 'p4', :s4 => 's4', :l4 => 'l4'}
    @e3.params = {:p3 => 'p3', :s3 => :s4, :s4 => 'xx', :l3 => lambda { l4 }}
    @e2.params = {:p2 => 'p2', :s2 => :s3, :l2 => lambda { l3 }}

    @e2.add_variable(:v2, 'v2')
  end

  it "should access parent environments" do
    @e1.lazy_eval(lambda { parent.p3 }).should eql('p3')
    @e1.lazy_eval(lambda { parent.parent.p4 }).should eql('p4')
  end

  it "should cascade lambdas" do
    @e1.lazy_eval(lambda { l2 }).should eql('l4')
    @e1.lazy_eval(lambda { s2 }).should eql('s4')
  end

  it "should access parent environments by cascading" do
    @e1.lazy_eval(lambda { p3 }).should eql('p3')
    @e1.lazy_eval(lambda { p4 }).should eql('p4')
    @e1.lazy_eval(lambda { v2 }).should eql('v2')
    @e1.lazy_eval(lambda { s3 }).should eql('s4')
    @e1.lazy_eval(lambda { fs2 }).should eql('s4')
  end
end
