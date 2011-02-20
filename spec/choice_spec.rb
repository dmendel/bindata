#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/choice'

class Chooser
  attr_accessor :choice
end

class BinData::Choice
  def set_chooser(chooser)
    @chooser = chooser
  end
  def choice=(s)
    @chooser.choice = s
  end
end

def create_choice(choices, options = {})
  chooser = Chooser.new
  params = {:choices => choices, :selection => lambda { chooser.choice } }.merge(options)
  choice = BinData::Choice.new(params)
  choice.set_chooser(chooser)
  choice
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
    lambda { BinData::Choice.new(args) }.should raise_error(BinData::UnRegisteredTypeError)
  end

  it "should fail if a given type is unknown" do
    args = {:choices => {0 => :does_not_exist}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(BinData::UnRegisteredTypeError)
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
    subject.choice = 3
    subject.should == 30
  end

  it "should show the current selection" do
    subject.choice = 3
    subject.selection.should == 3
  end

  it "should forward #snapshot" do
    subject.choice = 3
    subject.snapshot.should == 30
  end

  it "should be able to change the choice" do
    subject.choice = 3

    subject.choice = 7
    subject.should == 70
  end

  it "should fail if no choice has been set" do
    lambda { subject.to_s }.should raise_error(IndexError)
  end

  it "should not be able to select an invalid choice" do
    subject.choice = 99
    lambda { subject.to_s }.should raise_error(IndexError)
  end

  it "should not be able to select a nil choice" do
    subject.choice = 1
    lambda { subject.to_s }.should raise_error(IndexError)
  end

  it "should handle missing methods correctly" do
    subject.choice = 3

    subject.should respond_to(:value)
    subject.should_not respond_to(:does_not_exist)
    lambda { subject.does_not_exist }.should raise_error(NoMethodError)
  end

  it "should delegate methods to the selected single choice" do
    subject.choice = 5
    subject.num_bytes.should == ExampleSingle.new.num_bytes
  end
end

describe BinData::Choice, "with sparse choices array" do
  it_should_behave_like "Choice initialized with array or hash"

  subject {
    choices = [nil, nil, nil,
               [:example_single, {:value => 30}], nil,
               [:example_single, {:value => 50}], nil,
               [:example_single, {:value => 70}]]
    create_choice(choices)
  }
end

describe BinData::Choice, "with choices hash" do
  it_should_behave_like "Choice initialized with array or hash"

  subject {
    choices = {3 => [:example_single, {:value => 30}],
               5 => [:example_single, {:value => 50}],
               7 => [:example_single, {:value => 70}]}
    create_choice(choices)
  }
end

describe BinData::Choice, "with single values" do
  subject {
    choices = {3 => :example_single,
               5 => :example_single,
               7 => :example_single}
    create_choice(choices)
  }

  it "should assign raw values" do
    subject.choice = 3
    subject.assign(254)
    subject.should == 254
  end

  it "should assign Single values" do
    obj = ExampleSingle.new(11)

    subject.choice = 3
    subject.assign(obj)
    subject.should == 11
  end

  it "should clear" do
    subject.choice = 3
    subject.assign(254)

    subject.clear
    subject.should be_zero
  end

  it "should be clear on initialisation" do
    subject.choice = 3

    subject.should be_clear
  end

  it "should not be clear after assignment" do
    subject.choice = 3
    subject.assign(254)

    subject.should_not be_clear
  end

  it "should not copy value when changing selection" do
    subject.choice = 3
    subject.assign(254)

    subject.choice = 7
    subject.should_not == 254
  end

  it "should behave as value" do
    subject.choice = 3
    subject.assign(5)

    (subject + 1).should == 6
    (1 + subject).should == 6
  end
end

describe BinData::Choice, "with copy_on_change => true" do
  subject {
    choices = {3 => :example_single,
               5 => :example_single,
               7 => :example_single}
    create_choice(choices, :copy_on_change => true)
  }

  it "should copy value when changing selection" do
    subject.choice = 3
    subject.assign(254)

    subject.choice = 7
    subject.should == 254
  end
end

describe BinData::Choice, "subclassed with default parameters" do
  class DerivedChoice < BinData::Choice
    endian :big
    default_parameter :selection => 'a'

    uint16 'a'
    uint32 'b'
  end

  it "should set initial selection" do
    subject = DerivedChoice.new
    subject.num_bytes.should == 2
  end

  it "should overide default parameter" do
    subject = DerivedChoice.new(:selection => 'b')
    subject.num_bytes.should == 4
  end
end
