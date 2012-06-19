#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata/base_primitive'
require 'bindata/io'

describe BinData::BasePrimitive do
  it "is not registered" do
    expect {
      BinData::RegisteredClasses.lookup("BasePrimitive")
    }.to raise_error(BinData::UnRegisteredTypeError)
  end
end

describe BinData::BasePrimitive, "all subclasses" do
  class SubClassOfBasePrimitive < BinData::BasePrimitive
    expose_methods_for_testing
  end

  subject { SubClassOfBasePrimitive.new }

  it "raise errors on unimplemented methods" do
    expect { subject.value_to_binary_string(nil) }.to raise_error(NotImplementedError)
    expect { subject.read_and_return_value(nil) }.to raise_error(NotImplementedError)
    expect { subject.sensible_default }.to raise_error(NotImplementedError)
  end
end

describe BinData::BasePrimitive do
  it "conforms to rule 1 for returning a value" do
    data = ExampleSingle.new(:value => 5)
    data.should == 5
  end

  it "conforms to rule 2 for returning a value" do
    io = ExampleSingle.io_with_value(42)
    data = ExampleSingle.new(:value => 5)
    data.read(io)

    data.stub(:reading?).and_return(true)
    data.should == 42
  end

  it "conforms to rule 3 for returning a value" do
    data = ExampleSingle.new(:initial_value => 5)
    data.should be_clear
    data.should == 5
  end

  it "conforms to rule 4 for returning a value" do
    data = ExampleSingle.new(:initial_value => 5)
    data.assign(17)
    data.should_not be_clear
    data.should == 17
  end

  it "conforms to rule 5 for returning a value" do
    data = ExampleSingle.new
    data.should be_clear
    data.should == 0
  end

  it "conforms to rule 6 for returning a value" do
    data = ExampleSingle.new
    data.assign(8)
    data.should_not be_clear
    data.should == 8
  end
end

describe ExampleSingle do
  subject { ExampleSingle.new(5) }

  it "fails when assigning nil values" do
    expect { subject.assign(nil) }.to raise_error(ArgumentError)
  end

  it "sets and retrieves values" do
    subject.assign(7)
    subject.should == 7
  end

  it "sets and retrieves BinData::BasePrimitives" do
    subject.assign(ExampleSingle.new(7))
    subject.should == 7
  end

  it "responds to known methods" do
    subject.should respond_to(:num_bytes)
  end

  it "responds to known methods in #snapshot" do
    subject.should respond_to(:div)
  end

  it "does not respond to unknown methods in self or #snapshot" do
    subject.should_not respond_to(:does_not_exist)
  end

  it "behaves as #snapshot" do
    (subject + 1).should == 6
    (1 + subject).should == 6
  end

  it "is equal to other ExampleSingle" do
    subject.should == ExampleSingle.new(5)
  end

  it "is equal to raw values" do
    subject.should == 5
    5.should == subject
  end

  it "can be used as a hash key" do
    hash = {5 => 17}

    hash[subject].should == 17
  end

  it "is sortable" do
    [ExampleSingle.new(5), ExampleSingle.new(3)].sort.should == [3, 5]
  end
end

describe BinData::BasePrimitive, "after initialisation" do
  subject { ExampleSingle.new }

  it "does not allow both :initial_value and :value" do
    params = {:initial_value => 1, :value => 2}
    expect { ExampleSingle.new(params) }.to raise_error(ArgumentError)
  end

  it { should be_clear }
  its(:value) { should == 0 }
  its(:num_bytes) { should == 4 }

  it "has symmetric IO" do
    subject.assign(42)
    written = subject.to_binary_s

    ExampleSingle.read(written).should == 42
  end

  it "sets and retrieves values" do
    subject.value = 5
    subject.value.should == 5
  end

  it "is not clear after setting value" do
    subject.assign(5)
    subject.should_not be_clear
  end

  it "is not clear after reading" do
    subject.read("\x11\x22\x33\x44")
    subject.should_not be_clear
  end

  it "returns a snapshot" do
    subject.assign(5)
    subject.snapshot.should == 5
  end
end

describe BinData::BasePrimitive, "with :initial_value" do
  subject { ExampleSingle.new(:initial_value => 5) }

  its(:value) { should == 5 }

  it "forgets :initial_value after being set" do
    subject.assign(17)
    subject.should_not == 5
  end

  it "forgets :initial_value after reading" do
    subject.read("\x11\x22\x33\x44")
    subject.should_not == 5
  end

  it "remembers :initial_value after being cleared" do
    subject.assign(17)
    subject.clear
    subject.should == 5
  end
end

describe BinData::BasePrimitive, "with :value" do
  subject { ExampleSingle.new(:value => 5) }

  its(:value) { should == 5 }

  let(:io) { ExampleSingle.io_with_value(56) }

  it "changes during reading" do
    subject.read(io)
    subject.stub(:reading?).and_return(true)
    subject.should == 56
  end

  it "does not change after reading" do
    subject.read(io)
    subject.should == 5
  end

  it "is unaffected by assigning" do
    subject.assign(17)
    subject.should == 5
  end
end

describe BinData::BasePrimitive, "checking read value" do
  let(:io) { ExampleSingle.io_with_value(12) }

  context ":check_value is non boolean" do
    it "succeeds when check_value is correct" do
      data = ExampleSingle.new(:check_value => 12)
      expect { data.read(io) }.not_to raise_error
    end

    it "fails when check_value is incorrect" do
      data = ExampleSingle.new(:check_value => lambda { 99 })
      expect { data.read(io) }.to raise_error(BinData::ValidityError)
    end
  end

  context ":check_value is boolean" do
    it "succeeds when check_value is true" do
      data = ExampleSingle.new(:check_value => lambda { value < 20 })
      expect { data.read(io) }.not_to raise_error
    end

    it "fails when check_value is false" do
      data = ExampleSingle.new(:check_value => lambda { value > 20 })
      expect { data.read(io) }.to raise_error(BinData::ValidityError)
    end
  end
end
