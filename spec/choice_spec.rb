#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/choice'
require 'bindata/int'
require 'bindata/lazy'
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

  it "should fail if :choices isn't an Array or Hash" do
    args = {:choices => :does_not_exist, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if :choices Hash has a symbol as key" do
    args = {:choices => {:a => :int8}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if :choices Hash has a nil key" do
    args = {:choices => {nil => :int8}, :selection => 0}
    lambda { BinData::Choice.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail on all_possible_field_names with unsanitized parameters" do
    lambda {
      BinData::Choice.all_possible_field_names({})
    }.should raise_error(ArgumentError)
  end

  it "should return all possible field names for :choices Hash" do
    choices = {0 => [:struct, {:fields => [[:int8, :a], [:int8, :b]]}],
               1 => [:struct, {:fields => [[:int8, :c]]}]}
    args = {:choices => choices, :selection => 0}
    params = BinData::SanitizedParameters.new(BinData::Choice, args)
    BinData::Choice.all_possible_field_names(params).should == ["a", "b", "c"]
  end

  it "should return all possible field names for :choices Array" do
    choices = [[:struct, {:fields => [[:int8, :a], [:int8, :b]]}],
               [:struct, {:fields => [[:int8, :c]]}]]
    args = {:choices => choices, :selection => 0}
    params = BinData::SanitizedParameters.new(BinData::Choice, args)
    BinData::Choice.all_possible_field_names(params).should == ["a", "b", "c"]
  end
end

describe BinData::Choice, "with choices array" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => [[:int8,    {:value => 3}],
                                             [:int16le, {:value => 5}],
                                             [:int32le, {:value => 7}]],
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should be able to select the choice" do
    @chooser.choice = 0
    @data.value.should == 3
    @chooser.choice = 1
    @data.value.should == 5
    @chooser.choice = 2
    @data.value.should == 7
  end

  it "should handle :selection returning nil" do
    @chooser.choice = nil
    lambda { @data.value }.should raise_error(IndexError)
  end

  it "should not be able to select an invalid choice" do
    @chooser.choice = 99
    lambda { @data.value }.should raise_error(IndexError)
  end

  it "should handle missing methods correctly" do
    @chooser.choice = 0

    @data.should respond_to(:value)
    @data.should_not respond_to(:does_not_exist)
    lambda { @data.does_not_exist }.should raise_error(NoMethodError)
  end

  it "should delegate methods to the selected single choice" do
    @chooser.choice = 1

    @data.find_obj_for_name("does_not_exist").should be_nil
    @data.num_bytes.should == 2
    @data.field_names.should be_empty
  end
end

describe BinData::Choice, "with sparse choices array" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => [nil, nil, nil,
                                             [:int8,    {:value => 3}],
                                             nil,
                                             [:int16le, {:value => 5}],
                                             nil,
                                             [:int32le, {:value => 7}]],
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should be able to select the choice" do
    @chooser.choice = 3
    @data.value.should == 3
    @chooser.choice = 7
    @data.value.should == 7
  end

  it "should not be able to select an invalid choice" do
    @chooser.choice = 99
    lambda { @data.value }.should raise_error(IndexError)
  end

  it "should not be able to select a nil choice" do
    @chooser.choice = 1
    lambda { @data.value }.should raise_error(IndexError)
  end
end

describe BinData::Choice, "with choices hash" do
  before(:each) do
    chooser = Chooser.new
    @data = BinData::Choice.new(:choices => {3 => [:int8,    {:value => 3}],
                                             5 => [:int16le, {:value => 5}],
                                             7 => [:int32le, {:value => 7}]},
                                :selection => lambda { chooser.choice } )
    @chooser = chooser
  end

  it "should be able to select the choice" do
    @chooser.choice = 3
    @data.value.should == 3
    @chooser.choice = 7
    @data.value.should == 7
  end

  it "should not be able to select an invalid choice" do
    @chooser.choice = 99
    lambda { @data.value }.should raise_error(IndexError)
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

    @data.to_s.should == "\xfe"

    @chooser.choice = 5
    @data.to_s.should == "\xfe\x00"

    @chooser.choice = 7
    @data.to_s.should == "\xfe\x00\x00\x00"
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
    @data.a = 5
    @data.a.should == 5

    @chooser.choice = 5
    @data.a = 17
    @data.a.should == 17

    @chooser.choice = 3
    @data.a.should == 5

    @chooser.choice = 5
    @data.a.should == 17
  end
end
