#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Skip do
  let(:obj) { BinData::Skip.new(:length => 5) }
  let(:io) { StringIO.new("abcdefghij") }

  it "initial state" do
    obj.must_equal ""
    obj.to_binary_s.must_equal_binary "\000" * 5
  end

  it "skips bytes" do
    obj.read(io)
    io.pos.must_equal 5
  end

  it "has expected binary representation after setting value" do
    obj.assign("123")
    obj.to_binary_s.must_equal_binary "\000" * 5
  end

  it "has expected binary representation after reading" do
    obj.read(io)
    obj.to_binary_s.must_equal_binary "\000" * 5
  end
end
