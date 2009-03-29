#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require File.expand_path(File.dirname(__FILE__)) + '/example'
require 'bindata/choice'

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
    args = {:choices => {:a => :example_single}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if :choices Hash has a nil key" do
    args = {:choices => {nil => :example_single}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end
end

share_examples_for "Choice initialized with array or hash" do
  it "should be able to select the choice" do
    @chooser.choice = 3
    @data.value.should == 30
  end

  it "should show the current selection" do
    @chooser.choice = 3
    @data.selection.should == 3
  end

  it "should be able to change the choice" do
    @chooser.choice = 3

    @chooser.choice = 7
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

    @data.num_bytes.should == ExampleSingle.new.num_bytes
  end
end

describe BinData::Choice, "with sparse choices array" do
  it_should_behave_like "Choice initialized with array or hash"

  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => [nil, nil, nil,
                                             [:example_single, {:value => 30}],
                                             nil,
                                             [:example_single, {:value => 50}],
                                             nil,
                                             [:example_single, {:value => 70}]],
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end
end

describe BinData::Choice, "with choices hash" do
  it_should_behave_like "Choice initialized with array or hash"

  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => [:example_single, {:value => 30}],
                                             5 => [:example_single, {:value => 50}],
                                             7 => [:example_single, {:value => 70}]},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end
end

describe BinData::Choice, "with single values" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => :example_single,
                                             5 => :example_single,
                                             7 => :example_single,},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should copy value when changing selection" do
    @chooser.choice = 3
    @data.value = 254

    @chooser.choice = 7
    @data.value.should == 254
  end

  it "should behave as value" do
    @chooser.choice = 3
    @data.value = 5

    (@data + 1).should == 6
    (1 + @data).should == 6
  end
end

describe BinData::Choice, "with multi values" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices =>
                                  {3 => :example_multi,
                                   5 => :example_multi},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should access fields" do
    @chooser.choice = 3
    @data.set_value(8, 9)
    @data.get_value.should == [8, 9]
  end

  it "should not copy values when changing fields" do
    @chooser.choice = 3
    @data.set_value(8, 9)

    @chooser.choice = 5
    @data.get_value.should_not == [8, 9]
  end

  it "should preserve values when switching selection" do
    @chooser.choice = 3
    @data.set_value(8, 9)

    @chooser.choice = 5
    @data.set_value(11, 12)

    @chooser.choice = 3
    @data.get_value.should == [8, 9]
  end
end
