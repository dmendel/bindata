#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/float'

context "A FloatLe" do
  setup do
    @obj = BinData::FloatLe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  specify "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('e')
  end

  specify "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000001)
  end
end

context "A FloatBe" do
  setup do
    @obj = BinData::FloatBe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  specify "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('g')
  end

  specify "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000001)
  end
end

context "A DoubleLe" do
  setup do
    @obj = BinData::DoubleLe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  specify "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('E')
  end

  specify "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000000000000000001)
  end
end


context "A DoubleBe" do
  setup do
    @obj = BinData::DoubleBe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  specify "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('G')
  end

  specify "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000000000000000001)
  end
end
