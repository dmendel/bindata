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

  it "raises errors on unimplemented methods" do
    expect { subject.clear         }.to raise_error(NotImplementedError)
    expect { subject.clear?        }.to raise_error(NotImplementedError)
    expect { subject.assign(nil)   }.to raise_error(NotImplementedError)
    expect { subject.snapshot      }.to raise_error(NotImplementedError)
    expect { subject.do_read(nil)  }.to raise_error(NotImplementedError)
    expect { subject.do_write(nil) }.to raise_error(NotImplementedError)
    expect { subject.do_num_bytes  }.to raise_error(NotImplementedError)
  end
end

describe BinData::Base, "with parameters" do
  it "raises error when parameter name is invalid" do
    expect {
      class InvalidParameterNameBase < BinData::Base
        optional_parameter :eval # i.e. Kernel#eval
      end
    }.to raise_error(NameError)
  end

  it "raises an error when parameter has nil value" do
    expect { BaseStub.new(:a => nil) }.to raise_error(ArgumentError)
  end

  it "converts parameter keys to symbols" do
    subject = BaseStub.new('a' => 3)
    subject.should have_parameter(:a)
  end
end

describe BinData::Base, "with mandatory parameters" do
  class MandatoryBase < BaseStub
    mandatory_parameter :p1
    mandatory_parameter :p2
  end

  it "ensures that all mandatory parameters are present" do
    params = {:p1 => "a", :p2 => "b" }
    expect { MandatoryBase.new(params) }.not_to raise_error
  end

  it "fails when only some mandatory parameters are present" do
    params = {:p1 => "a", :xx => "b" }
    expect { MandatoryBase.new(params) }.to raise_error(ArgumentError)
  end

  it "fails when no mandatory parameters are present" do
    expect { MandatoryBase.new() }.to raise_error(ArgumentError)
  end
end

describe BinData::Base, "with default parameters" do
  class DefaultBase < BaseStub
    default_parameter :p1 => "a"
  end

  it "uses default parameters when not specified" do
    subject = DefaultBase.new
    subject.eval_parameter(:p1).should == "a"
  end

  it "can override default parameters" do
    subject = DefaultBase.new(:p1 => "b")
    subject.eval_parameter(:p1).should == "b"
  end
end

describe BinData::Base, "with mutually exclusive parameters" do
  class MutexParamBase < BaseStub
    optional_parameters :p1, :p2
    mutually_exclusive_parameters :p1, :p2
  end

  it "does not fail when neither of those parameters are present" do
    expect { MutexParamBase.new }.not_to raise_error
  end

  it "does not fail when only one of those parameters is present" do
    expect { MutexParamBase.new(:p1 => "a") }.not_to raise_error
    expect { MutexParamBase.new(:p2 => "b") }.not_to raise_error
  end

  it "fails when both those parameters are present" do
    expect { MutexParamBase.new(:p1 => "a", :p2 => "b") }.to raise_error(ArgumentError)
  end
end

describe BinData::Base, "with multiple parameters" do
  class WithParamBase < BaseStub
    mandatory_parameter :p1
    default_parameter   :p2 => 2
    optional_parameter  :p3
  end

  it "identifies internally accepted parameters" do
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

    it "evaluates parameters" do
      subject.eval_parameter(:p1).should == 1
      subject.eval_parameter(:p2).should == 2
      expect { subject.eval_parameter(:p3) }.to raise_error(NoMethodError)
      subject.eval_parameter(:p4).should == 4
    end

    it "gets parameters without evaluating" do
      subject.get_parameter(:p1).should == 1
      subject.get_parameter(:p2).should == 2
      subject.get_parameter(:p3).should == :xx
      subject.get_parameter(:p4).should respond_to(:arity)
    end

    it "has parameters" do
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

  it "calls both #initialize_xxx methods" do
    BaseInit.recorded_calls {
      BaseInit.new
    }.should == [:initialize_shared_instance, :initialize_instance]
  end

  context "as a factory" do
    subject { BaseInit.new(:check_offset => 1) }

    describe "#new" do
      it "calls #initialize_instance" do
        obj = subject

        BaseInit.recorded_calls {
          obj.new
        }.should == [:initialize_instance]
      end

      it "copies parameters" do
        obj = subject.new
        obj.eval_parameter(:check_offset).should == 1
      end

      it "performs action for :check_offset" do
        obj = subject.new
        expect {
          obj.read("abc")
        }.to raise_error(BinData::ValidityError)
      end

      it "assigns value" do
        obj = subject.new(3)
        obj.snapshot.should == 3
      end

      it "sets parent" do
        obj = subject.new(3, "p")
        obj.parent.should == "p"
      end
    end
  end
end

describe BinData::Base, "as black box" do
  context "class methods" do
    it "returns bindata_name" do
      BaseStub.bindata_name.should == "base_stub"
    end

    it "instantiates self for ::read" do
      BaseStub.read("").class.should == BaseStub
    end
  end

  it "accesses parent" do
    parent = BaseStub.new
    child = BaseStub.new(nil, parent)
    child.parent.should == parent
  end

  subject { BaseStub.new }

  it "returns self for #read" do
    subject.read("").should == subject
  end

  it "returns self for #write" do
    subject.write("").should == subject
  end

  it "forwards #inspect to snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    subject.inspect.should == subject.snapshot.inspect
  end

  it "forwards #to_s to snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    subject.to_s.should == subject.snapshot.to_s
  end

  it "pretty prints object as snapshot" do
    subject.stub(:snapshot).and_return([1, 2, 3])
    actual_io = StringIO.new
    expected_io = StringIO.new

    require 'pp'
    PP.pp(subject, actual_io)
    PP.pp(subject.snapshot, expected_io)

    actual_io.value.should == expected_io.value
  end

  it "writes the same as to_binary_s" do
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

  it "forwards read to do_read" do
    subject.should_receive(:clear).ordered
    subject.should_receive(:do_read).ordered
    subject.read(nil)
  end

  it "forwards write to do_write" do
    subject.should_receive(:do_write)
    subject.write(nil)
  end

  it "forwards num_bytes to do_num_bytes" do
    subject.should_receive(:do_num_bytes).and_return(42)
    subject.num_bytes.should == 42
  end

  it "rounds up fractional num_bytes" do
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
    it "fails when offset is incorrect" do
      io.seek(2)
      subject = TenByteOffsetBase.create(:check_offset => 8)
      expect { subject.read(io) }.to raise_error(BinData::ValidityError)
    end

    it "succeeds when offset is correct" do
      io.seek(3)
      subject = TenByteOffsetBase.create(:check_offset => 10)
      expect { subject.read(io) }.not_to raise_error
    end

    it "fails when :check_offset fails" do
      io.seek(4)
      subject = TenByteOffsetBase.create(:check_offset => lambda { offset == 11 } )
      expect { subject.read(io) }.to raise_error(BinData::ValidityError)
    end

    it "succeeds when :check_offset succeeds" do
      io.seek(5)
      subject = TenByteOffsetBase.create(:check_offset => lambda { offset == 10 } )
      expect { subject.read(io) }.not_to raise_error
    end
  end

  context "with :adjust_offset" do
    it "is mutually exclusive with :check_offset" do
      params = { :check_offset => 8, :adjust_offset => 8 }
      expect { TenByteOffsetBase.create(params) }.to raise_error(ArgumentError)
    end

    it "adjust offset when incorrect" do
      io.seek(2)
      subject = TenByteOffsetBase.create(:adjust_offset => 13)
      subject.read(io)
      io.pos.should == (2 + 13)
    end

    it "succeeds when offset is correct" do
      io.seek(3)
      subject = TenByteOffsetBase.create(:adjust_offset => 10)
      expect { subject.read(io) }.not_to raise_error
      io.pos.should == (3 + 10)
    end

    it "fails if cannot adjust offset" do
      io.seek(4)
      subject = TenByteOffsetBase.create(:adjust_offset => -5)
      expect { subject.read(io) }.to raise_error(BinData::ValidityError)
    end
  end
end
