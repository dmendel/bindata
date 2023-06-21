#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Stringz, "when empty" do
  let(:obj) { BinData::Stringz.new }

  it "initial state" do
    _(obj.value).must_equal ""
    _(obj.num_bytes).must_equal 1
    _(obj.to_binary_s).must_equal_binary "\0"
  end
end

describe BinData::Stringz, "with value set" do
  let(:obj) { BinData::Stringz.new("abcd") }

  it "initial state" do
    _(obj.value).must_equal "abcd"
    _(obj.num_bytes).must_equal 5
    _(obj.to_binary_s).must_equal_binary "abcd\0"
  end
end

describe BinData::Stringz, "when reading" do
  let(:obj) { BinData::Stringz.new }

  it "stops at the first zero byte" do
    io = StringIO.new("abcd\0xyz\0")
    obj.read(io)
    _(io.pos).must_equal 5
    _(obj).must_equal "abcd"
  end

  it "handles a zero length string" do
    io = StringIO.new("\0abcd")
    obj.read(io)
    _(io.pos).must_equal 1
    _(obj).must_equal ""
  end

  it "fails if no zero byte is found" do
    _ {obj.read("abcd") }.must_raise EOFError
  end
end

describe BinData::Stringz, "when setting the value" do
  let(:obj) { BinData::Stringz.new }

  it "includes the zero byte in num_bytes total" do
    obj.assign("abcd")
    _(obj.num_bytes).must_equal 5
  end

  it "accepts empty strings" do
    obj.assign("")
    _(obj).must_equal ""
  end

  it "accepts strings that aren't zero terminated" do
    obj.assign("abcd")
    _(obj).must_equal "abcd"
  end

  it "accepts strings that are zero terminated" do
    obj.assign("abcd\0")
    _(obj).must_equal "abcd"
  end

  it "accepts up to the first zero byte" do
    obj.assign("abcd\0xyz\0")
    _(obj).must_equal "abcd"
  end
end

describe BinData::Stringz, "with max_length" do
  let(:obj) { BinData::Stringz.new(max_length: 5) }

  it "fails if max_length is less that 1" do
    obj = BinData::Stringz.new(max_length: 0)

    _{ obj.read "abc\0" }.must_raise ArgumentError
    _{ obj.to_binary_s }.must_raise ArgumentError
    _{ obj.num_bytes }.must_raise ArgumentError
  end

  it "reads less than max_length" do
    io = StringIO.new("abc\0xyz")
    obj.read(io)
    _(obj).must_equal "abc"
  end

  it "reads exactly max_length" do
    io = StringIO.new("abcd\0xyz")
    obj.read(io)
    _(obj).must_equal "abcd"
  end

  it "reads no more than max_length" do
    io = StringIO.new("abcdefg\0xyz")
    obj.read(io)
    _(io.pos).must_equal 5
    _(obj).must_equal "abcd"
  end

  it "accepts values less than max_length" do
    obj.assign("abc")
    _(obj).must_equal "abc"
  end

  it "accepts values exactly max_length" do
    obj.assign("abcd")
    _(obj).must_equal "abcd"
  end

  it "trims values greater than max_length" do
    obj.assign("abcdefg")
    _(obj).must_equal "abcd"
  end

  it "writes values greater than max_length" do
    obj.assign("abcdefg")
    _(obj.to_binary_s).must_equal_binary "abcd\0"
  end

  it "writes values less than max_length" do
    obj.assign("abc")
    _(obj.to_binary_s).must_equal_binary "abc\0"
  end

  it "writes values exactly max_length" do
    obj.assign("abcd")
    _(obj.to_binary_s).must_equal_binary "abcd\0"
  end
end
