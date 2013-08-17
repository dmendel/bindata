#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "common"))

module AllBitfields

  def test_has_a_sensible_value_of_zero
    all_classes do |bit_class|
      bit_class.new.must_equal 0
    end
  end

  def test_avoids_underflow
    all_classes do |bit_class|
      obj = bit_class.new

      obj.assign(min_value - 1)
      obj.must_equal min_value
    end
  end

  def test_avoids_overflow
    all_classes do |bit_class|
      obj = bit_class.new

      obj.assign(max_value + 1)
      obj.must_equal max_value
    end
  end

  def test_assign_values
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        obj = bit_class.new
        obj.assign(val)

        obj.must_equal val
      end
    end
  end

  def test_assign_values_from_other_bit_objects
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        obj = bit_class.new
        obj.assign(bit_class.new(val))

        obj.must_equal val
      end
    end
  end

  def test_symmetrically_read_and_write
    all_classes do |bit_class|
      some_values_within_range.each do |val|
        obj = bit_class.new
        obj.assign(val)

        obj.value_read_from_written.must_equal obj
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
  include AllBitfields

  before do
    @bits = generate_bit_classes_to_test(:big)
  end

  it "read big endian values" do
    @bits.each_pair do |bit_class, nbits|
      nbytes = (nbits + 7) / 8
      str = [0b1000_0000].pack("C") + "\000" * (nbytes - 1)

      bit_class.read(str).must_equal 1 << (nbits - 1)
    end
  end
end

describe "Little endian bitfields" do
  include AllBitfields

  before do
    @bits = generate_bit_classes_to_test(:little)
  end

  it "read little endian values" do
    @bits.each_pair do |bit_class, nbits|
      nbytes = (nbits + 7) / 8
      str = [0b0000_0001].pack("C") + "\000" * (nbytes - 1)

      bit_class.read(str).must_equal 1
    end
  end
end

describe "Bits of size 1" do
  let(:bit_classes) { [BinData::Bit1, BinData::Bit1le] }

  it "accept true as value" do
    bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.assign(true)
      obj.must_equal 1
    end
  end

  it "accept false as value" do
    bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.assign(false)
      obj.must_equal 0
    end
  end

  it "accept nil as value" do
    bit_classes.each do |bit_class|
      obj = bit_class.new
      obj.assign(nil)
      obj.must_equal 0
    end
  end
end

