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
