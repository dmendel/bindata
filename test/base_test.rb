#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe "BinData::Base", "framework" do
  class FrameworkBase < BinData::Base
    class << self
      attr_accessor :calls
      def record_calls(&block)
        self.calls = []
        block.call
      end
    end

    def initialize_instance
      self.class.calls << :initialize_instance
    end

    def initialize_shared_instance
      self.class.calls << :initialize_shared_instance
    end

    expose_methods_for_testing
  end

  let(:obj) do
    FrameworkBase.record_calls { FrameworkBase.new }
  end

  it "raises errors on unimplemented methods" do
    _ { obj.clear?        }.must_raise NotImplementedError
    _ { obj.assign(nil)   }.must_raise NotImplementedError
    _ { obj.snapshot      }.must_raise NotImplementedError
    _ { obj.do_read(nil)  }.must_raise NotImplementedError
    _ { obj.do_write(nil) }.must_raise NotImplementedError
    _ { obj.do_num_bytes  }.must_raise NotImplementedError
  end

  it "calls initialize methods in order" do
    FrameworkBase.record_calls { FrameworkBase.new }
    _(FrameworkBase.calls).must_equal [:initialize_shared_instance, :initialize_instance]
  end

  it "does not call #initialize_shared_instance for prototypes" do
    prototype = obj
    FrameworkBase.record_calls { prototype.new }
    _(FrameworkBase.calls).must_equal [:initialize_instance]
  end
end

describe BinData::Base, "ArgExtractor" do
  class ParamParserBase < BinData::Base
    attr_reader :params
    attr_reader :val

    def assign(v)
      @val = v
    end
  end

  it "parses parameters" do
    par = BinData::Base.new
    data = [
      [[3             ],  3,   [],   nil],
      [[3,         par],  3,   [],   par],
      [[   {a: 1}     ],  nil, [:a], nil],
      [[   {a: 1}, par],  nil, [:a], par],
      [[3, {a: 1}     ],  3,   [:a], nil],
      [[3, {a: 1}, par],  3,   [:a], par],
    ]

    data.each do |el|
      args, val, param_keys, parent = *el
      obj = ParamParserBase.new(*args)

      if val
        _(obj.val).must_be_same_as val
      else
        _(obj.val).must_be_nil
      end

      _(obj.params.keys).must_equal param_keys

      if parent
        _(obj.parent).must_be_same_as parent
      else
        _(obj.parent).must_be_nil
      end
    end
  end
end

describe BinData::Base do
  class BaseStub < BinData::Base
    # Override to avoid NotImplemented errors
    def clear?; end
    def assign(x); end
    def snapshot; end
    def do_read(io) end
    def do_write(io) end
    def do_num_bytes; end
  end

  let(:obj) { BaseStub.new }

  it "::bindata_name returns lowercased name" do
    _(BaseStub.bindata_name).must_equal "base_stub"
  end

  it "::read instantiates self" do
    _(BaseStub.read("")).must_be_instance_of BaseStub
  end

  it "#read returns self" do
    _(obj.read("")).must_equal obj
  end

  it "#write returns self" do
    _(obj.write("")).must_equal obj
  end

  it "#to_hex uses #to_binary_s representation" do
    def obj.to_binary_s; "\x01\xab\xCD"; end

    _(obj.to_hex).must_equal "01abcd"
  end

  it "#inspect is forwarded to snapshot" do
    def obj.snapshot; [1, 2, 3]; end

    _(obj.inspect).must_equal obj.snapshot.inspect
  end

  it "#to_s is forwarded to snapshot" do
    def obj.snapshot; [1, 2, 3]; end

    _(obj.to_s).must_equal obj.snapshot.to_s
  end

  it "pretty prints object as snapshot" do
    actual_io = StringIO.new
    expected_io = StringIO.new

    def obj.snapshot; [1, 2, 3]; end

    require 'pp'
    PP.pp(obj, actual_io)
    PP.pp(obj.snapshot, expected_io)

    _(actual_io.value).must_equal expected_io.value
  end

  it "#write writes the same as #to_binary_s" do
    class WriteToSBase < BaseStub
      def do_write(io) io.writebytes("abc"); end
    end

    obj = WriteToSBase.new
    io = StringIO.new
    obj.write(io)
    _(io.value).must_equal obj.to_binary_s
  end

  it "#read is forwarded to #do_read" do
    calls = []
    called_clear = lambda { |*a| calls << :clear }
    called_do_read = lambda { |*a| calls << :do_read }

    obj.define_singleton_method(:clear, called_clear)
    obj.define_singleton_method(:do_read, called_do_read)

    obj.read(nil)

    _(calls).must_equal [:clear, :do_read]
  end

  it "#write is forwarded to #do_write" do
    calls = []
    called_do_write = lambda { |*a| calls << :do_write }

    obj.define_singleton_method(:do_write, called_do_write)

    obj.write(nil)

    _(calls).must_equal [:do_write]
  end

  it "#num_bytes is forwarded to #do_num_bytes" do
    def obj.do_num_bytes; 42; end

    _(obj.num_bytes).must_equal 42
  end

  it "#num_bytes rounds up fractional values" do
    def obj.do_num_bytes; 42.1; end

    _(obj.num_bytes).must_equal 43
  end
end
