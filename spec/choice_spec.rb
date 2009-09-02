#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
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
    lambda { BinData::Choice.new(args) }.should raise_error(BinData::UnknownTypeError)
  end

  it "should fail if a given type is unknown" do
    args = {:choices => {0 => :does_not_exist}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(BinData::UnknownTypeError)
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

  it "should fail if no choice has been set" do
    lambda { @data.value }.should raise_error(IndexError)
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

  it "should assign raw values" do
    @chooser.choice = 3
    @data.value = 254
    @data.value.should == 254
  end

  it "should assign Single values" do
    obj = ExampleSingle.new
    obj.value = 11

    @chooser.choice = 3
    @data.value = obj
    @data.value.should == 11
  end

  it "should clear" do
    @chooser.choice = 3
    @data.value = 254

    @data.clear
    @data.value.should be_zero
  end

  it "should be clear on initialisation" do
    @chooser.choice = 3

    @data.should be_clear
  end

  it "should not be clear after assignment" do
    @chooser.choice = 3
    @data.value = 254

    @data.should_not be_clear
  end

  it "should not copy value when changing selection" do
    @chooser.choice = 3
    @data.value = 254

    @chooser.choice = 7
    @data.value.should_not == 254
  end

  it "should behave as value" do
    @chooser.choice = 3
    @data.value = 5

    (@data + 1).should == 6
    (1 + @data).should == 6
  end
end

describe BinData::Choice, "with copy_on_change => true" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => :example_single,
                                             5 => :example_single,
                                             7 => :example_single,},
                                :selection => lambda { chooser.choice },
                                :copy_on_change => true)
    @chooser = chooser
  end

  it "should copy value when changing selection" do
    @chooser.choice = 3
    @data.value = 254

    @chooser.choice = 7
    @data.value.should == 254
  end
end
