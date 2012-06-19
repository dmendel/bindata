#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

shared_examples "All Integers" do

  it "have correct num_bytes" do
    all_classes do |int_class|
      int_class.new.num_bytes.should == @nbytes
    end
  end

  it "have a sensible value of zero" do
    all_classes do |int_class|
      int_class.new.should be_zero
    end
  end

  it "avoid underflow" do
    all_classes do |int_class|
      subject = int_class.new
      subject.assign(min_value - 1)

      subject.should == min_value
    end
  end

  it "avoid overflow" do
    all_classes do |int_class|
      subject = int_class.new
      subject.assign(max_value + 1)

      subject.should == max_value
    end
  end

  it "assign values" do
    all_classes do |int_class|
      subject = int_class.new
      test_int = gen_test_int
      subject.assign(test_int)

      subject.should == test_int
    end
  end

  it "assign values from other int objects" do
    all_classes do |int_class|
      src = int_class.new
      src.assign(gen_test_int)

      subject = int_class.new
      subject.assign(src)
      subject.should == src
    end
  end

  it "symmetrically read and write a +ve number" do
    all_classes do |int_class|
      subject = int_class.new
      subject.assign(gen_test_int)

      subject.value_read_from_written.should == subject
    end
  end

  it "symmetrically read and write a -ve number" do
    all_classes do |int_class|
      if @signed
        subject = int_class.new
        subject.assign(-gen_test_int)

        subject.value_read_from_written.should == subject
      end
    end
  end

  it "convert a +ve number to string" do
    all_classes do |int_class|
      val = gen_test_int

      subject = int_class.new
      subject.assign(val)

      subject.to_binary_s.should == int_to_binary_str(val)
    end
  end

  it "convert a -ve number to string" do
    all_classes do |int_class|
      if @signed
        val = -gen_test_int

        subject = int_class.new
        subject.assign(val)

        subject.to_binary_s.should == int_to_binary_str(val)
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

  def int_to_binary_str(val)
    str = ""
    v = val & ((1 << (@nbytes * 8)) - 1)
    @nbytes.times do
      str.concat(v & 0xff)
      v >>= 8
    end
    (@endian == :little) ? str : str.reverse
  end

  def create_mapping_of_class_to_nbits(endian, signed)
    base = signed ? "Int" : "Uint"
    signed_sym = signed ? :signed : :unsigned
    endian_str = (endian == :little) ? "le" : "be"

    result = {}
    result[BinData.const_get("#{base}8")] = 1
    (1 .. 20).each do |nbytes|
      nbits = nbytes * 8
      class_name = "#{base}#{nbits}#{endian_str}"
      result[BinData.const_get(class_name)] = nbytes
    end

    result
  end
end

describe "All signed big endian integers" do
  include_examples "All Integers"

  before(:all) do
    @endian = :big
    @signed = true
    @ints = create_mapping_of_class_to_nbits(@endian, @signed)
  end
end

describe "All unsigned big endian integers" do
  include_examples "All Integers"

  before(:all) do
    @endian = :big
    @signed = false
    @ints = create_mapping_of_class_to_nbits(@endian, @signed)
  end
end

describe "All signed little endian integers" do
  include_examples "All Integers"

  before(:all) do
    @endian = :little
    @signed = true
    @ints = create_mapping_of_class_to_nbits(@endian, @signed)
  end
end

describe "All unsigned little endian integers" do
  include_examples "All Integers"

  before(:all) do
    @endian = :little
    @signed = false
    @ints = create_mapping_of_class_to_nbits(@endian, @signed)
  end
end

describe "Custom defined integers" do
  it "fail unless bits are a multiple of 8" do
    expect {
      BinData::Uint7le
    }.to raise_error

    expect {
      BinData::Uint7be
    }.to raise_error

    expect {
      BinData::Int7le
    }.to raise_error

    expect {
      BinData::Int7be
    }.to raise_error
  end
end
