#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::CountBytesRemaining do
  let(:obj) { BinData::CountBytesRemaining.new }

  it "initial state" do
    _(obj).must_equal 0
    _(obj.num_bytes).must_equal 0
  end

  it "counts till end of stream" do
    data = "abcdefghij"
    _(obj.read(data)).must_equal 10
  end

  it "does not read any data" do
    io = StringIO.new "abcdefghij"
    obj.read(io)

    _(io.pos).must_equal 0
  end

  it "does not write any data" do
    _(obj.to_binary_s).must_equal_binary ""
  end

  it "allows setting value for completeness" do
    obj.assign("123")
    _(obj).must_equal "123"
    _(obj.to_binary_s).must_equal_binary ""
  end

  it "accepts BinData::BasePrimitive parameters" do
    count = BinData::CountBytesRemaining.new(assert: 2)
    _ {
      count.read("xyz")
    }.must_raise BinData::ValidityError
  end
end
