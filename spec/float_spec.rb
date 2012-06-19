#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/float'

describe "A FloatLe" do
  subject { BinData::FloatLe.new(Math::PI) }

  its(:num_bytes)               { should == 4 }
  its(:to_binary_s)             { should == [Math::PI].pack('e') }
  its(:value_read_from_written) { should be_within(0.000001).of(Math::PI) }
end

describe "A FloatBe" do
  subject { BinData::FloatBe.new(Math::PI) }

  its(:num_bytes)               { should == 4 }
  its(:to_binary_s)             { should == [Math::PI].pack('g') }
  its(:value_read_from_written) { should be_within(0.000001).of(Math::PI) }
end

describe "A DoubleLe" do
  subject { BinData::DoubleLe.new(Math::PI) }

  its(:num_bytes)               { should == 8 }
  its(:to_binary_s)             { should == [Math::PI].pack('E') }
  its(:value_read_from_written) { should be_within(0.0000000000000001).of(Math::PI) }
end


describe "A DoubleBe" do
  subject { BinData::DoubleBe.new(Math::PI) }

  its(:num_bytes)               { should == 8 }
  its(:to_binary_s)             { should == [Math::PI].pack('G') }
  its(:value_read_from_written) { should be_within(0.0000000000000001).of(Math::PI) }
end
