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
