#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Virtual do
  let(:stream) { StringIO.new "abcdefghij" }

  it "must not read from any stream" do
    BinData::Virtual.read(stream)
    _(stream.pos).must_equal 0
  end

  it "must not write to a stream" do
    obj = BinData::Virtual.new
    _(obj.to_binary_s).must_equal_binary ""
  end

  it "occupies no space" do
    obj = BinData::Virtual.new
    _(obj.num_bytes).must_equal 0
  end

  it "asserts on #read" do
    data = []
    obj = BinData::Virtual.new(assert: -> { data << 1; true })

    obj.read ""
    _(data).must_equal [1]
  end

  it "asserts on #assign" do
    data = []
    obj = BinData::Virtual.new(assert: -> { data << 1; true })

    obj.assign("foo")
    _(data).must_equal [1]
  end

  it "assigns a value" do
    obj = BinData::Virtual.new(3)
    _(obj).must_equal 3
  end

  it "accepts the :value parameter" do
    obj = BinData::Virtual.new(value: 3)
    _(obj).must_equal 3
  end
end
