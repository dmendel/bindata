#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata'

describe BinData::SingleValue, "when defining" do
  it "should fail when inheriting from deprecated SingleValue" do
    lambda {
      class SubclassSingleValue < BinData::SingleValue
      end
    }.should raise_error
  end
end

describe BinData::MultiValue, "when defining" do
  it "should fail inheriting from deprecated MultiValue" do
    lambda {
      class SubclassMultiValue < BinData::MultiValue
      end
    }.should raise_error
  end
end

describe BinData::Base, "when defining" do
  it "should fail if #initialize is overridden" do
    class BaseWithInitialize < BinData::Base
      def initialize(params = {}, parent = nil)
        super
      end
    end

    lambda {
      BaseWithInitialize.new
    }.should raise_error
  end

  it "should handle if #initialize is naively renamed to #initialize_instance" do
    class BaseWithInitializeInstance < BinData::Base
      def initialize_instance(params = {}, parent = nil)
        super
      end
    end

    lambda {
      BaseWithInitializeInstance.new
    }.should_not raise_error
  end

  it "should handle deprecated #register_self method" do
    lambda {
      class DeprecatedRegisterSelfBase < BinData::Base
        register_self
      end
    }.should_not raise_error
  end

  it "should handle deprecated #register method" do
    lambda {
      class DeprecatedRegisterBase < BinData::Base
        register(self.name, self)
      end
    }.should_not raise_error
  end

  it "should handle deprecated #register method for subclasses" do
    lambda {
      class DeprecatedSuperBase < BinData::Base
        def self.inherited(subclass)
          register(subclass.name, subclass)                                                                                                                                      
        end                                                                                                                                                                      
      end

      class DeprecatedSubBase < DeprecatedSuperBase
      end
    }.should_not raise_error
  end

  it "should handle deprecated #register method with custom calling" do
    lambda {
      class DeprecatedCustomBase < BinData::Base
        register(name, Object)
      end
    }.should_not raise_error
  end
end

describe BinData::Base do
  class DeprecatedBase < BinData::Base
  end

  subject { DeprecatedBase.new }
  let(:io)  { "abcde" }

  it "should forward _do_read to do_read" do
    subject.should_receive(:do_read).with(io)
    subject._do_read(io)
  end

  it "should forward _do_write to do_write" do
    subject.should_receive(:do_write).with(io)
    subject._do_write(io)
  end

  it "should forward _do_num_bytes to do_num_bytes" do
    subject.should_receive(:do_num_bytes)
    subject._do_num_bytes
  end

  it "should forward _assign to assign" do
    val = 3
    subject.should_receive(:assign).with(val)
    subject._assign(val)
  end

  it "should forward _snapshot to snapshot" do
    subject.should_receive(:snapshot)
    subject._snapshot
  end
end
