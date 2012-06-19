#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata'

describe BinData::SingleValue, "when defining" do
  it "fails when inheriting from deprecated SingleValue" do
    expect {
      class SubclassSingleValue < BinData::SingleValue
      end
    }.to raise_error
  end
end

describe BinData::MultiValue, "when defining" do
  it "fails inheriting from deprecated MultiValue" do
    expect {
      class SubclassMultiValue < BinData::MultiValue
      end
    }.to raise_error
  end
end

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
    }.not_to raise_error
  end

  it "handles deprecated #register_self method" do
    expect {
      class DeprecatedRegisterSelfBase < BinData::Base
        register_self
      end
    }.not_to raise_error
  end

  it "handles deprecated #register method" do
    expect {
      class DeprecatedRegisterBase < BinData::Base
        register(self.name, self)
      end
    }.not_to raise_error
  end

  it "handles deprecated #register method for subclasses" do
    expect {
      class DeprecatedSuperBase < BinData::Base
        def self.inherited(subclass)
          register(subclass.name, subclass)                                                                                                                                      
        end                                                                                                                                                                      
      end

      class DeprecatedSubBase < DeprecatedSuperBase
      end
    }.not_to raise_error
  end

  it "handles deprecated #register method with custom calling" do
    expect {
      class DeprecatedCustomBase < BinData::Base
        register(name, Object)
      end
    }.not_to raise_error
  end
end

describe BinData::Base do
  class DeprecatedBase < BinData::Base
  end

  subject { DeprecatedBase.new }
  let(:io)  { "abcde" }

  it "forwards _do_read to do_read" do
    subject.should_receive(:do_read).with(io)
    subject._do_read(io)
  end

  it "forwards _do_write to do_write" do
    subject.should_receive(:do_write).with(io)
    subject._do_write(io)
  end

  it "forwards _do_num_bytes to do_num_bytes" do
    subject.should_receive(:do_num_bytes)
    subject._do_num_bytes
  end

  it "forwards _assign to assign" do
    val = 3
    subject.should_receive(:assign).with(val)
    subject._assign(val)
  end

  it "forwards _snapshot to snapshot" do
    subject.should_receive(:snapshot)
    subject._snapshot
  end
end
