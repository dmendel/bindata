#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/base_primitive'
require 'bindata/io'

describe BinData::BasePrimitive, "all subclasses" do
  class SubClassOfBasePrimitive < BinData::BasePrimitive
    expose_methods_for_testing
  end

  subject { SubClassOfBasePrimitive.new }

  it "should raise errors on unimplemented methods" do
    lambda { subject.value_to_binary_string(nil) }.should raise_error(NotImplementedError)
    lambda { subject.read_and_return_value(nil) }.should raise_error(NotImplementedError)
    lambda { subject.sensible_default }.should raise_error(NotImplementedError)
  end
end

describe BinData::BasePrimitive do
  it "should conform to rule 1 for returning a value" do
    data = ExampleSingle.new(:value => 5)
    data.value.should == 5
  end

  it "should conform to rule 2 for returning a value" do
    io = ExampleSingle.io_with_value(42)
    data = ExampleSingle.new(:value => 5)
    data.read(io)

    data.stub(:reading?).and_return(true)
    data.value.should == 42
  end

  it "should conform to rule 3 for returning a value" do
    data = ExampleSingle.new(:initial_value => 5)
    data.should be_clear
    data.value.should == 5
  end

  it "should conform to rule 4 for returning a value" do
    data = ExampleSingle.new(:initial_value => 5)
    data.value = 17
    data.should_not be_clear
    data.value.should == 17
  end

  it "should conform to rule 5 for returning a value" do
    data = ExampleSingle.new
    data.should be_clear
    data.value.should == 0
  end

  it "should conform to rule 6 for returning a value" do
    data = ExampleSingle.new
    data.value = 8
    data.should_not be_clear
    data.value.should == 8
  end
end

describe ExampleSingle do
  subject { ExampleSingle.new(5) }

  it "should fail when assigning nil values" do
    lambda { subject.assign(nil) }.should raise_error(ArgumentError)
  end

  it "should allowing setting and retrieving value" do
    subject.value = 7
    subject.value.should == 7
  end

  it "should allowing setting and retrieving BinData::BasePrimitives" do
    subject.value = ExampleSingle.new(7)
    subject.value.should == 7
  end

  it "should respond to known methods" do
    subject.should respond_to(:num_bytes)
  end

  it "should respond to known methods in #snapshot" do
    subject.should respond_to(:div)
  end

  it "should not respond to unknown methods in self or #snapshot" do
    subject.should_not respond_to(:does_not_exist)
  end

  it "should behave as #snapshot" do
    (subject + 1).should == 6
    (1 + subject).should == 6
  end

  it "should be equal to other ExampleSingle" do
    subject.should == ExampleSingle.new(5)
  end

  it "should be equal to raw values" do
    subject.should == 5
    5.should == subject
  end

  it "should work as hash keys" do
    hash = {5 => 17}

    hash[subject].should == 17
  end
end

describe BinData::BasePrimitive, "after initialisation" do
  subject { ExampleSingle.new }

  it "should not allow both :initial_value and :value" do
    params = {:initial_value => 1, :value => 2}
    lambda { ExampleSingle.new(params) }.should raise_error(ArgumentError)
  end

  it { should be_clear }
  its(:value) { should == 0 }
  its(:num_bytes) { should == 4 }

  it "should have symmetric IO" do
    subject.value = 42
    written = subject.to_binary_s

    ExampleSingle.read(written).should == 42
  end

  it "should allowing setting and retrieving value" do
    subject.value = 5
    subject.value.should == 5
  end

  it "should not be clear after setting value" do
    subject.value = 5
    subject.should_not be_clear
  end

  it "should not be clear after reading" do
    subject.read("\x11\x22\x33\x44")
    subject.should_not be_clear
  end

  it "should return a snapshot" do
    subject.value = 5
    subject.snapshot.should == 5
  end
end

describe BinData::BasePrimitive, "with :initial_value" do
  subject { ExampleSingle.new(:initial_value => 5) }

  its(:value) { should == 5 }

  it "should forget :initial_value after being set" do
    subject.value = 17
    subject.value.should_not == 5
  end

  it "should forget :initial_value after reading" do
    subject.read("\x11\x22\x33\x44")
    subject.value.should_not == 5
  end

  it "should remember :initial_value after being cleared" do
    subject.value = 17
    subject.clear
    subject.value.should == 5
  end
end

describe BinData::BasePrimitive, "with :value" do
  subject { ExampleSingle.new(:value => 5) }

  its(:value) { should == 5 }

  let(:io) { ExampleSingle.io_with_value(56) }

  it "should change during reading" do
    subject.read(io)
    subject.stub(:reading?).and_return(true)
    subject.value.should == 56
  end

  it "should not change after reading" do
    subject.read(io)
    subject.value.should == 5
  end

  it "should not be able to change the value" do
    subject.value = 17
    subject.value.should == 5
  end
end

describe BinData::BasePrimitive, "checking read value" do
  let(:io) { ExampleSingle.io_with_value(12) }

  context ":check_value is non boolean" do
    it "should succeed when check_value and correct" do
      data = ExampleSingle.new(:check_value => 12)
      lambda { data.read(io) }.should_not raise_error
    end

    it "should fail when check_value is incorrect" do
      data = ExampleSingle.new(:check_value => lambda { 99 })
      lambda { data.read(io) }.should raise_error(BinData::ValidityError)
    end
  end

  context ":check_value is boolean" do
    it "should succeed when check_value is true" do
      data = ExampleSingle.new(:check_value => lambda { value < 20 })
      lambda { data.read(io) }.should_not raise_error
    end

    it "should fail when check_value is false" do
      data = ExampleSingle.new(:check_value => lambda { value > 20 })
      lambda { data.read(io) }.should raise_error(BinData::ValidityError)
    end
  end
end
