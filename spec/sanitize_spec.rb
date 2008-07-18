#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/sanitize'
require 'bindata/int'

describe BinData::Sanitizer, "class methods" do
  it "should resolve type with endian" do
    BinData::Sanitizer.type_exists?(:int16, :little).should be_true
  end

  it "should return if type exists" do
    BinData::Sanitizer.type_exists?(:int8).should be_true
  end

  it "should raise if type doesn't exist" do
    BinData::Sanitizer.type_exists?(:does_not_exist).should be_false
  end

  it "should lookup types" do
    BinData::Sanitizer.lookup(:int16, :little).should == BinData::Int16le
  end

end

describe BinData::Sanitizer do
  before(:each) do
    @sanitizer = BinData::Sanitizer.new
  end

  it "should raise error on unknown types" do
    lambda {
      @sanitizer.sanitize(:does_not_exist, {})
    }.should raise_error(TypeError)
  end

  it "should lookup when endian is set" do
    @sanitizer.with_endian(:little) do
      klass, params = @sanitizer.sanitize(:int16, {})
      klass.should == BinData::Int16le
    end
  end

  it "should nest with_endian calls" do
    @sanitizer.with_endian(:little) do
      klass, params = @sanitizer.sanitize(:int16, {})
      klass.should == BinData::Int16le

      @sanitizer.with_endian(:big) do
        klass, params = @sanitizer.sanitize(:int16, {})
        klass.should == BinData::Int16be
      end

      klass, params = @sanitizer.sanitize(:int16, {})
      klass.should == BinData::Int16le
    end
  end

  it "should sanitize parameters" do
    klass, params = @sanitizer.sanitize(:int8, {:value => 3})
    klass.should == BinData::Int8
    params.should have_key(:value)
  end
end

describe BinData::SanitizedParameters, "with bad input" do
  before(:each) do
    @mock = mock("dummy class")
    @mock.stub!(:accepted_parameters).and_return([:a, :b, :c])
    @params = {:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}
  end

  it "should convert keys to symbols" do
    the_params = {'a' => 1, 'b' => 2, 'e' => 5}
    sanitized = BinData::SanitizedParameters.new(@mock, the_params)
    sanitized.accepted_parameters.should == ({:a => 1, :b => 2})
    sanitized.extra_parameters.should == ({:e => 5})
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
    @mock.stub!(:accepted_parameters).and_return([:a, :b, :c])
    @params = {:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}
  end

  it "should partition" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.accepted_parameters.should == ({:a => 1, :b => 2, :c => 3})
    sanitized.extra_parameters.should == ({:d => 4, :e => 5})
  end

  it "should respond_to keys" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:keys)
    keys = sanitized.keys.collect { |x| x.to_s }
    keys.sort.should ==(['a', 'b', 'c', 'd', 'e'])
  end

  it "should respond_to has_key?" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:has_key?)
    sanitized.has_key?(:a).should be_true
    sanitized.has_key?(:e).should be_true
    sanitized.has_key?(:z).should be_false
  end

  it "should respond_to []" do
    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:[])
    sanitized[:a].should == 1
    sanitized[:d].should == 4
  end
end
