#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/bits'

describe "Bits of size 1" do
  let(:bit_classes) { [BinData::Bit1, BinData::Bit1le] }

  it "accept true as value" do
    bit_classes.each do |bit_class|
      subject = bit_class.new
      subject.assign(true)
      subject.should == 1
    end
  end

  it "accept false as value" do
    bit_classes.each do |bit_class|
      subject = bit_class.new
      subject.assign(false)
      subject.should == 0
    end
  end

  it "accept nil as value" do
    bit_classes.each do |bit_class|
      subject = bit_class.new
      subject.assign(nil)
      subject.should == 0
    end
  end
end

shared_examples "All bitfields" do

  it "have a sensible value of zero" do
    all_classes do |bit_class|
      bit_class.new.should be_zero
    end
  end

  it "avoid underflow" do
    all_classes do |bit_class|
      subject = bit_class.new

      subject.assign(min_value - 1)
      subject.should == min_value
    end
  end

  it "avoid overflow" do
    all_classes do |bit_class|
      subject = bit_class.new

      subject.assign(max_value + 1)
      subject.should == max_value
    end
  end

  it "assign values" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        subject = bit_class.new
        subject.assign(val)

        subject.should == val
      end
    end
  end

  it "assign values from other bit objects" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        subject = bit_class.new
        subject.assign(bit_class.new(val))

        subject.should == val
      end
    end
  end

  it "symmetrically #read and #write" do
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        subject = bit_class.new
        subject.assign(val)

        subject.value_read_from_written.should == subject
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

    [lo, mid, hi].select { |val| value_within_range?(val) }
  end

  def value_within_range?(val)
    (min_value .. max_value).include?(val)
  end
end

def generate_bit_classes_to_test(endian)
  bits = {}
  (1 .. 50).each do |nbits|
    name = (endian == :big) ? "Bit#{nbits}" : "Bit#{nbits}le"
    bit_class = BinData.const_get(name)
    bits[bit_class] = nbits
  end
  bits
end

describe "Big endian bitfields" do
  include_examples "All bitfields"

  before(:all) do
    @bits = generate_bit_classes_to_test(:big)
  end

  it "read big endian values" do
    @bits.each_pair do |bit_class, nbits|
      nbytes = (nbits + 7) / 8
      str = [0b1000_0000].pack("C") + "\000" * (nbytes - 1)

      bit_class.read(str).should == 1 << (nbits - 1)
    end
  end
end

describe "Little endian bitfields" do
  include_examples "All bitfields"

  before(:all) do
    @bits = generate_bit_classes_to_test(:little)
  end

  it "read little endian values" do
    @bits.each_pair do |bit_class, nbits|
      nbytes = (nbits + 7) / 8
      str = [0b0000_0001].pack("C") + "\000" * (nbytes - 1)

      bit_class.read(str).should == 1
    end
  end
end
