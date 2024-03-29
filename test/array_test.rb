#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Array, "when instantiating" do
  describe "with no mandatory parameters supplied" do
    it "raises an error" do
      args = {}
      _ { BinData::Array.new(args) }.must_raise ArgumentError
    end
  end

  describe "with some but not all mandatory parameters supplied" do
    it "raises an error" do
      args = {initial_length: 3}
      _ { BinData::Array.new(args) }.must_raise ArgumentError
    end
  end

  it "warns about :length" do
    _ {
      BinData::Array.new(type: :uint8, length: 3)
    }.must_warn ":length is not used with BinData::Array.  You probably want to change this to :initial_length"
  end

  it "warns about :read_length" do
    _ {
      BinData::Array.new(type: :uint8, read_length: 3)
    }.must_warn ":read_length is not used with BinData::Array.  You probably want to change this to :initial_length"
  end

  it "fails if a given type is unknown" do
    args = {type: :does_not_exist, initial_length: 3}
    _ { BinData::Array.new(args) }.must_raise BinData::UnRegisteredTypeError
  end

  it "fails if :initial_length is not an integer" do
    args = {type: :uint8, initial_length: "3"}
    _ { BinData::Array.new(args) }.must_raise ArgumentError
  end

  it "does not allow both :initial_length and :read_until" do
    args = {initial_length: 3, read_until: -> { false } }
    _ { BinData::Array.new(args) }.must_raise ArgumentError
  end

  it "accepts BinData::Base as :type" do
    obj = BinData::Int8.new(initial_value: 5)
    array = BinData::Array.new(type: obj, initial_length: 1)
    _(array).must_equal [5]
  end
end

describe BinData::Array, "with no elements" do
  let(:obj) { BinData::Array.new(type: :uint32le) }

  it "initial state" do
    assert obj.clear?
    _(obj).must_be_empty
    _(obj.length).must_equal 0
    _(obj.first).must_be_nil
    _(obj.last).must_be_nil
  end

  it "returns [] for the first n elements" do
    _(obj.first(3)).must_equal []
  end

  it "returns [] for the last n elements" do
    _(obj.last(3)).must_equal []
  end

  it "won't assign nil" do
    _ { obj.assign(nil) }.must_raise ArgumentError
  end
end

describe BinData::Array, "with several elements" do
  let(:obj) {
    type = [:uint32le, {initial_value: -> { index + 1 }}]
    BinData::Array.new(type: type, initial_length: 5)
  }

  it "initial state" do
    assert obj.clear?
    _(obj).wont_be_empty
    _(obj.size).must_equal 5
    _(obj.length).must_equal 5
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5]
    _(obj.inspect).must_equal "[1, 2, 3, 4, 5]"
  end

  it "coerces to ::Array if required" do
    _([0].concat(obj)).must_equal [0, 1, 2, 3, 4, 5]
  end

  it "uses methods from Enumerable" do
    _(obj.select { |x| (x % 2) == 0 }).must_equal [2, 4]
  end

  it "assigns primitive values" do
    obj.assign([4, 5, 6])
    _(obj).must_equal [4, 5, 6]
  end

  it "assigns bindata objects" do
    obj.assign([BinData::Uint32le.new(4), BinData::Uint32le.new(5), BinData::Uint32le.new(6)])
    _(obj).must_equal [4, 5, 6]
  end

  it "assigns a bindata array" do
    array = BinData::Array.new([4, 5, 6], type: :uint32le)
    obj.assign(array)
    _(obj).must_equal [4, 5, 6]
  end

  it "returns the first element" do
    _(obj.first).must_equal 1
  end

  it "returns the first n elements" do
    _(obj[0...3]).must_equal [1, 2, 3]
    _(obj.first(3)).must_equal [1, 2, 3]
    _(obj.first(99)).must_equal [1, 2, 3, 4, 5]
  end

  it "returns the last element" do
    _(obj.last).must_equal 5
    _(obj[-1]).must_equal 5
  end

  it "returns the last n elements" do
    _(obj.last(3)).must_equal [3, 4, 5]
    _(obj.last(99)).must_equal [1, 2, 3, 4, 5]

    _(obj[-3, 100]).must_equal [3, 4, 5]
  end

  it "clears all" do
    obj[1] = 8
    obj.clear
    _(obj).must_equal [1, 2, 3, 4, 5]
  end

  it "clears a single element" do
    obj[1] = 8
    obj[1].clear
    _(obj[1]).must_equal 2
  end

  it "is clear if all elements are clear" do
    obj[1] = 8
    obj[1].clear
    assert obj.clear?
  end

  it "tests clear status of individual elements" do
    obj[1] = 8
    assert obj[0].clear?
    refute obj[1].clear?
  end

  it "directly accesses elements" do
    obj[1] = 8
    _(obj[1]).must_equal 8
  end

  it "symmetrically reads and writes" do
    obj[1] = 8
    str = obj.to_binary_s

    obj.clear
    _(obj[1]).must_equal 2

    obj.read(str)
    _(obj[1]).must_equal 8
  end

  it "identifies index of elements" do
    _(obj.index(3)).must_equal 2
  end

  it "returns nil for index of non existent element" do
    _(obj.index(42)).must_be_nil
  end

  it "has correct debug name" do
    _(obj[2].debug_name).must_equal "obj[2]"
  end

  it "has correct offset" do
    _(obj[2].rel_offset).must_equal 2 * 4
  end

  it "has correct num_bytes" do
    _(obj.num_bytes).must_equal 5 * 4
  end

  it "has correct num_bytes for individual elements" do
    _(obj[0].num_bytes).must_equal 4
  end
end

describe BinData::Array, "when accessing elements" do
  let(:obj) {
    type = [:uint32le, {initial_value: -> { index + 1 }}]
    data = BinData::Array.new(type: type, initial_length: 5)
    data.assign([1, 2, 3, 4, 5])
    data
  }

  it "inserts with positive indexes" do
    obj.insert(2, 30, 40)
    _(obj.snapshot).must_equal [1, 2, 30, 40, 3, 4, 5]
  end

  it "inserts with negative indexes" do
    obj.insert(-2, 30, 40)
    _(obj.snapshot).must_equal [1, 2, 3, 4, 30, 40, 5]
  end

  it "pushes" do
    obj.push(30, 40)
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5, 30, 40]
  end

  it "concats" do
    obj.concat([30, 40])
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5, 30, 40]
  end

  it "unshifts" do
    obj.unshift(30, 40)
    _(obj.snapshot).must_equal [30, 40, 1, 2, 3, 4, 5]
  end

  it "automatically extends on [index]" do
    _(obj[9]).must_equal 10
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  end

  it "automatically extends on []=" do
    obj[9] = 30
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 30]
  end

  it "automatically extends on insert" do
    obj.insert(7, 30, 40)
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5, 6, 7, 30, 40]
  end

  it "does not extend on at" do
    _(obj.at(9)).must_be_nil
    _(obj.length).must_equal 5
  end

  it "does not extend on [start, length]" do
    _(obj[9, 2]).must_be_nil
    _(obj.length).must_equal 5
  end

  it "does not extend on [range]" do
    _(obj[9 .. 10]).must_be_nil
    _(obj.length).must_equal 5
  end

  it "raises error on bad input to []" do
    _ { obj["a"] }.must_raise TypeError
    _ { obj[1, "a"] }.must_raise TypeError
  end

  it "is unaffected by self assignment" do
    obj.assign(obj)
    _(obj.snapshot).must_equal [1, 2, 3, 4, 5]
  end
end

describe BinData::Array, "with :read_until" do

  describe "containing +element+" do
    it "reads until the sentinel is reached" do
      read_until = lambda { element == 5 }
      obj = BinData::Array.new(type: :int8, read_until: read_until)

      obj.read "\x01\x02\x03\x04\x05\x06\x07\x08"
      _(obj).must_equal [1, 2, 3, 4, 5]
    end
  end

  describe "containing +array+ and +index+" do
    it "reads until the sentinel is reached" do
      read_until = lambda { index >= 2 and array[index - 2] == 5 }
      obj = BinData::Array.new(type: :int8, read_until: read_until)

      obj.read "\x01\x02\x03\x04\x05\x06\x07\x08"
      _(obj).must_equal [1, 2, 3, 4, 5, 6, 7]
    end
  end

  describe ":eof" do
    it "reads records until eof" do
      obj = BinData::Array.new(type: :int8, read_until: :eof)

      obj.read "\x01\x02\x03"
      _(obj).must_equal [1, 2, 3]
    end

    it "reads records until eof, ignoring partial records" do
      obj = BinData::Array.new(type: :int16be, read_until: :eof)

      obj.read "\x00\x01\x00\x02\x03"
      _(obj).must_equal [1, 2]
    end

    it "reports exceptions" do
      array_type = [:string, {read_length: -> { unknown_variable }}]
      obj = BinData::Array.new(type: array_type, read_until: :eof)
      _ { obj.read "\x00\x01\x00\x02\x03" }.must_raise NoMethodError
    end
  end
end

describe BinData::Array, "nested within an Array" do
  let(:obj) {
    nested_array_params = { type: [:int8, { initial_value: :index }],
                            initial_length: -> { index + 1 } }
    BinData::Array.new(type: [:array, nested_array_params],
                       initial_length: 3)
  }

  it "#snapshot" do
    _(obj.snapshot).must_equal [ [0], [0, 1], [0, 1, 2] ]
  end

  it "maintains structure when reading" do
    obj.read "\x04\x05\x06\x07\x08\x09"
    _(obj).must_equal [ [4], [5, 6], [7, 8, 9] ]
  end
end

describe BinData::Array, "subclassed" do
  class IntArray < BinData::Array
    endian :big
    default_parameter initial_element_value: 0

    uint16 initial_value: :initial_element_value
  end

  it "forwards parameters" do
    obj = IntArray.new(initial_length: 7)
    _(obj.length).must_equal 7
  end

  it "overrides default parameters" do
    obj = IntArray.new(initial_length: 3, initial_element_value: 5)
    _(obj.to_binary_s).must_equal_binary "\x00\x05\x00\x05\x00\x05"
  end
end

describe BinData::Array, "of bits" do
  let(:obj) { BinData::Array.new(type: :bit1, initial_length: 15) }

  it "reads" do
    str = [0b0001_0100, 0b1000_1000].pack("CC")
    obj.read(str)
    _(obj[0]).must_equal  0
    _(obj[1]).must_equal  0
    _(obj[2]).must_equal  0
    _(obj[3]).must_equal  1
    _(obj[4]).must_equal  0
    _(obj[5]).must_equal  1
    _(obj[6]).must_equal  0
    _(obj[7]).must_equal  0
    _(obj[8]).must_equal  1
    _(obj[9]).must_equal  0
    _(obj[10]).must_equal 0
    _(obj[11]).must_equal 0
    _(obj[12]).must_equal 1
    _(obj[13]).must_equal 0
    _(obj[14]).must_equal 0
  end

  it "writes" do
    obj[3] = 1
    _(obj.to_binary_s).must_equal_binary [0b0001_0000, 0b0000_0000].pack("CC")
  end

  it "returns num_bytes" do
    _(obj.num_bytes).must_equal 2
  end

  it "has correct offset" do
    _(obj[7].rel_offset).must_equal 0
    _(obj[8].rel_offset).must_equal 1
  end
end

