#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Skip, "when instantiating" do
  describe "with no mandatory parameters supplied" do
    it "raises an error" do
      args = {}
      _ { BinData::Skip.new(args) }.must_raise ArgumentError
    end
  end
end

describe BinData::Skip, "with :length" do
  let(:obj) { BinData::Skip.new(length: 5) }
  let(:io) { StringIO.new("abcdefghij") }

  it "initial state" do
    _(obj).must_equal ""
    _(obj.to_binary_s).must_equal_binary "\000" * 5
  end

  it "skips bytes" do
    obj.read(io)
    _(io.pos).must_equal 5
  end

  it "has expected binary representation after setting value" do
    obj.assign("123")
    _(obj.to_binary_s).must_equal_binary "\000" * 5
  end

  it "has expected binary representation after reading" do
    obj.read(io)
    _(obj.to_binary_s).must_equal_binary "\000" * 5
  end
end

describe BinData::Skip, "with :to_abs_offset" do
  BinData::Struct.new(fields: [ [:skip, :f, { to_abs_offset: 5 } ] ])

  let(:skip_obj) { [:skip, :f, { to_abs_offset: 5 } ] }
  let(:io) { StringIO.new("abcdefghij") }

  it "reads skipping forward" do
    fields = [ skip_obj ]
    obj = BinData::Struct.new(fields: fields)
    obj.read(io)
    _(io.pos).must_equal 5
  end

  it "reads skipping in place" do
    fields = [ [:string, :a, { read_length: 5 }], skip_obj ]
    obj = BinData::Struct.new(fields: fields)
    obj.read(io)
    _(io.pos).must_equal 5
  end

  it "does not read skipping backwards" do
    fields = [ [:string, :a, { read_length: 10 }], skip_obj ]
    obj = BinData::Struct.new(fields: fields)

    _ {
      obj.read(io)
    }.must_raise ArgumentError
  end

  it "writes skipping forward" do
    fields = [ skip_obj ]
    obj = BinData::Struct.new(fields: fields)
    _(obj.to_binary_s).must_equal "\000\000\000\000\000"
  end

  it "reads skipping in place" do
    fields = [ [:string, :a, { value: "abcde" }], skip_obj ]
    obj = BinData::Struct.new(fields: fields)
    _(obj.to_binary_s).must_equal "abcde"
  end

  it "does not write skipping backwards" do
    fields = [ [:string, :a, { value: "abcdefghij" }], skip_obj ]
    obj = BinData::Struct.new(fields: fields)
    _ {
      obj.to_binary_s
    }.must_raise ArgumentError
  end
end

describe BinData::Skip, "with :until_valid" do
  let(:io) { StringIO.new("abcdefghij") }

  it "doesn't skip when writing" do
    skip_obj = [:string, { read_length: 1, assert: "f" }]
    args = { until_valid: skip_obj }
    obj = BinData::Skip.new(args)
    _(obj.to_binary_s).must_equal ""
  end

  it "skips to valid match" do
    skip_obj = [:string, { read_length: 1, assert: "f" }]
    fields = [ [:skip, :s, { until_valid: skip_obj }] ]
    obj = BinData::Struct.new(fields: fields)
    obj.read(io)
    _(io.pos).must_equal 5
  end

  it "won't skip on unseekable stream" do
    rd, wr = IO::pipe
    unseekable_io = BinData::IO::Read.new(rd)
    wr.write io
    wr.close

    skip_obj = [:string, { read_length: 1, assert: "f" }]
    fields = [ [:skip, :s, { until_valid: skip_obj }] ]
    obj = BinData::Struct.new(fields: fields)
    _ {obj.read(unseekable_io)}.must_raise IOError
    rd.close
  end

  it "doesn't skip when validator doesn't assert" do
    skip_obj = [:string, { read_length: 1 }]
    fields = [ [:skip, :s, { until_valid: skip_obj }] ]
    obj = BinData::Struct.new(fields: fields)
    obj.read(io)
    _(io.pos).must_equal 0
  end

  it "raises IOError when no match" do
    skip_obj = [:string, { read_length: 1, assert: "X" }]
    fields = [ [:skip, :s, { until_valid: skip_obj }] ]
    obj = BinData::Struct.new(fields: fields)
    _ {
      obj.read(io)
    }.must_raise IOError
  end

  it "raises IOError when validator reads beyond stream" do
    skip_obj = [:string, { read_length: 30 }]
    fields = [ [:skip, :s, { until_valid: skip_obj }] ]
    obj = BinData::Struct.new(fields: fields)
    _ {
      obj.read(io)
    }.must_raise IOError
  end

  it "uses block form" do
    class DSLSkip < BinData::Record
      skip :s do
        string read_length: 1, assert: "f"
      end
      string :a, read_length: 1
    end

    obj = DSLSkip.read(io)
    _(obj.a).must_equal "f"
  end
end

describe BinData::Skip, "with :until_valid" do
  class SkipSearch < BinData::Record
    skip :s do
      uint8
      uint8 asserted_value: 1
      uint8 :a
      uint8 :b
      virtual assert: -> { a == b }
    end
    array :data, type: :uint8, initial_length: 4
  end

  let(:io) { BinData::IO.create_string_io("\x0f" * 10 + "\x00\x01\x02\x03\x00" + "\x02\x01\x03\x03" + "\x06") }

  it "finds valid match" do
    obj = SkipSearch.read(io)
    _(obj.data).must_equal [2, 1, 3, 3]
  end

  it "match is at expected offset" do
    obj = SkipSearch.read(io)
    _(obj.data.rel_offset).must_equal 15
  end
end
