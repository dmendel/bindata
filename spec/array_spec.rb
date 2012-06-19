#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/array'
require 'bindata/int'
require 'bindata/string'

describe BinData::Array, "when instantiating" do
  context "with no mandatory parameters supplied" do
    it "raises an error" do
      args = {}
      expect { BinData::Array.new(args) }.to raise_error(ArgumentError)
    end
  end

  context "with some but not all mandatory parameters supplied" do
    it "raises an error" do
      args = {:initial_length => 3}
      expect { BinData::Array.new(args) }.to raise_error(ArgumentError)
    end
  end

  it "fails if a given type is unknown" do
    args = {:type => :does_not_exist, :initial_length => 3}
    expect { BinData::Array.new(args) }.to raise_error(BinData::UnRegisteredTypeError)
  end

  it "does not allow both :initial_length and :read_until" do
    args = {:initial_length => 3, :read_until => lambda { false } }
    expect { BinData::Array.new(args) }.to raise_error(ArgumentError)
  end
end

describe BinData::Array, "with no elements" do
  subject { BinData::Array.new(:type => :example_single) }

  it { should be_clear }
  it { should be_empty }
  its(:length) { should be_zero }
  its(:first)  { should be_nil }
  its(:last)   { should be_nil }

  it "returns [] for the first n elements" do
    subject.first(3).should == []
  end

  it "returns [] for the last n elements" do
    subject.last(3).should == []
  end
end

describe BinData::Array, "with several elements" do
  subject {
    type = [:example_single, {:initial_value => lambda { index + 1 }}]
    BinData::Array.new(:type => type, :initial_length => 5)
  }

  it { should be_clear }
  it { should_not be_empty }
  its(:size) { should == 5 }
  its(:length) { should == 5 }
  its(:snapshot) { should == [1, 2, 3, 4, 5] }
  its(:inspect) { should == "[1, 2, 3, 4, 5]" }

  it "coerces to ::Array if required" do
    [0].concat(subject).should == [0, 1, 2, 3, 4, 5]
  end

  it "uses methods from Enumerable" do
    subject.select { |x| (x % 2) == 0 }.should == [2, 4]
  end

  it "assigns primitive values" do
    subject.assign([4, 5, 6])
    subject.should == [4, 5, 6]
  end

  it "assigns bindata objects" do
    subject.assign([ExampleSingle.new(4), ExampleSingle.new(5), ExampleSingle.new(6)])
    subject.should == [4, 5, 6]
  end

  it "assigns a bindata array" do
    array = BinData::Array.new([4, 5, 6], :type => :example_single)
    subject.assign(array)
    subject.should == [4, 5, 6]
  end

  it "returns the first element" do
    subject.first.should == 1
  end

  it "returns the first n elements" do
    subject[0...3].should == [1, 2, 3]
    subject.first(3).should == [1, 2, 3]
    subject.first(99).should == [1, 2, 3, 4, 5]
  end

  it "returns the last element" do
    subject.last.should == 5
    subject[-1].should == 5
  end

  it "returns the last n elements" do
    subject.last(3).should == [3, 4, 5]
    subject.last(99).should == [1, 2, 3, 4, 5]

    subject[-3, 100].should == [3, 4, 5]
  end

  it "clears all" do
    subject[1] = 8
    subject.clear
    subject.should == [1, 2, 3, 4, 5]
  end

  it "clears a single element" do
    subject[1] = 8
    subject[1].clear
    subject[1].should == 2
  end

  it "is clear if all elements are clear" do
    subject[1] = 8
    subject[1].clear
    subject.should be_clear
  end

  it "tests clear status of individual elements" do
    subject[1] = 8
    subject[0].should be_clear
    subject[1].should_not be_clear
  end

  it "directly accesses elements" do
    subject[1] = 8
    subject[1].should == 8
  end

  it "symmetrically reads and writes" do
    subject[1] = 8
    str = subject.to_binary_s

    subject.clear
    subject[1].should == 2

    subject.read(str)
    subject[1].should == 8
  end

  it "identifies index of elements" do
    subject.index(3).should == 2
  end

  it "returns nil for index of non existent element" do
    subject.index(42).should be_nil
  end

  it "has correct debug name" do
    subject[2].debug_name.should == "obj[2]"
  end

  it "has correct offset" do
    subject[2].offset.should == ExampleSingle.new.num_bytes * 2
  end

  it "has correct num_bytes" do
    subject.num_bytes.should == 5 * ExampleSingle.new.num_bytes
  end

  it "has correct num_bytes for individual elements" do
    subject[0].num_bytes.should == ExampleSingle.new.num_bytes
  end
end

describe BinData::Array, "when accessing elements" do
  subject {
    type = [:example_single, {:initial_value => lambda { index + 1 }}]
    data = BinData::Array.new(:type => type, :initial_length => 5)
    data.assign([1, 2, 3, 4, 5])
    data
  }

  it "inserts with positive indexes" do
    subject.insert(2, 30, 40)
    subject.snapshot.should == [1, 2, 30, 40, 3, 4, 5]
  end

  it "inserts with negative indexes" do
    subject.insert(-2, 30, 40)
    subject.snapshot.should == [1, 2, 3, 4, 30, 40, 5]
  end

  it "pushes" do
    subject.push(30, 40)
    subject.snapshot.should == [1, 2, 3, 4, 5, 30, 40]
  end

  it "concats" do
    subject.concat([30, 40])
    subject.snapshot.should == [1, 2, 3, 4, 5, 30, 40]
  end

  it "unshifts" do
    subject.unshift(30, 40)
    subject.snapshot.should == [30, 40, 1, 2, 3, 4, 5]
  end

  it "automatically extends on [index]" do
    subject[9].should == 10
    subject.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  end

  it "automatically extends on []=" do
    subject[9] = 30
    subject.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 8, 9, 30]
  end

  it "automatically extends on insert" do
    subject.insert(7, 30, 40)
    subject.snapshot.should == [1, 2, 3, 4, 5, 6, 7, 30, 40]
  end

  it "does not extend on at" do
    subject.at(9).should be_nil
    subject.length.should == 5
  end

  it "does not extend on [start, length]" do
    subject[9, 2].should be_nil
    subject.length.should == 5
  end

  it "does not extend on [range]" do
    subject[9 .. 10].should be_nil
    subject.length.should == 5
  end

  it "raises error on bad input to []" do
    expect { subject["a"] }.to raise_error(TypeError)
    expect { subject[1, "a"] }.to raise_error(TypeError)
  end
end

describe BinData::Array, "with :read_until" do

  context "containing +element+" do
    it "reads until the sentinel is reached" do
      read_until = lambda { element == 5 }
      subject = BinData::Array.new(:type => :int8, :read_until => read_until)

      subject.read "\x01\x02\x03\x04\x05\x06\x07\x08"
      subject.should == [1, 2, 3, 4, 5]
    end
  end

  context "containing +array+ and +index+" do
    it "reads until the sentinel is reached" do
      read_until = lambda { index >= 2 and array[index - 2] == 5 }
      subject = BinData::Array.new(:type => :int8, :read_until => read_until)

      subject.read "\x01\x02\x03\x04\x05\x06\x07\x08"
      subject.should == [1, 2, 3, 4, 5, 6, 7]
    end
  end

  context ":eof" do
    it "reads records until eof" do
      subject = BinData::Array.new(:type => :int8, :read_until => :eof)

      subject.read "\x01\x02\x03"
      subject.should == [1, 2, 3]
    end

    it "reads records until eof, ignoring partial records" do
      subject = BinData::Array.new(:type => :int16be, :read_until => :eof)

      subject.read "\x00\x01\x00\x02\x03"
      subject.should == [1, 2]
    end

    it "reports exceptions" do
      array_type = [:string, {:read_length => lambda { unknown_variable }}]
      subject = BinData::Array.new(:type => array_type, :read_until => :eof)
      expect { subject.read "\x00\x01\x00\x02\x03" }.to raise_error
    end
  end
end

describe BinData::Array, "nested within an Array" do
  subject {
    nested_array_params = { :type => [:int8, { :initial_value => :index }],
                            :initial_length => lambda { index + 1 } }
    BinData::Array.new(:type => [:array, nested_array_params],
                       :initial_length => 3)
  }

  its(:snapshot) { should == [ [0], [0, 1], [0, 1, 2] ] }

  it "maintains structure when reading" do
    subject.read "\x04\x05\x06\x07\x08\x09"
    subject.should == [ [4], [5, 6], [7, 8, 9] ]
  end
end

describe BinData::Array, "subclassed" do
  class IntArray < BinData::Array
    endian :big
    default_parameter :initial_element_value => 0

    uint16 :initial_value => :initial_element_value
  end

  it "forwards parameters" do
    subject = IntArray.new(:initial_length => 7)
    subject.length.should == 7
  end

  it "overrides default parameters" do
    subject = IntArray.new(:initial_length => 3, :initial_element_value => 5)
    subject.to_binary_s.should == "\x00\x05\x00\x05\x00\x05"
  end
end

