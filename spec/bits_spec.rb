#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/bits'

describe "Bits of size 1" do
  before(:each) do
    @bit_classes = [BinData::Bit1, BinData::Bit1le]
  end

  it "should accept true as value" do
    @bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.value = true
      obj.value.should == 1
    end
  end

  it "should accept false as value" do
    @bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.value = false
      obj.value.should == 0
    end
  end

  it "should accept nil as value" do
    @bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.value = nil
      obj.value.should == 0
    end
  end
end

share_examples_for "All bitfields" do

  it "should have a sensible value of zero" do
    all_classes do |bit_class|
      bit_class.new.value.should be_zero
    end
  end

  it "should avoid underflow" do
    all_classes do |bit_class|
      obj = bit_class.new

      obj.value = min_value - 1
      obj.value.should == min_value
    end
  end

  it "should avoid overflow" do
    all_classes do |bit_class|
      obj = bit_class.new

      obj.value = max_value + 1
      obj.value.should == max_value
    end
  end

  it "should assign values" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        obj = bit_class.new
        obj.assign(val)

        obj.value.should == val
      end
    end
  end

  it "should assign values from other bit objects" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        src = bit_class.new
        src.assign(val)

        obj = bit_class.new
        obj.assign(src)

        obj.value.should == val
      end
    end
  end

  it "should have symmetric #read and #write" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        obj = bit_class.new
        obj.value = val

        written = obj.to_binary_s
        bit_class.read(written).should == val
      end
    end
  end

  def all_classes(&block)
    @bits.each_pair do |bit_class, nbits|
      @nbits = nbits
      yield bit_class
    end
  end

  def min_value
    0
  end

  def max_value
    (1 << @nbits) - 1
  end

  def some_values_within_range
    lo  = min_value + 1
    mid = (min_value + max_value) / 2
    hi  = max_value - 1

    [lo, mid, hi].find_all { |v| (min_value .. max_value).include?(v) }
  end
end

describe "Big endian bitfields" do
  it_should_behave_like "All bitfields"

  before(:all) do
    @bits = {}
    (1 .. 63).each do |nbits|
      bit_class = BinData.const_get("Bit#{nbits}")
      @bits[bit_class] = nbits
    end
  end

  it "should read big endian value" do
    @bits.each_pair do |bit_class, nbits|
      obj = bit_class.new

      nbytes = (nbits + 7) / 8
      str = [0b1000_0000].pack("C") + "\000" * (nbytes - 1)
      obj.read(str)
      obj.value.should == 1 << (nbits - 1)
    end
  end
end

describe "Little endian bitfields" do
  it_should_behave_like "All bitfields"

  before(:all) do
    @bits = {}
    (1 .. 63).each do |nbits|
      bit_class = BinData.const_get("Bit#{nbits}le")
      @bits[bit_class] = nbits
    end
  end

  it "should read little endian value" do
    @bits.each_pair do |bit_class, nbits|
      obj = bit_class.new

      nbytes = (nbits + 7) / 8
      str = [0b0000_0001].pack("C") + "\000" * (nbytes - 1)
      obj.read(str)
      obj.value.should == 1
    end
  end
end
