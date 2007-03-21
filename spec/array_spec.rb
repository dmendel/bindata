#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/array'
require 'bindata/int'
require 'bindata/struct'

context "Instantiating an Array" do
  specify "should ensure mandatory parameters are supplied" do
    args = {}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
    args = {:type => :int8}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
    args = {:initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(ArgumentError)
  end

  specify "should fail if a given type is unknown" do
    args = {:type => :does_not_exist, :initial_length => 3}
    lambda { BinData::Array.new(args) }.should raise_error(TypeError)
  end
end

context "An Array with several elements" do
  setup do
    type = [:int16le, {:initial_value => lambda { index + 1 }}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  specify "should return a correct snapshot" do
    @data.snapshot.should eql([1, 2, 3, 4, 5])
  end

  specify "should have correct num elements" do
    @data.length.should eql(5)
    @data.size.should eql(5)
  end

  specify "should have correct num_bytes" do
    @data.num_bytes.should eql(10)
  end

  specify "should have correct num_bytes for individual elements" do
    @data.num_bytes(0).should eql(2)
  end

  specify "should have no field_names" do
    @data.field_names.should be_empty
  end

  specify "should be able to directly access elements" do
    @data[1] = 8
    @data[1].should eql(8)
  end

  specify "should be able to use methods from Enumerable" do
    @data.select { |x| (x % 2) == 0 }.should eql([2, 4])
  end

  specify "should clear" do
    @data[1] = 8
    @data.clear
    @data.collect.should eql([1, 2, 3, 4, 5])
  end

  specify "should clear a single element" do
    @data[1] = 8
    @data.clear(1)
    @data[1].should eql(2)
  end

  specify "should be clear upon creation" do
    @data.clear?.should be_true
  end

  specify "should be clear if all elements are clear" do
    @data[1] = 8
    @data.clear(1)
    @data.clear?.should be_true
  end

  specify "should test clear status of individual elements" do
    @data[1] = 8
    @data.clear?(0).should be_true
    @data.clear?(1).should be_false
  end

  specify "should read and write correctly" do
    io = StringIO.new
    @data[1] = 8
    @data.write(io)

    @data.clear
    io.rewind
    @data[1].should eql(2)

    @data.read(io)
    @data[1].should eql(8)
  end
end

context "An Array containing structs" do
  setup do
    type = [:struct, {:fields => [[:int8, :a,
                                   {:initial_value => lambda { parent.index }}],
                                  [:int8, :b]]}]
    @data = BinData::Array.new(:type => type, :initial_length => 5)
  end

  specify "should access elements, not values" do
    @data[3].a.should eql(3)
  end

  specify "should not be able to modify elements" do
    lambda { @data[1] = 3 }.should raise_error(NoMethodError)
  end

  specify "should interate over each element" do
    @data.collect { |s| s.a }.should eql([0, 1, 2, 3, 4])
  end
end
