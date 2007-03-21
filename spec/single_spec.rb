#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/single'

# An implementation of a unsigned 4 byte integer.
class ConcreteSingle < BinData::Single
  def val_to_str(val)    [val].pack("V") end
  def read_val(io)       readbytes(io, 4).unpack("V")[0] end
  def sensible_default() 0 end

  def in_read?()         @in_read end
end

context "The sample implementation of Single" do
  specify "should have symmetric IO" do
    io = StringIO.new
    data = ConcreteSingle.new
    data.value = 42
    data.write(io)

    io.rewind
    data = ConcreteSingle.new
    data.read(io)
    data.value.should eql(42)
  end
end

context "The class Single" do
  specify "should register subclasses" do
    BinData::Single.lookup(:concrete_single).should eql(ConcreteSingle)
  end

  specify "should read and return a value" do
    io = StringIO.new([123456].pack("V"))
    ConcreteSingle.read(io).should eql(123456)
    data = ConcreteSingle.new
  end
end

context "A Single object" do
  specify "should conform to rule 1 for returning a value" do
    data = ConcreteSingle.new(:value => 5)
    data.should_not be_in_read
    data.value.should eql(5)
  end

  specify "should conform to rule 2 for returning a value" do
    io = StringIO.new([42].pack("V"))
    data = ConcreteSingle.new(:value => 5)
    data.do_read(io)
    data.should be_in_read
    data.value.should eql(42)
  end

  specify "should conform to rule 3 for returning a value" do
    data = ConcreteSingle.new(:initial_value => 5)
    data.should be_clear
    data.value.should eql(5)
  end

  specify "should conform to rule 4 for returning a value" do
    data = ConcreteSingle.new(:initial_value => 5)
    data.value = 17
    data.should_not be_clear
    data.value.should eql(17)
  end

  specify "should conform to rule 5 for returning a value" do
    data = ConcreteSingle.new
    data.should be_clear
    data.value.should eql(0)
  end

  specify "should conform to rule 6 for returning a value" do
    data = ConcreteSingle.new
    data.value = 8
    data.should_not be_clear
    data.value.should eql(8)
  end
end

context "A new Single object" do
  setup do
    @data = ConcreteSingle.new
  end

  specify "should not allow both :initial_value and :value" do
    params = {:initial_value => 1, :value => 2}
    lambda { ConcreteSingle.new(params) }.should raise_error(ArgumentError)
  end

  specify "should have a sensible value" do
    @data.value.should eql(0)
  end

  specify "should allowing setting and retrieving value" do
    @data.value = 5
    @data.value.should eql(5)
  end

  specify "should be clear" do
    @data.should be_clear
  end

  specify "should not be clear after setting value" do
    @data.value = 5
    @data.should_not be_clear
  end

  specify "should not be clear after reading" do
    io = StringIO.new([123456].pack("V"))
    @data.read(io)
    @data.should_not be_clear
  end

  specify "should return num_bytes" do
    @data.num_bytes.should eql(4)
  end

  specify "should not contain any field names" do
    @data.field_names.should be_empty
  end

  specify "should return a snapshot" do
    @data.value = 5
    @data.snapshot.should eql(5)
  end
end

context "A Single with :initial_value" do
  setup do
    @data = ConcreteSingle.new(:initial_value => 5)
  end

  specify "should return that initial value before reading or being set" do
    @data.value.should eql(5)
  end

  specify "should forget :initial_value after being set" do
    @data.value = 17
    @data.value.should_not eql(5)
  end

  specify "should forget :initial_value after reading" do
    io = StringIO.new([56].pack("V"))
    @data.read(io)
    @data.value.should_not eql(5)
  end

  specify "should remember :initial_value after being cleared" do
    @data.value = 17
    @data.clear
    @data.value.should eql(5)
  end
end

context "A Single with :value" do
  setup do
    @data = ConcreteSingle.new(:value => 5)
  end

  specify "should return that :value" do
    @data.value.should eql(5)
  end

  specify "should change during reading" do
    io = StringIO.new([56].pack("V"))
    @data.do_read(io)
    @data.value.should eql(56)
    @data.done_read
  end

  specify "should not change after reading" do
    io = StringIO.new([56].pack("V"))
    @data.read(io)
    @data.value.should eql(5)
  end

  specify "should not be able to change the value" do
    @data.value = 17
    @data.value.should eql(5)
  end
end

context "A Single with :check_value" do
  setup do
    @io = StringIO.new([34].pack("V"))
  end

  specify "should succeed when check_value is non boolean and correct" do
    data = ConcreteSingle.new(:check_value => 34)
    lambda { data.read(@io) }.should_not raise_error
  end

  specify "should fail when check_value is non boolean and incorrect" do
    data = ConcreteSingle.new(:check_value => lambda { 123 * 5 })
    lambda { data.read(@io) }.should raise_error(BinData::ValidityError)
  end

  specify "should succeed when check_value is boolean and true" do
    data = ConcreteSingle.new(:check_value => lambda { (value % 2) == 0})
    lambda { data.read(@io) }.should_not raise_error
  end

  specify "should fail when check_value is boolean and false" do
    data = ConcreteSingle.new(:check_value => lambda { value > 100 })
    lambda { data.read(@io) }.should raise_error(BinData::ValidityError)
  end
end
