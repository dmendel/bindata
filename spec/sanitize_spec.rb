#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/sanitize'
require 'bindata/int'

describe BinData::SanitizedParameters, "with bad input" do
  before(:each) do
    @mock = mock("dummy class")
    @mock.stub!(:accepted_internal_parameters).and_return([:a, :b, :c])
    @params = {:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}
  end

  it "should convert keys to symbols" do
    the_params = {'a' => 1, 'b' => 2, 'e' => 5}
    sanitized = BinData::SanitizedParameters.new(@mock, the_params)
    sanitized.parameters.should == {:a => 1, :b => 2, :e => 5}
  end

  it "should raise error if parameter has nil value" do
    the_params = {'a' => 1, 'b' => nil, 'e' => 5}
    lambda {
      BinData::SanitizedParameters.new(@mock, the_params)
    }.should raise_error(ArgumentError)
  end
end

describe BinData::SanitizedParameters do
  before(:each) do
    @mock = mock("dummy class")
    @mock.stub!(:accepted_internal_parameters).and_return([:a, :b, :c])
    @params = {:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}
  end

  it "should respond_to keys" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:keys)
    keys = sanitized.keys.collect { |k| k.to_s }
    keys.sort.should == ['a', 'b', 'c', 'd', 'e']
  end

  it "should respond_to has_key?" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:has_key?)
    sanitized.should have_key(:a)
    sanitized.should have_key(:e)
    sanitized.should_not have_key(:z)
  end

  it "should respond_to []" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:[])
    sanitized[:a].should == 1
    sanitized[:d].should == 4
  end
end

describe BinData::Sanitizer do
  before(:each) do
    @sanitizer = BinData::Sanitizer.new
  end

  it "should raise error on unknown types" do
    lambda {
      @sanitizer.lookup_class(:does_not_exist)
    }.should raise_error(TypeError)
  end

  it "should lookup when endian is set" do
    @sanitizer.with_endian(:little) do
      the_class = @sanitizer.lookup_class(:int16)
      the_class.should == BinData::Int16le
    end
  end

  it "should nest with_endian calls" do
    @sanitizer.with_endian(:little) do
      the_class = @sanitizer.lookup_class(:int16)
      the_class.should == BinData::Int16le

      @sanitizer.with_endian(:big) do
        the_class = @sanitizer.lookup_class(:int16)
        the_class.should == BinData::Int16be
      end

      the_class = @sanitizer.lookup_class(:int16)
      the_class.should == BinData::Int16le
    end
  end

  it "should sanitize parameters" do
    params = @sanitizer.sanitized_params(BinData::Int8, {:value => 3})
    params.should have_key(:value)
  end
end
