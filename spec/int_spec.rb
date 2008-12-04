#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/int'

share_examples_for "All Integers" do
  def all_klasses(&block)
    @ints.each_pair do |klass, nbytes|
      @nbytes = nbytes
      yield klass
    end
  end

  def max_value
    if @signed
      (1 << (@nbytes * 8 - 1)) - 1
    else
      (1 << (@nbytes * 8)) - 1
    end
  end

  def min_value
    if @signed
      -max_value - 1
    else
      0
    end
  end

  # resulting int is guaranteed to be +ve for signed or unsigned integers
  def gen_test_int
    (0 ... @nbytes).inject(0) { |val, i| (val << 8) | ((val + 0x11) % 0x100) }
  end

  def int_to_str(val)
    str = ""
    v = val & ((1 << (@nbytes * 8)) - 1)
    @nbytes.times do
      str.concat(v & 0xff)
      v >>= 8
    end
    (@endian == :little) ? str : str.reverse
  end

  def test_conversion(klass, val, expected=nil)
    expected ||= val

    obj = klass.new
    obj.value = val

    # clamping should occur
    obj.value.should == expected
    
    actual_str   = obj.to_s
    expected_str = int_to_str(expected)

    # should convert to string as expected
    actual_str.should == expected_str

    # should convert from string as expected
    klass.read(expected_str).should == expected
  end

  it "should have a sensible value of zero" do
    all_klasses do |klass|
      klass.new.value.should be_zero
    end
  end

  it "should clamp when below the minimum" do
    all_klasses do |klass|
      test_conversion(klass, min_value-1, min_value)
    end
  end

  it "should clamp when above the maximum" do
    all_klasses do |klass|
      test_conversion(klass, max_value+1, max_value)
    end
  end

  it "should convert a +ve number" do
    all_klasses do |klass|
      test_conversion(klass, gen_test_int)
    end
  end

  it "should convert a -ve number" do
    all_klasses do |klass|
      if @signed
        test_conversion(klass, -gen_test_int)
      end
    end
  end
end

describe "All signed big endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    @endian = :big
    @signed = true
    @ints = {
      BinData::Int8 => 1,
      BinData::Int8be => 1,
      BinData::Int16be => 2,
      BinData::Int32be => 4,
      BinData::Int64be => 8,
      BinData::Int128be => 16,
    }
  end
end

describe "All unsigned big endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    @endian = :big
    @signed = false
    @ints = {
      BinData::Uint8 => 1,
      BinData::Uint8be => 1,
      BinData::Uint16be => 2,
      BinData::Uint32be => 4,
      BinData::Uint64be => 8,
      BinData::Uint128be => 16,
    }
  end
end

describe "All signed little endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    @endian = :little
    @signed = true
    @ints = {
      BinData::Int8 => 1,
      BinData::Int8le => 1,
      BinData::Int16le => 2,
      BinData::Int32le => 4,
      BinData::Int64le => 8,
      BinData::Int128le => 16,
    }
  end
end

describe "All unsigned little endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    @endian = :little
    @signed = false
    @ints = {
      BinData::Uint8 => 1,
      BinData::Uint8le => 1,
      BinData::Uint16le => 2,
      BinData::Uint32le => 4,
      BinData::Uint64le => 8,
      BinData::Uint128le => 16,
    }
  end
end
