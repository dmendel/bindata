#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/array'
require 'bindata/int'
require 'bindata/struct'

describe "Instantiating an Array" do
  it "should ensure mandatory parameters are supplied" do
    args = {}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
    args = {:initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if a given type is unknown" do
    args = {:type => :does_not_exist, :initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(TypeError)
  end

  it "should not allow both :initial_length and :read_until" do
    args = {:initial_length => 3, :read_until => lambda { false } }
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
  end
end

describe "An Array with no elements" do
  before(:each) do
    @data = BinData::Array.new(:type => :int8)
  end

  it "should return correct length" do
    @data.length.should be_zero
  end

  it "should be empty" do
    @data.should be_empty
  end

  it "should return nil for the first element" do
    @data.first.should be_nil
  end

  it "should return [] for the first n elements" do
    @data.first(3).should eql([])
  end

  it "should return nil for the last element" do
    @data.last.should be_nil
  end

  it "should return [] for the last n elements" do
    @data.last(3).should eql([])
  end

  it "should append an element" do
    @data.append(99)
    @data.length.should eql(1)
    @data.last.should eql(99)
  end
end

describe "An Array with several elements" do
  before(:each) do
    type = [:int16le, {:initial_value => lambda { index + 1 }}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  it "should return a correct snapshot" do
    @data.snapshot.should eql([1, 2, 3, 4, 5])
  end

  it "should coerce to ::Array if required" do
    ((1..7).to_a - @data).should eql([6, 7])
  end

  it "should return the first element" do
    @data.first.should eql(1)
  end

  it "should return the first n elements" do
    @data[0...3].should eql([1, 2, 3])
    @data.first(3).should eql([1, 2, 3])
    @data.first(99).should eql([1, 2, 3, 4, 5])
  end

  it "should return the last element" do
    @data.last.should eql(5)
    @data[-1].should eql(5)
  end

  it "should return the last n elements" do
    @data.last(3).should eql([3, 4, 5])
    @data.last(99).should eql([1, 2, 3, 4, 5])

    @data[-3, 100].should eql([3, 4, 5])
  end

  it "should have correct num elements" do
    @data.length.should eql(5)
    @data.size.should eql(5)
  end

  it "should have correct num_bytes" do
    @data.num_bytes.should eql(10)
  end

  it "should have correct num_bytes for individual elements" do
    @data.num_bytes(0).should eql(2)
  end

  it "should have no field_names" do
    @data.field_names.should be_empty
  end

  it "should be able to directly access elements" do
    @data[1] = 8
    @data[1].should eql(8)
  end

  it "should not be empty" do
    @data.should_not be_empty
  end

  it "should be able to use methods from Enumerable" do
    @data.select { |x| (x % 2) == 0 }.should eql([2, 4])
  end

  it "should clear" do
    @data[1] = 8
    @data.clear
    @data.collect.should eql([1, 2, 3, 4, 5])
  end

  it "should clear a single element" do
    @data[1] = 8
    @data.clear(1)
    @data[1].should eql(2)
  end

  it "should be clear upon creation" do
    @data.clear?.should be_true
  end

  it "should be clear if all elements are clear" do
    @data[1] = 8
    @data.clear(1)
    @data.clear?.should be_true
  end

  it "should test clear status of individual elements" do
    @data[1] = 8
    @data.clear?(0).should be_true
    @data.clear?(1).should be_false
  end

  it "should read and write correctly" do
    io = StringIO.new
    @data[1] = 8
    @data.write(io)

    @data.clear
    io.rewind
    @data[1].should eql(2)

    @data.read(io)
    @data[1].should eql(8)
  end

  it "should append an element" do
    @data.append(99)
    @data.length.should eql(6)
    @data.last.should eql(99)
  end
end

describe "An Array containing structs" do
  before(:each) do
    type = [:struct, {:fields => [[:int8, :a,
                                   {:initial_value => lambda { parent.index }}],
                                  [:int8, :b]]}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  it "should access elements, not values" do
    @data[3].a.should eql(3)
  end

  it "should access multiple elements with slice" do
    @data.slice(2, 3).collect { |x| x.a }.should eql([2, 3, 4])
  end

  it "should not be able to modify elements" do
    lambda { @data[1] = 3 }.should raise_error(NoMethodError)
  end

  it "should interate over each element" do
    @data.collect { |s| s.a }.should eql([0, 1, 2, 3, 4])
  end

  it "should be able to append elements" do
    obj = @data.append
    obj.a = 3
    obj.b = 5

    @data.last.a.should eql(3)
    @data.last.b.should eql(5)
  end
end

describe "An Array with :read_until containing +element+" do
  before(:each) do
    read_until = lambda { element == 5 }
    @data = BinData::Array.new(:type => :int8, :read_until => read_until)
  end

  it "should append to an empty array" do
    @data.append(3)
    @data.first.should eql(3)
  end

  it "should read until the sentinel is reached" do
    io = StringIO.new("\x01\x02\x03\x04\x05\x06\x07")
    @data.read(io)
    @data.length.should eql(5)
  end
end

describe "An Array with :read_until containing +array+ and +index+" do
  before(:each) do
    read_until = lambda { index >=2 and array[index - 2] == 5 }
    @data = BinData::Array.new(:type => :int8, :read_until => read_until)
  end

  it "should read until the sentinel is reached" do
    io = StringIO.new("\x01\x02\x03\x04\x05\x06\x07\x08")
    @data.read(io)
    @data.length.should eql(7)
  end
end
