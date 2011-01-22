#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata/base'

class BaseStub < BinData::Base
  # Override to avoid NotImplemented errors
  def clear; end
  def clear?; end
  def assign(x); @data = x; end
  def snapshot; @data; end
  def do_read(io) end
  def do_write(io) end
  def do_num_bytes; end
end

describe BinData::Base, "all subclasses" do
  class SubClassOfBase < BinData::Base
    expose_methods_for_testing
  end

  subject { SubClassOfBase.new }

  it "should raise errors on unimplemented methods" do
    lambda { subject.clear         }.should raise_error(NotImplementedError)
    lambda { subject.clear?        }.should raise_error(NotImplementedError)
    lambda { subject.assign(nil)   }.should raise_error(NotImplementedError)
    lambda { subject.snapshot      }.should raise_error(NotImplementedError)
    lambda { subject.do_read(nil)  }.should raise_error(NotImplementedError)
    lambda { subject.do_write(nil) }.should raise_error(NotImplementedError)
    lambda { subject.do_num_bytes  }.should raise_error(NotImplementedError)
  end
end

describe BinData::Base, "with parameters" do
  it "should raise error if parameter name is invalid" do
    lambda {
      class InvalidParameterNameBase < BinData::Base
        optional_parameter :eval # i.e. Kernel#eval
      end
    }.should raise_error(NameError)
  end

  it "should raise error if parameter has nil value" do
    lambda { BaseStub.new(:a => nil) }.should raise_error(ArgumentError)
  end

  it "should convert parameter keys to symbols" do
    subject = BaseStub.new('a' => 3)
    subject.should have_parameter(:a)
  end
end

describe BinData::Base, "with mandatory parameters" do
  class MandatoryBase < BaseStub
    mandatory_parameter :p1
    mandatory_parameter :p2
  end

  it "should ensure that all mandatory parameters are present" do
    params = {:p1 => "a", :p2 => "b" }
    lambda { MandatoryBase.new(params) }.should_not raise_error
  end

  it "should fail if not all mandatory parameters are present" do
    params = {:p1 => "a", :xx => "b" }
    lambda { MandatoryBase.new(params) }.should raise_error(ArgumentError)
  end

  it "should fail if no mandatory parameters are present" do
    lambda { MandatoryBase.new() }.should raise_error(ArgumentError)
  end
end

describe BinData::Base, "with default parameters" do
  class DefaultBase < BaseStub
    default_parameter :p1 => "a"
  end

  it "should use default parameters when not specified" do
    subject = DefaultBase.new
    subject.eval_parameter(:p1).should == "a"
  end

  it "should be able to override default parameters" do
    subject = DefaultBase.new(:p1 => "b")
    subject.eval_parameter(:p1).should == "b"
  end
end

describe BinData::Base, "with mutually exclusive parameters" do
  class MutexParamBase < BaseStub
    optional_parameters :p1, :p2
    mutually_exclusive_parameters :p1, :p2
  end

  it "should not fail when neither of those parameters are present" do
    lambda { MutexParamBase.new }.should_not raise_error
  end

  it "should not fail when only one of those parameters is present" do
    lambda { MutexParamBase.new(:p1 => "a") }.should_not raise_error
    lambda { MutexParamBase.new(:p2 => "b") }.should_not raise_error
  end

  it "should fail when both those parameters are present" do
    lambda { MutexParamBase.new(:p1 => "a", :p2 => "b") }.should raise_error(ArgumentError)
  end
end

describe BinData::Base, "with multiple parameters" do
  class WithParamBase < BaseStub
    mandatory_parameter :p1
    default_parameter   :p2 => 2
    optional_parameter  :p3
  end

  it "should identify internally accepted parameters" do
    accepted = WithParamBase.accepted_parameters.all
    accepted.should include(:p1)
    accepted.should include(:p2)
    accepted.should include(:p3)
    accepted.should_not include(:xx)
  end

  context "examining parameters" do
    subject {
      params = {:p1 => 1, :p3 => :xx, :p4 => lambda { 4 }}
      WithParamBase.new(params)
    }

    it "should evaluate parameters" do
      subject.eval_parameter(:p1).should == 1
      subject.eval_parameter(:p2).should == 2
      lambda { subject.eval_parameter(:p3) }.should raise_error(NoMethodError)
      subject.eval_parameter(:p4).should == 4
    end

    it "should get parameters without evaluating" do
      subject.get_parameter(:p1).should == 1
      subject.get_parameter(:p2).should == 2
      subject.get_parameter(:p3).should == :xx
      subject.get_parameter(:p4).should respond_to(:arity)
    end

    it "should have parameters" do
      subject.should have_parameter(:p1)
      subject.should have_parameter(:p2)
      subject.should have_parameter(:p3)
      subject.should have_parameter(:p4)
    end
  end
end

describe BinData::Base, "when initializing" do
  class BaseInit < BaseStub
    class << self
      attr_accessor :calls
      def recorded_calls(&block)
        self.calls = []
        block.call
        calls
      end
    end

    def initialize_instance
      self.class.calls << :initialize_instance
    end

    def initialize_shared_instance
      self.class.calls << :initialize_shared_instance
    end
  end

  it "should call both #initialize_xxx methods when initializing" do
    BaseInit.recorded_calls {
      BaseInit.new
    }.should == [:initialize_shared_instance, :initialize_instance]
  end

  context "as a factory" do
    subject { BaseInit.new(:check_offset => 1) }

    describe "#new" do
      it "should call #initialize_instance" do
        obj = subject

        BaseInit.recorded_calls {
          obj.new
        }.should == [:initialize_instance]
      end

      it "should copy parameters" do
        obj = subject.new
        obj.eval_parameter(:check_offset).should == 1
      end

      it "should perform action for :check_offset" do
        obj = subject.new
        lambda {
          obj.read("abc")
        }.should raise_error(BinData::ValidityError)
      end

      it "should assign value" do
        obj = subject.new(3)
        obj.snapshot.should == 3
      end

      it "should set parent" do
        obj = subject.new(3, "p")
        obj.parent.should == "p"
      end
    end
  end
end

describe BinData::Base, "as a factory" do
end

describe BinData::Base, "as black box" do
  context "class methods" do
    it "should return bindata_name" do
      BaseStub.bindata_name.should == "base_stub"
    end

    it "should instantiate self for ::read" do
      BaseStub.read("").class.should == BaseStub
    end
  end

  it "should access parent" do
    parent = BaseStub.new
    child = BaseStub.new(nil, parent)
    child.parent.should == parent
  end

  subject { BaseStub.new }

  it "should return self for #read" do
    subject.read("").should == subject
  end

  it "should return self for #write" do
    subject.write("").should == subject
  end

  it "should forward #inspect to snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    subject.inspect.should == subject.snapshot.inspect
  end

  it "should forward #to_s to snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    subject.to_s.should == subject.snapshot.to_s
  end

  it "should pretty print object as snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    actual_io = StringIO.new
    expected_io = StringIO.new

    require 'pp'
    PP.pp(subject, actual_io)
    PP.pp(subject.snapshot, expected_io)

    actual_io.value.should == expected_io.value
  end

  it "should write the same as to_binary_s" do
    class WriteToSBase < BaseStub
      def do_write(io) io.writebytes("abc"); end
    end

    subject = WriteToSBase.new
    io = StringIO.new
    subject.write(io)
    io.value.should == subject.to_binary_s
  end
end

describe BinData::Base, "as white box" do
  subject { BaseStub.new }

  it "should forward read to do_read" do
    subject.should_receive(:clear).ordered
    subject.should_receive(:do_read).ordered
    subject.read(nil)
  end

  it "should forward write to do_write" do
    subject.should_receive(:do_write)
    subject.write(nil)
  end

  it "should forward num_bytes to do_num_bytes" do
    subject.should_receive(:do_num_bytes).and_return(42)
    subject.num_bytes.should == 42
  end

  it "should round up fractional num_bytes" do
    subject.should_receive(:do_num_bytes).and_return(42.1)
    subject.num_bytes.should == 43
  end
end

describe BinData::Base, "checking offsets" do
  class TenByteOffsetBase < BaseStub
    def self.create(params)
      obj = self.new
      obj.initialize_child(params)
      obj
    end

    def initialize_child(params)
      @child = BaseStub.new(params, self)
    end

    def do_read(io)
      io.seekbytes(10)
      @child.do_read(io)
    end
  end

  let(:io) { StringIO.new("12345678901234567890") }

  context "with :check_offset" do
    it "should fail if offset is incorrect" do
      io.seek(2)
      subject = TenByteOffsetBase.create(:check_offset => 8)
      lambda { subject.read(io) }.should raise_error(BinData::ValidityError)
    end

    it "should succeed if offset is correct" do
      io.seek(3)
      subject = TenByteOffsetBase.create(:check_offset => 10)
      lambda { subject.read(io) }.should_not raise_error
    end

    it "should fail if :check_offset fails" do
      io.seek(4)
      subject = TenByteOffsetBase.create(:check_offset => lambda { offset == 11 } )
      lambda { subject.read(io) }.should raise_error(BinData::ValidityError)
    end

    it "should succeed if :check_offset succeeds" do
      io.seek(5)
      subject = TenByteOffsetBase.create(:check_offset => lambda { offset == 10 } )
      lambda { subject.read(io) }.should_not raise_error
    end
  end

  context "with :adjust_offset" do
    it "should be mutually exclusive with :check_offset" do
      params = { :check_offset => 8, :adjust_offset => 8 }
      lambda { TenByteOffsetBase.create(params) }.should raise_error(ArgumentError)
    end

    it "should adjust if offset is incorrect" do
      io.seek(2)
      subject = TenByteOffsetBase.create(:adjust_offset => 13)
      subject.read(io)
      io.pos.should == (2 + 13)
    end

    it "should succeed if offset is correct" do
      io.seek(3)
      subject = TenByteOffsetBase.create(:adjust_offset => 10)
      lambda { subject.read(io) }.should_not raise_error
      io.pos.should == (3 + 10)
    end

    it "should fail if cannot adjust offset" do
      io.seek(4)
      subject = TenByteOffsetBase.create(:adjust_offset => -5)
      lambda { subject.read(io) }.should raise_error(BinData::ValidityError)
    end
  end
end
