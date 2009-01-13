#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

share_examples_for "All Integers" do

  it "should have a sensible value of zero" do
    all_classes do |int_class|
      int_class.new.value.should be_zero
    end
  end

  it "should avoid underflow" do
    all_classes do |int_class|
      obj = int_class.new
      obj.value = min_value - 1

      obj.value.should == min_value
    end
  end

  it "should avoid overflow" do
    all_classes do |int_class|
      obj = int_class.new
      obj.value = max_value + 1

      obj.value.should == max_value
    end
  end

  it "should symmetrically read and write a +ve number" do
    all_classes do |int_class|
      obj = int_class.new
      obj.value = gen_test_int

      str = obj.to_s
      int_class.read(str).should == obj.value
    end
  end

  it "should symmetrically read and write a -ve number" do
    all_classes do |int_class|
      if @signed
        obj = int_class.new
        obj.value = -gen_test_int

        str = obj.to_s
        int_class.read(str).should == obj.value
      end
    end
  end

  it "should convert a +ve number to string" do
    all_classes do |int_class|
      val = gen_test_int

      obj = int_class.new
      obj.value = val

      obj.to_s.should == int_to_str(val)
    end
  end

  it "should convert a -ve number to string" do
    all_classes do |int_class|
      if @signed
        val = -gen_test_int

        obj = int_class.new
        obj.value = val

        obj.to_s.should == int_to_str(val)
      end
    end
  end

  def all_classes(&block)
    @ints.each_pair do |int_class, nbytes|
      @nbytes = nbytes
      yield int_class
    end
  end

  def min_value
    if @signed
      -max_value - 1
    else
      0
    end
  end

  def max_value
    if @signed
      (1 << (@nbytes * 8 - 1)) - 1
    else
      (1 << (@nbytes * 8)) - 1
    end
  end

  def gen_test_int
    # resulting int is guaranteed to be +ve for signed or unsigned integers
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
end

describe "All signed big endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    BinData::Integer.define_class(24, :big, :signed)
    BinData::Integer.define_class(48, :big, :signed)
    BinData::Integer.define_class(96, :big, :signed)
    @endian = :big
    @signed = true
    @ints = {
      BinData::Int8 => 1,
      BinData::Int8be => 1,
      BinData::Int16be => 2,
      BinData::Int24be => 3,
      BinData::Int32be => 4,
      BinData::Int48be => 6,
      BinData::Int64be => 8,
      BinData::Int96be => 12,
      BinData::Int128be => 16,
    }
  end
end

describe "All unsigned big endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    BinData::Integer.define_class(24, :big, :unsigned)
    BinData::Integer.define_class(48, :big, :unsigned)
    BinData::Integer.define_class(96, :big, :unsigned)
    @endian = :big
    @signed = false
    @ints = {
      BinData::Uint8 => 1,
      BinData::Uint8be => 1,
      BinData::Uint16be => 2,
      BinData::Uint24be => 3,
      BinData::Uint32be => 4,
      BinData::Uint48be => 6,
      BinData::Uint64be => 8,
      BinData::Uint96be => 12,
      BinData::Uint128be => 16,
    }
  end
end

describe "All signed little endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    BinData::Integer.define_class(24, :little, :signed)
    BinData::Integer.define_class(48, :little, :signed)
    BinData::Integer.define_class(96, :little, :signed)
    @endian = :little
    @signed = true
    @ints = {
      BinData::Int8 => 1,
      BinData::Int8le => 1,
      BinData::Int16le => 2,
      BinData::Int24le => 3,
      BinData::Int32le => 4,
      BinData::Int48le => 6,
      BinData::Int64le => 8,
      BinData::Int96le => 12,
      BinData::Int128le => 16,
    }
  end
end

describe "All unsigned little endian integers" do
  it_should_behave_like "All Integers"

  before(:all) do
    BinData::Integer.define_class(24, :little, :unsigned)
    BinData::Integer.define_class(48, :little, :unsigned)
    BinData::Integer.define_class(96, :little, :unsigned)
    @endian = :little
    @signed = false
    @ints = {
      BinData::Uint8 => 1,
      BinData::Uint8le => 1,
      BinData::Uint16le => 2,
      BinData::Uint24le => 3,
      BinData::Uint32le => 4,
      BinData::Uint48le => 6,
      BinData::Uint64le => 8,
      BinData::Uint96le => 12,
      BinData::Uint128le => 16,
    }
  end
end
