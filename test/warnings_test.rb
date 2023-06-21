#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Base, "when defining" do
  it "fails if #initialize is overridden" do
    class BaseWithInitialize < BinData::Base
      def initialize(params = {}, parent = nil)
        super
      end
    end

    _ {
      BaseWithInitialize.new
    }.must_raise RuntimeError
  end

  it "fails if #initialize is overridden on BasePrimitive" do
    class BasePrimitiveWithInitialize < BinData::String
      def initialize(params = {}, parent = nil)
        super
      end
    end

    _ {
      BasePrimitiveWithInitialize.new
    }.must_raise RuntimeError
  end

  it "handles if #initialize is naively renamed to #initialize_instance" do
    class BaseWithInitializeInstance < BinData::Base
      def initialize_instance(params = {}, parent = nil)
        super
      end
    end

    _ {
      BaseWithInitializeInstance.new
    }.must_raise RuntimeError
  end
end
