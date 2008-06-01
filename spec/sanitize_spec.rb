#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/sanitize'

describe BinData::SanitizedParameters, "with nil parameters" do
  before(:each) do
    @mock = mock("dummy class")
    @mock.stub!(:accepted_parameters).and_return([:a, :b, :c])
  end

  it "should return empty parameters" do
    @mock.should_receive(:sanitize_parameters).with({}).and_return({})

    sanitized = BinData::SanitizedParameters.new(@mock, nil)
    sanitized.keys.should be_empty
  end

  it "should pass extra arguments" do
    @mock.should_receive(:sanitize_parameters).with({}, 1, 2, 3).and_return({})

    sanitized = BinData::SanitizedParameters.new(@mock, nil, 1, 2, 3)
    sanitized.keys.should be_empty
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
    @mock.should_receive(:sanitize_parameters).with(the_params).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, the_params)
    sanitized.accepted_parameters.should == ({:a => 1, :b => 2})
    sanitized.extra_parameters.should == ({:e => 5})
  end

  it "should raise error if parameter has nil value" do
    the_params = {'a' => 1, 'b' => nil, 'e' => 5}
    @mock.should_receive(:sanitize_parameters).with(the_params).
      and_return { |params, *rest| params }

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

  it "should pass extra arguments" do
    @mock.should_receive(:sanitize_parameters).with(@params, 1, 2, 3).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, @params, 1, 2, 3)
  end

  it "should partition" do
    @mock.should_receive(:sanitize_parameters).with(@params).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.accepted_parameters.should == ({:a => 1, :b => 2, :c => 3})
    sanitized.extra_parameters.should == ({:d => 4, :e => 5})
  end

  it "should respond_to keys" do
    @mock.should_receive(:sanitize_parameters).with(@params).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:keys)
    keys = sanitized.keys.collect { |x| x.to_s }
    keys.sort.should ==(['a', 'b', 'c', 'd', 'e'])
  end

  it "should respond_to has_key?" do
    @mock.should_receive(:sanitize_parameters).with(@params).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:has_key?)
    sanitized.has_key?(:a).should be_true
    sanitized.has_key?(:e).should be_true
    sanitized.has_key?(:z).should be_false
  end

  it "should respond_to []" do
    @mock.should_receive(:sanitize_parameters).with(@params).
      and_return { |params, *rest| params }

    sanitized = BinData::SanitizedParameters.new(@mock, @params)
    sanitized.should respond_to(:[])
    sanitized[:a].should == 1
    sanitized[:d].should == 4
  end
end
