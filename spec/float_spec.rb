#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/float'

describe "A FloatLe" do
  before(:each) do
    @obj = BinData::FloatLe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  it "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('e')
  end

  it "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000001)
  end
end

describe "A FloatBe" do
  before(:each) do
    @obj = BinData::FloatBe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  it "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('g')
  end

  it "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000001)
  end
end

describe "A DoubleLe" do
  before(:each) do
    @obj = BinData::DoubleLe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  it "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('E')
  end

  it "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000000000000000001)
  end
end


describe "A DoubleBe" do
  before(:each) do
    @obj = BinData::DoubleBe.new
    @obj.value = Math::PI

    @io = StringIO.new
  end

  it "should write the expected value" do
    @obj.write(@io)
    @io.rewind

    @io.read.should == [Math::PI].pack('G')
  end

  it "should read the same value as written" do
    @obj.write(@io)
    @io.rewind

    # check that we read in the same data that was written
    @obj.read(@io)
    @obj.value.should be_close(Math::PI, 0.000000000000000001)
  end
end
