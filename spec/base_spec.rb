#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/base'

class BaseStub < BinData::Base
  def clear; end
  def _do_read(io) end
  def done_read; end
  def _do_write(io) end
  def _num_bytes; end
  def snapshot; end
  def single_value?; end
  def field_names; end
end

describe BinData::Base, "with mandatory parameters" do
  before(:all) do
    eval <<-END
      class MandatoryBase < BinData::Base
        mandatory_parameter :p1
      end
    END
  end

  it "should ensure that those parameters are present" do
    lambda { MandatoryBase.new(:p1 => "a") }.should_not raise_error
  end

  it "should fail when those parameters are not present" do
    lambda { MandatoryBase.new(:p2 => "a") }.should raise_error(ArgumentError)
  end
end

describe BinData::Base, "with default parameters" do
  before(:all) do
    eval <<-END
      class DefaultBase < BinData::Base
        default_parameter :p1 => "a"
        public :has_param?, :param
      end
    END
  end

  it "should set default parameters if they are not specified" do
    obj = DefaultBase.new
    obj.should have_param(:p1)
    obj.param(:p1).should == "a"
  end

  it "should be able to override default parameters" do
    obj = DefaultBase.new(:p1 => "b")
    obj.should have_param(:p1)
    obj.param(:p1).should == "b"
  end
end

describe BinData::Base, "with mutually exclusive parameters" do
  before(:all) do
    eval <<-END
      class MutexParamBase < BinData::Base
        optional_parameters :p1, :p2
        mutually_exclusive_parameters :p1, :p2
      end
    END
  end

  it "should not fail when neither of those parameters is present" do
    lambda { MutexParamBase.new }.should_not raise_error
  end

  it "should not fail when only one of those parameters is present" do
    lambda { MutexParamBase.new(:p1 => "a") }.should_not raise_error
    lambda { MutexParamBase.new(:p2 => "a") }.should_not raise_error
  end

  it "should fail when both those parameters are present" do
    lambda { MutexParamBase.new(:p1 => "a", :p2 => "b") }.should raise_error(ArgumentError)
  end
end

describe BinData::Base, "with multiple parameters" do
  before(:all) do
    eval <<-END
      class WithParamBase < BinData::Base
        mandatory_parameter :p1
        optional_parameter  :p2
        default_parameter   :p3 => '3'
        public :has_param?, :eval_param, :param
      end
    END
  end

  it "should not allow parameters with nil values" do
    lambda { WithParamBase.new(:p1 => 1, :p2 => nil) }.should raise_error(ArgumentError)
  end

  it "should identify extra parameters" do
    env = mock("env")
    env.should_receive(:params=).with(:p4 => 4, :p5 => 5)
    env.should_receive(:data_object=)
    obj = WithParamBase.new({:p1 => 1, :p3 => 3, :p4 => 4, :p5 => 5}, env)
  end

  it "should only recall mandatory, default and optional parameters" do
    obj = WithParamBase.new(:p1 => 1, :p3 => 3, :p4 => 4, :p5 => 5)
    obj.should     have_param(:p1)
    obj.should_not have_param(:p2)
    obj.should     have_param(:p3)
    obj.should_not have_param(:p4)
    obj.should_not have_param(:p5)
  end

  it "should evaluate mandatory, default and optional parameters" do
    obj = WithParamBase.new(:p1 => 1, :p3 => lambda {1 + 2}, :p4 => 4, :p5 => 5)
    obj.eval_param(:p1).should == 1
    obj.eval_param(:p2).should be_nil
    obj.eval_param(:p3).should == 3
    obj.eval_param(:p4).should be_nil
    obj.eval_param(:p5).should be_nil
  end

  it "should be able to access without evaluating" do
    obj = WithParamBase.new(:p1 => :asym, :p3 => lambda {1 + 2})
    obj.param(:p1).should == :asym
    obj.param(:p2).should be_nil
    obj.param(:p3).should respond_to(:arity)
  end

  it "should identify accepted parameters" do
    accepted_parameters = WithParamBase.accepted_parameters
    accepted_parameters.should include(:p1)
    accepted_parameters.should include(:p2)
    accepted_parameters.should include(:p3)
    accepted_parameters.should_not include(:p4)
  end
end

describe BinData::Base, "with :check_offset" do
  before(:all) do
    eval <<-END
      class TenByteOffsetBase < BaseStub
        def do_read(io)
          # advance the io position before checking offset
          io.seekbytes(10)
          super(io)
        end
      end
    END
  end

  it "should fail if offset is incorrect" do
    io = StringIO.new("12345678901234567890")
    io.seek(2)
    obj = TenByteOffsetBase.new(:check_offset => 8)
    lambda { obj.read(io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if offset is correct" do
    io = StringIO.new("12345678901234567890")
    io.seek(3)
    obj = TenByteOffsetBase.new(:check_offset => 10)
    lambda { obj.read(io) }.should_not raise_error
  end

  it "should fail if :check_offset fails" do
    io = StringIO.new("12345678901234567890")
    io.seek(4)
    obj = TenByteOffsetBase.new(:check_offset => lambda { offset == 11 } )
    lambda { obj.read(io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if :check_offset succeeds" do
    io = StringIO.new("12345678901234567890")
    io.seek(5)
    obj = TenByteOffsetBase.new(:check_offset => lambda { offset == 10 } )
    lambda { obj.read(io) }.should_not raise_error
  end
end

describe BinData::Base, "with :adjust_offset" do
  before(:all) do
    eval <<-END
      class TenByteAdjustingOffsetBase < BaseStub
        def do_read(io)
          # advance the io position before checking offset
          io.seekbytes(10)
          super(io)
        end
      end
    END
  end

  it "should be mutually exclusive with :check_offset" do
    params = { :check_offset => 8, :adjust_offset => 8 }
    lambda { TenByteAdjustingOffsetBase.new(params) }.should raise_error(ArgumentError)
  end

  it "should adjust if offset is incorrect" do
    io = StringIO.new("12345678901234567890")
    io.seek(2)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => 13)
    obj.read(io)
    io.pos.should == (2 + 13)
  end

  it "should succeed if offset is correct" do
    io = StringIO.new("12345678901234567890")
    io.seek(3)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => 10)
    lambda { obj.read(io) }.should_not raise_error
    io.pos.should == (3 + 10)
  end

  it "should fail if cannot adjust offset" do
    io = StringIO.new("12345678901234567890")
    io.seek(3)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => -4)
    lambda { obj.read(io) }.should raise_error(BinData::ValidityError)
  end
end

describe BinData::Base, "with :readwrite => false" do
  before(:all) do
    eval <<-END
      class NoIOBase < BaseStub
        attr_accessor :mock
        def _do_read(io) mock._do_read(io); end
        def _do_write(io) mock._do_write(io); end
        def _num_bytes; mock._num_bytes; end
      end
    END
  end

  before(:each) do
    @obj = NoIOBase.new :readwrite => false
    @obj.mock = mock('mock')
  end

  it "should not read" do
    io = StringIO.new("12345678901234567890")
    @obj.mock.should_not_receive(:_do_read)
    @obj.read(io)
  end

  it "should not write" do
    io = StringIO.new
    @obj.mock.should_not_receive(:_do_write)
    @obj.write(io)
  end

  it "should have zero num_bytes" do
    @obj.mock.should_not_receive(:_num_bytes)
    @obj.num_bytes.should be_zero
  end
end

describe BinData::Base, "when subclassing" do
  before(:all) do
    eval <<-END
      class SubClassOfBase < BinData::Base
        public :_do_read, :_do_write, :_num_bytes
      end
    END
  end

  before(:each) do
    @obj = SubClassOfBase.new
  end

  it "should raise errors on unimplemented methods" do
    lambda {
      SubClassOfBase.all_possible_field_names(nil)
    }.should raise_error(NotImplementedError)
    lambda { @obj.clear }.should raise_error(NotImplementedError)
    lambda { @obj._do_read(nil) }.should raise_error(NotImplementedError)
    lambda { @obj.done_read }.should raise_error(NotImplementedError)
    lambda { @obj._do_write(nil) }.should raise_error(NotImplementedError)
    lambda { @obj._num_bytes }.should raise_error(NotImplementedError)
    lambda { @obj.snapshot }.should raise_error(NotImplementedError)
    lambda { @obj.single_value? }.should raise_error(NotImplementedError)
    lambda { @obj.field_names }.should raise_error(NotImplementedError)
  end
end

describe BinData::Base, "when subclassing as a single value" do
  before(:all) do
    eval <<-END
      class SingleValueSubClassOfBase < BaseStub
        def single_value?; true; end
        def value; 123; end
      end
    END
  end

  before(:each) do
    @obj = SingleValueSubClassOfBase.new
  end

  it "should return value when reading" do
    SingleValueSubClassOfBase.read("").should == 123
  end
end

describe BinData::Base, "when subclassing as multi values" do
  before(:all) do
    eval <<-END
      class MultiValueSubClassOfBase < BaseStub
        def single_value?; false; end
        def value; 123; end
      end
    END
  end

  it "should return self when reading" do
    obj = MultiValueSubClassOfBase.read("")
    obj.class.should == MultiValueSubClassOfBase
  end
end

describe BinData::Base do
  before(:all) do
    eval <<-END
      class InstanceOfBase < BaseStub
        def snapshot; 123; end
        def _do_write(io); io.writebytes('456'); end
      end
    END
  end

  before(:each) do
    @obj = InstanceOfBase.new
  end

  it "should forward #inspect to snapshot" do
    @obj.inspect.should == 123.inspect
  end

  it "should write the same as to_s" do
    io = StringIO.new
    @obj.write(io)
    io.rewind
    io.read.should == @obj.to_s
  end
end
