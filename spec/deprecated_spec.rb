#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata'

describe BinData::Base, "when defining" do
  it "fails if #initialize is overridden" do
    class BaseWithInitialize < BinData::Base
      def initialize(params = {}, parent = nil)
        super
      end
    end

    expect {
      BaseWithInitialize.new
    }.to raise_error
  end

  it "handles if #initialize is naively renamed to #initialize_instance" do
    class BaseWithInitializeInstance < BinData::Base
      def initialize_instance(params = {}, parent = nil)
        super
      end
    end

    expect {
      BaseWithInitializeInstance.new
    }.to raise_error
  end
end
