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

  before(:each) do
    @obj = DeprecatedBase.new
    @io = "abcde"
  end

  it "should forward _do_read to do_read" do
    @obj.should_receive(:do_read).with(@io)
    @obj._do_read(@io)
  end

  it "should forward _do_write to do_write" do
    @obj.should_receive(:do_write).with(@io)
    @obj._do_write(@io)
  end

  it "should forward _do_num_bytes to do_num_bytes" do
    @obj.should_receive(:do_num_bytes)
    @obj._do_num_bytes
  end

  it "should forward _assign to assign" do
    val = 3
    @obj.should_receive(:assign).with(val)
    @obj._assign(val)
  end

  it "should forward _snapshot to snapshot" do
    @obj.should_receive(:snapshot)
    @obj._snapshot
  end
end
