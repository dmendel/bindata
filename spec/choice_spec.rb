#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/choice'
require 'bindata/int'
require 'bindata/struct'

class Chooser
  attr_accessor :choice
end

describe BinData::Choice, "when instantiating" do
  it "should ensure mandatory parameters are supplied" do
    args = {}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
    args = {:selection => 1}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
    args = {:choices => []}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if a given type is unknown" do
    args = {:choices => [:does_not_exist], :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(TypeError)
  end

  it "should fail if a given type is unknown" do
    args = {:choices => {0 => :does_not_exist}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(TypeError)
  end

  it "should fail if :choices Hash has a symbol as key" do
    args = {:choices => {:a => :int8}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if :choices Hash has a nil key" do
    args = {:choices => {nil => :int8}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end
end

share_examples_for "Choice initialized with array or hash" do
  it "should be able to select the choice" do
    @chooser.choice = 3
    @data.selection.should == 3
    @data.value.should == 30
  end

  it "should be able to change the choice" do
    @chooser.choice = 3

    @chooser.choice = 7
    @data.selection.should == 7
    @data.value.should == 70
  end

  it "should not be able to select an invalid choice" do
    @chooser.choice = 99
    lambda { @data.value }.should raise_error(IndexError)
  end

  it "should not be able to select a nil choice" do
    @chooser.choice = 1
    lambda { @data.value }.should raise_error(IndexError)
  end

  it "should handle missing methods correctly" do
    @chooser.choice = 3

    @data.should respond_to(:value)
    @data.should_not respond_to(:does_not_exist)
    lambda { @data.does_not_exist }.should raise_error(NoMethodError)
  end

  it "should delegate methods to the selected single choice" do
    @chooser.choice = 5

    @data.num_bytes.should == 2
  end
end

describe BinData::Choice, "with sparse choices array" do
  it_should_behave_like "Choice initialized with array or hash"

  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => [nil, nil, nil,
                                             [:int8,    {:value => 30}],
                                             nil,
                                             [:int16le, {:value => 50}],
                                             nil,
                                             [:int32le, {:value => 70}]],
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end
end

describe BinData::Choice, "with choices hash" do
  it_should_behave_like "Choice initialized with array or hash"

  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => [:int8,    {:value => 30}],
                                             5 => [:int16le, {:value => 50}],
                                             7 => [:int32le, {:value => 70}]},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end
end

describe BinData::Choice, "with single values" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => :uint8,
                                             5 => :uint16le,
                                             7 => :uint32le,},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should copy value when changing selection" do
    @chooser.choice = 3
    @data.value = 254

    @chooser.choice = 7
    @data.value.should == 254
  end
end

describe BinData::Choice, "with multi values" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices =>
                                  {3 => [:struct, {:fields => [[:int8,  :a]]}],
                                   5 => [:struct, {:fields => [[:int8,  :a]]}]},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should access fields" do
    @chooser.choice = 3
    @data.a = 5
    @data.a.should == 5
  end

  it "should not copy values when changing fields" do
    @chooser.choice = 3
    @data.a = 17

    @chooser.choice = 5
    @data.a.should_not == 17
  end

  it "should preserve values when switching selection" do
    @chooser.choice = 3
    @data.a = 30

    @chooser.choice = 5
    @data.a = 50

    @chooser.choice = 3
    @data.a.should == 30
  end
end
