#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/choice'
require 'bindata/int'

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
  it "ensures mandatory parameters are supplied" do
    args = {}
    expect { BinData::Choice.new(args) }.to raise_error(ArgumentError)

    args = {:selection => 1}
    expect { BinData::Choice.new(args) }.to raise_error(ArgumentError)

    args = {:choices => []}
    expect { BinData::Choice.new(args) }.to raise_error(ArgumentError)
  end

  it "fails when a given type is unknown" do
    args = {:choices => [:does_not_exist], :selection => 0}
    expect { BinData::Choice.new(args) }.to raise_error(BinData::UnRegisteredTypeError)
  end

  it "fails when a given type is unknown" do
    args = {:choices => {0 => :does_not_exist}, :selection => 0}
    expect { BinData::Choice.new(args) }.to raise_error(BinData::UnRegisteredTypeError)
  end

  it "fails when :choices Hash has a symbol as key" do
    args = {:choices => {:a => :example_single}, :selection => 0}
    expect { BinData::Choice.new(args) }.to raise_error(ArgumentError)
  end

  it "fails when :choices Hash has a nil key" do
    args = {:choices => {nil => :example_single}, :selection => 0}
    expect { BinData::Choice.new(args) }.to raise_error(ArgumentError)
  end
end

shared_examples "Choice initialized with array or hash" do
  it "can select the choice" do
    subject.choice = 3
    subject.should == 30
  end

  it "shows the current selection" do
    subject.choice = 3
    subject.selection.should == 3
  end

  it "forwards #snapshot" do
    subject.choice = 3
    subject.snapshot.should == 30
  end

  it "can change the choice" do
    subject.choice = 3

    subject.choice = 7
    subject.should == 70
  end

  it "fails if no choice has been set" do
    expect { subject.to_s }.to raise_error(IndexError)
  end

  it "will not select an invalid choice" do
    subject.choice = 99
    expect { subject.to_s }.to raise_error(IndexError)
  end

  it "will not select a nil choice" do
    subject.choice = 1
    expect { subject.to_s }.to raise_error(IndexError)
  end

  it "handles missing methods correctly" do
    subject.choice = 3

    subject.should respond_to(:value)
    subject.should_not respond_to(:does_not_exist)
    expect { subject.does_not_exist }.to raise_error(NoMethodError)
  end

  it "delegates methods to the selected single choice" do
    subject.choice = 5
    subject.num_bytes.should == ExampleSingle.new.num_bytes
  end
end

describe BinData::Choice, "with sparse choices array" do
  include_examples "Choice initialized with array or hash"

  subject {
    choices = [nil, nil, nil,
               [:example_single, {:value => 30}], nil,
               [:example_single, {:value => 50}], nil,
               [:example_single, {:value => 70}]]
    create_choice(choices)
  }
end

describe BinData::Choice, "with choices hash" do
  include_examples "Choice initialized with array or hash"

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

  it "assigns raw values" do
    subject.choice = 3
    subject.assign(254)
    subject.should == 254
  end

  it "assigns Single values" do
    obj = ExampleSingle.new(11)

    subject.choice = 3
    subject.assign(obj)
    subject.should == 11
  end

  it "clears" do
    subject.choice = 3
    subject.assign(254)

    subject.clear
    subject.should be_zero
  end

  it "is clear on initialisation" do
    subject.choice = 3

    subject.should be_clear
  end

  it "is not clear after assignment" do
    subject.choice = 3
    subject.assign(254)

    subject.should_not be_clear
  end

  it "does not copy value when changing selection" do
    subject.choice = 3
    subject.assign(254)

    subject.choice = 7
    subject.should_not == 254
  end

  it "behaves as value" do
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

  it "copies value when changing selection" do
    subject.choice = 3
    subject.assign(254)

    subject.choice = 7
    subject.should == 254
  end
end

describe BinData::Choice, "with :default" do
  let(:choices) { { "a" => :int8, :default => :int16be } }

  it "selects for existing case" do
    subject = BinData::Choice.new(:selection => "a", :choices => choices)
    subject.num_bytes.should == 1
  end

  it "selects for default case" do
    subject = BinData::Choice.new(:selection => "other", :choices => choices)
    subject.num_bytes.should == 2
  end
end

describe BinData::Choice, "subclassed with default parameters" do
  class DerivedChoice < BinData::Choice
    endian :big
    default_parameter :selection => 'a'

    uint16 'a'
    uint32 'b'
    uint64 :default
  end

  it "sets initial selection" do
    subject = DerivedChoice.new
    subject.num_bytes.should == 2
  end

  it "overides default parameter" do
    subject = DerivedChoice.new(:selection => 'b')
    subject.num_bytes.should == 4
  end

  it "selects default selection" do
    subject = DerivedChoice.new(:selection => 'z')
    subject.num_bytes.should == 8
  end
end
