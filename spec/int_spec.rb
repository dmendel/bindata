#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/int'

context "All signed integers" do
  specify "should have a sensible value of zero" do
    [BinData::Int8,
     BinData::Int16le,
     BinData::Int16be,
     BinData::Int32le,
     BinData::Int32be].each do |klass|
      klass.new.value.should == 0
    end
  end

  specify "should pass these tests" do
    [
      [1, true,  BinData::Int8],
      [2, false, BinData::Int16le],
      [2, true,  BinData::Int16be],
      [4, false, BinData::Int32le],
      [4, true,  BinData::Int32be],
    ].each do |nbytes, big_endian, klass|
      gen_int_test_data(nbytes, big_endian).each do |val, clamped_val, str|
        test_read_write(klass, val, clamped_val, str)
      end
    end
  end
end

context "All unsigned integers" do
  specify "should have a sensible value of zero" do
    [BinData::Uint8,
     BinData::Uint16le,
     BinData::Uint16be,
     BinData::Uint32le,
     BinData::Uint32be].each do |klass|
      klass.new.value.should == 0
    end
  end

  specify "should pass these tests" do
    [
      [1, true,  BinData::Uint8],
      [2, false, BinData::Uint16le],
      [2, true,  BinData::Uint16be],
      [4, false, BinData::Uint32le],
      [4, true,  BinData::Uint32be],
    ].each do |nbytes, big_endian, klass|
      gen_uint_test_data(nbytes, big_endian).each do |val, clamped_val, str|
        test_read_write(klass, val, clamped_val, str)
      end
    end
  end
end

# run read / write tests for the given values
def test_read_write(klass, val, clamped_val, str)
  # set the data and ensure clamping occurs
  data = klass.new
  data.value = val
  data.value.should == clamped_val
  
  # write the data
  io = StringIO.new
  data.write(io)

  # check that we write the expected byte pattern
  io.rewind
  io.read.should == str

  # check that we read in the same data that was written
  io.rewind
  data = klass.new
  data.read(io)
  data.value.should == clamped_val
end

# return test data for testing unsigned ints
def gen_uint_test_data(nbytes, big_endian)
  raise "nbytes too big" if nbytes > 8
  tests = []

  # test the minimum value
  v = 0
  s = "\x00" * nbytes
  tests.push [v, v, big_endian ? s : s.reverse]

  # values below minimum should be clamped to minimum
  tests.push [v-1, v, big_endian ? s : s.reverse]

  # test a value within range
  v = 0x123456789abcdef0 >> ((8-nbytes) * 8)
  s = "\x12\x34\x56\x78\x9a\xbc\xde\xf0".slice(0, nbytes)
  tests.push [v, v, big_endian ? s : s.reverse]

  # test the maximum value
  v = (1 << (nbytes * 8)) - 1
  s = "\xff" * nbytes
  tests.push [v, v, big_endian ? s : s.reverse]

  # values above maximum should be clamped to maximum
  tests.push [v+1, v, big_endian ? s : s.reverse]

  tests
end

# return test data for testing signed ints
def gen_int_test_data(nbytes, big_endian)
  raise "nbytes too big" if nbytes > 8
  tests = []

  # test the minimum value
  v = -((1 << (nbytes * 8 - 1)) - 1) -1
  s = "\x80\x00\x00\x00\x00\x00\x00\x00".slice(0, nbytes)
  tests.push [v, v, big_endian ? s : s.reverse]

  # values below minimum should be clamped to minimum
  tests.push [v-1, v, big_endian ? s : s.reverse]

  # test a -ve value within range
  v = -1
  s = "\xff" * nbytes
  tests.push [v, v, big_endian ? s : s.reverse]

  # test a +ve value within range
  v = 0x123456789abcdef0 >> ((8-nbytes) * 8)
  s = "\x12\x34\x56\x78\x9a\xbc\xde\xf0".slice(0, nbytes)
  tests.push [v, v, big_endian ? s : s.reverse]

  # test the maximum value
  v = (1 << (nbytes * 8 - 1)) - 1
  s = "\x7f" + "\xff" * (nbytes - 1)
  tests.push [v, v, big_endian ? s : s.reverse]

  # values above maximum should be clamped to maximum
  tests.push [v+1, v, big_endian ? s : s.reverse]

  tests
end
