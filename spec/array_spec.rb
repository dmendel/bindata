#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/array'
require 'bindata/int'

describe BinData::Array, "when instantiating" do
  it "should ensure mandatory parameters are supplied" do
    args = {}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
    args = {:initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
  end

  it "should fail if a given type is unknown" do
    args = {:type => :does_not_exist, :initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(BinData::UnRegisteredTypeError)
  end

  it "should not allow both :initial_length and :read_until" do
    args = {:initial_length => 3, :read_until => lambda { false } }
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
  end
end

describe BinData::Array, "with no elements" do
  before(:each) do
    @data = BinData::Array.new(:type => :example_single)
  end

  it "should be clear" do
    @data.should be_clear
  end

  it "should return zero length" do
    @data.length.should be_zero
  end

  it "should be empty" do
    @data.should be_empty
  end

  it "should return nil for the first element" do
    @data.first.should be_nil
  end

  it "should return [] for the first n elements" do
    @data.first(3).should == []
  end

  it "should return nil for the last element" do
    @data.last.should be_nil
  end

  it "should return [] for the last n elements" do
    @data.last(3).should == []
  end
end

describe BinData::Array, "with several elements" do
  before(:each) do
    type = [:example_single, {:initial_value => lambda { index + 1 }}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  it "should have correct debug name" do
    @data[2].debug_name.should == "obj[2]"
  end

  it "should have correct offset" do
    @data[2].offset.should == ExampleSingle.new.num_bytes * 2
  end

  it "should return a correct snapshot" do
    @data.snapshot.should == [1, 2, 3, 4, 5]
  end

  it "should assign primitive values" do
    @data.assign([4, 5, 6])
    @data.snapshot.should == [4, 5, 6]
  end

  it "should assign bindata objects" do
    o1 = ExampleSingle.new
    o1.value = 4
    o2 = ExampleSingle.new
    o2.value = 5
    o3 = ExampleSingle.new
    o3.value = 6
    @data.assign([o1, o2, o3])
    @data.snapshot.should == [4, 5, 6]
  end

  it "should assign bindata array" do
    array = BinData::Array.new(:type => :example_single)
    array.push(4, 5, 6)
    @data.assign(array)
    @data.snapshot.should == [4, 5, 6]
  end

  it "should coerce to ::Array if required" do
    [0].concat(@data).should == [0, 1, 2, 3, 4, 5]
  end

  it "should return the first element" do
    @data.first.should == 1
  end

  it "should return the first n elements" do
    @data[0...3].should == [1, 2, 3]
    @data.first(3).should == [1, 2, 3]
    @data.first(99).should == [1, 2, 3, 4, 5]
  end

  it "should return the last element" do
    @data.last.should == 5
    @data[-1].should == 5
  end

  it "should return the last n elements" do
    @data.last(3).should == [3, 4, 5]
    @data.last(99).should == [1, 2, 3, 4, 5]

    @data[-3, 100].should == [3, 4, 5]
  end

  it "should have correct num elements" do
    @data.length.should == 5
    @data.size.should == 5
  end

  it "should have correct num_bytes" do
    @data.num_bytes.should == 5 * ExampleSingle.new.num_bytes
  end

  it "should have correct num_bytes for individual elements" do
    @data[0].num_bytes.should == ExampleSingle.new.num_bytes
  end

  it "should be able to directly access elements" do
    @data[1] = 8
    @data[1].should == 8
  end

  it "should not be empty" do
    @data.should_not be_empty
  end

  it "should return a nicely formatted array for inspect" do
    @data.inspect.should == "[1, 2, 3, 4, 5]"
  end

  it "should be able to use methods from Enumerable" do
    @data.select { |x| (x % 2) == 0 }.should == [2, 4]
  end

  it "should clear" do
    @data[1] = 8
    @data.clear
    @data.should == [1, 2, 3, 4, 5]
  end

  it "should clear a single element" do
    @data[1] = 8
    @data[1].clear
    @data[1].should == 2
  end

  it "should be clear upon creation" do
    @data.should be_clear
  end

  it "should be clear if all elements are clear" do
    @data[1] = 8
    @data[1].clear
    @data.should be_clear
  end

  it "should test clear status of individual elements" do
    @data[1] = 8
    @data[0].should be_clear
    @data[1].should_not be_clear
  end

  it "should symmetrically read and write" do
    @data[1] = 8
    str = @data.to_binary_s

    @data.clear
    @data[1].should == 2

    @data.read(str)
    @data[1].should == 8
  end

  it "should identify index of elements" do
    @data.index(3).should == 2
  end

  it "should return nil for index of non existent element" do
    @data.index(42).should be_nil
  end
end

describe BinData::Array, "when accessing elements" do
  before(:each) do
    type = [:example_single, {:initial_value => lambda { index + 1 }}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
    @data[0] = 1
    @data[1] = 2
    @data[2] = 3
    @data[3] = 4
    @data[4] = 5
  end

  it "should insert with positive indexes" do
    @data.insert(2, 30, 40)
    @data.snapshot.should == [1, 2, 30, 40, 3, 4, 5]
  end

  it "should insert with negative indexes" do
    @data.insert(-2, 30, 40)
    @data.snapshot.should == [1, 2, 3, 4, 30, 40, 5]
  end

  it "should push" do
    @data.push(30, 40)
    @data.snapshot.should == [1, 2, 3, 4, 5, 30, 40]
  end

  it "should concat" do
    @data.concat([30, 40])
    @data.snapshot.should == [1, 2, 3, 4, 5, 30, 40]
  end

  it "should unshift" do
    @data.unshift(30, 40)
    @data.snapshot.should == [30, 40, 1, 2, 3, 4, 5]
  end

  it "should automatically extend on [index]" do
    @data[9].should == 10
    @data.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  end

  it "should automatically extend on []=" do
    @data[9] = 30
    @data.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 8, 9, 30]
  end

  it "should automatically extend on insert" do
    @data.insert(7, 30, 40)
    @data.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 30, 40]
  end

  it "should not extend on at" do
    @data.at(9).should be_nil
    @data.length.should == 5
  end

  it "should not extend on [start, length]" do
    @data[9, 2].should be_nil
    @data.length.should == 5
  end

  it "should not extend on [range]" do
    @data[9 .. 10].should be_nil
    @data.length.should == 5
  end

  it "should raise error on bad input to []" do
    lambda { @data["a"] }.should raise_error(TypeError)
    lambda { @data[1, "a"] }.should raise_error(TypeError)
  end
end

describe BinData::Array, "with :read_until containing +element+" do
  before(:each) do
    read_until = lambda { element == 5 }
    @data = BinData::Array.new(:type => :int8, :read_until => read_until)
  end

  it "should read until the sentinel is reached" do
    str = "\x01\x02\x03\x04\x05\x06\x07"
    @data.read(str)
    @data.length.should == 5
  end
end

describe BinData::Array, "with :read_until containing +array+ and +index+" do
  before(:each) do
    read_until = lambda { index >= 2 and array[index - 2] == 5 }
    @data = BinData::Array.new(:type => :int8, :read_until => read_until)
  end

  it "should read until the sentinel is reached" do
    str = "\x01\x02\x03\x04\x05\x06\x07\x08"
    @data.read(str)
    @data.length.should == 7
  end
end

describe BinData::Array, "with :read_until => :eof" do
  it "should read records until eof" do
    obj = BinData::Array.new(:type => :int8, :read_until => :eof)
    str = "\x01\x02\x03"
    obj.read(str)
    obj.snapshot.should == [1, 2, 3]
  end

  it "should read records until eof, ignoring partial records" do
    obj = BinData::Array.new(:type => :int16be, :read_until => :eof)
    str = "\x00\x01\x00\x02\x03"
    obj.read(str)
    obj.snapshot.should == [1, 2]
  end
end

describe BinData::Array, "nested within an Array" do
  before(:each) do
    nested_array_params = { :type => [:int8, { :initial_value => :index }],
                            :initial_length => lambda { index + 1 } }
    @data = BinData::Array.new(:type => [:array, nested_array_params],
                               :initial_length => 3)
  end

  it "should use correct index" do
    @data.snapshot.should == [ [0], [0, 1], [0, 1, 2] ]
  end

  it "should maintain structure when reading" do
    str = "\x04\x05\x06\x07\x08\x09"
    @data.read(str)
    @data.snapshot.should == [ [4], [5, 6], [7, 8, 9] ]
  end
end
