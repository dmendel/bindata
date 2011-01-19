#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/skip'

describe BinData::Skip do
  subject { BinData::Skip.new(:length => 5) }
  let(:io) { StringIO.new("abcdefghij") }

  it { should == "" }
  its(:to_binary_s) { should == "\000" * 5 }

  it "should skip bytes" do
    subject.read(io)
    io.pos.should == 5
  end

  it "should have expected binary representation after setting value" do
    subject.value = "123"
    subject.to_binary_s.should == "\000" * 5
  end

  it "should have expected binary representation after reading" do
    subject.read(io)
    subject.to_binary_s.should == "\000" * 5
  end
end
