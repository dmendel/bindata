#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/base'

class BaseStub < BinData::Base
  # Override to avoid NotImplemented errors
  def clear; end
  def clear?; end
  def single_value?; end
  def _do_read(io) end
  def _done_read; end
  def _do_write(io) end
  def _do_num_bytes(x) end
  def _snapshot; end

  expose_methods_for_testing
end

class MockBaseStub < BaseStub
  attr_accessor :mock
  def clear;           mock.clear; end
  def clear?;          mock.clear?; end
  def single_value?;   mock.single_value?; end
  def _do_read(io)     mock._do_read(io); end
  def _done_read;      mock._done_read; end
  def _do_write(io)    mock._do_write(io); end
  def _do_num_bytes(x) mock._do_num_bytes(x) end
  def _snapshot;       mock._snapshot; end
end

describe BinData::Base, "when subclassing" do
  before(:all) do
    eval <<-END
      class SubClassOfBase < BinData::Base
        expose_methods_for_testing
      end
    END
  end

  before(:each) do
    @obj = SubClassOfBase.new
  end

  it "should raise errors on unimplemented methods" do
    lambda { @obj.clear }.should raise_error(NotImplementedError)
    lambda { @obj.clear? }.should raise_error(NotImplementedError)
    lambda { @obj.single_value? }.should raise_error(NotImplementedError)
    lambda { @obj._do_read(nil) }.should raise_error(NotImplementedError)
    lambda { @obj._done_read }.should raise_error(NotImplementedError)
    lambda { @obj._do_write(nil) }.should raise_error(NotImplementedError)
    lambda { @obj._do_num_bytes(nil) }.should raise_error(NotImplementedError)
    lambda { @obj._snapshot }.should raise_error(NotImplementedError)
  end
end

describe BinData::Base, "with mandatory parameters" do
  before(:all) do
    eval <<-END
      class MandatoryBase < BaseStub
        bindata_mandatory_parameter :p1
        bindata_mandatory_parameter :p2
      end
    END
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
  before(:all) do
    eval <<-END
      class DefaultBase < BaseStub
        bindata_default_parameter :p1 => "a"
      end
    END
  end

  it "should use default parameters when not specified" do
    obj = DefaultBase.new
    obj.should have_param(:p1)
    obj.eval_param(:p1).should == "a"
  end

  it "should be able to override default parameters" do
    obj = DefaultBase.new(:p1 => "b")
    obj.should have_param(:p1)
    obj.eval_param(:p1).should == "b"
  end
end

describe BinData::Base, "with mutually exclusive parameters" do
  before(:all) do
    eval <<-END
      class MutexParamBase < BaseStub
        bindata_optional_parameters :p1, :p2
        bindata_mutually_exclusive_parameters :p1, :p2
      end
    END
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
  before(:all) do
    eval <<-END
      class WithParamBase < BaseStub
        bindata_mandatory_parameter :p1
        bindata_optional_parameter  :p2
        bindata_default_parameter   :p3 => 3
      end
    END
  end

  it "should identify internally accepted parameters" do
    accepted = WithParamBase.accepted_internal_parameters
    accepted.should include(:p1)
    accepted.should include(:p2)
    accepted.should include(:p3)
    accepted.should_not include(:xx)
  end

  it "should identify custom parameters" do
    params = {:p1 => 1, :p2 => 2, :p3 => 3, :p4 => 4, :p5 => 5}
    obj = WithParamBase.new(params)
    obj.custom_parameters.should == {:p4 => 4, :p5 => 5}
  end

  it "should not allow parameters with nil values" do
    lambda { WithParamBase.new(:p1 => 1, :p2 => nil) }.should raise_error(ArgumentError)
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
    obj.no_eval_param(:p1).should == :asym
    obj.no_eval_param(:p2).should be_nil
    obj.no_eval_param(:p3).should respond_to(:arity)
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

  before(:each) do
    @io = StringIO.new("12345678901234567890")
  end

  it "should fail if offset is incorrect" do
    @io.seek(2)
    obj = TenByteOffsetBase.new(:check_offset => 8)
    lambda { obj.read(@io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if offset is correct" do
    @io.seek(3)
    obj = TenByteOffsetBase.new(:check_offset => 10)
    lambda { obj.read(@io) }.should_not raise_error
  end

  it "should fail if :check_offset fails" do
    @io.seek(4)
    obj = TenByteOffsetBase.new(:check_offset => lambda { offset == 11 } )
    lambda { obj.read(@io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if :check_offset succeeds" do
    @io.seek(5)
    obj = TenByteOffsetBase.new(:check_offset => lambda { offset == 10 } )
    lambda { obj.read(@io) }.should_not raise_error
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

  before(:each) do
    @io = StringIO.new("12345678901234567890")
  end

  it "should be mutually exclusive with :check_offset" do
    params = { :check_offset => 8, :adjust_offset => 8 }
    lambda { TenByteAdjustingOffsetBase.new(params) }.should raise_error(ArgumentError)
  end

  it "should adjust if offset is incorrect" do
    @io.seek(2)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => 13)
    obj.read(@io)
    @io.pos.should == (2 + 13)
  end

  it "should succeed if offset is correct" do
    @io.seek(3)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => 10)
    lambda { obj.read(@io) }.should_not raise_error
    @io.pos.should == (3 + 10)
  end

  it "should fail if cannot adjust offset" do
    @io.seek(3)
    obj = TenByteAdjustingOffsetBase.new(:adjust_offset => -4)
    lambda { obj.read(@io) }.should raise_error(BinData::ValidityError)
  end
end

describe BinData::Base, "with :onlyif => false" do
  before(:each) do
    @obj = MockBaseStub.new(:onlyif => false)
    @obj.mock = mock('mock')
  end

  it "should not read" do
    io = StringIO.new("12345678901234567890")
    @obj.mock.should_not_receive(:clear)
    @obj.mock.should_not_receive(:_do_read)
    @obj.mock.should_not_receive(:_done_read)
    @obj.read(io)
  end

  it "should not write" do
    io = StringIO.new
    @obj.mock.should_not_receive(:_do_write)
    @obj.write(io)
  end

  it "should have zero num_bytes" do
    @obj.mock.should_not_receive(:_do_num_bytes)
    @obj.num_bytes.should be_zero
  end

  it "should have nil snapshot" do
    @obj.mock.should_not_receive(:_snapshot)
    @obj.snapshot.should be_nil
  end
end

describe BinData::Base, "as a single value" do
  before(:all) do
    eval <<-END
      class SingleValueSubClassOfBase < BaseStub
        def single_value?;  true  ; end

        def value;          "123" ; end
      end
    END
  end

  it "should return value when reading" do
    obj = SingleValueSubClassOfBase.new
    SingleValueSubClassOfBase.read(nil).should == obj.value
  end
end

describe BinData::Base, "as multi value" do
  before(:all) do
    eval <<-END
      class MultiValueSubClassOfBase < BaseStub
        def single_value?; false; end
      end
    END
  end

  it "should return self when reading" do
    obj = MultiValueSubClassOfBase.read(nil)
    obj.class.should == MultiValueSubClassOfBase
  end
end

describe BinData::Base, "as black box" do
  it "should access parent" do
    parent = BaseStub.new
    child = BaseStub.new(nil, parent)
    child.parent.should == parent
  end

  it "should return self for #read" do
    obj = BaseStub.new
    obj.read("").should == obj
  end

  it "should return self for #write" do
    obj = BaseStub.new
    obj.write("").should == obj
  end

  it "should forward #inspect to snapshot" do
    class SnapshotBase < BaseStub
      def snapshot; [1, 2, 3]; end
    end
    obj = SnapshotBase.new
    obj.inspect.should == obj.snapshot.inspect
  end

  it "should write the same as to_s" do
    class WriteToSBase < BaseStub
      def _do_write(io) io.writebytes("abc"); end
    end

    obj = WriteToSBase.new
    io = StringIO.new
    obj.write(io)
    io.rewind
    written = io.read
    obj.to_s.should == written
  end
end

describe BinData::Base, "as white box" do
  before(:each) do
    @obj = MockBaseStub.new
    @obj.mock = mock('mock')
  end

  it "should forward read to _do_read" do
    @obj.mock.should_receive(:clear).ordered
    @obj.mock.should_receive(:_do_read).ordered
    @obj.mock.should_receive(:_done_read).ordered
    @obj.read(nil)
  end

  it "should forward write to _do_write" do
    @obj.mock.should_receive(:_do_write)
    @obj.write(nil)
  end

  it "should forward num_bytes to _do_num_bytes" do
    @obj.mock.should_receive(:_do_num_bytes).and_return(42)
    @obj.num_bytes.should == 42
  end

  it "should round up fractional num_bytes" do
    @obj.mock.should_receive(:_do_num_bytes).and_return(42.1)
    @obj.num_bytes.should == 43
  end

  it "should forward snapshot to _snapshot" do
    @obj.mock.should_receive(:_snapshot).and_return("abc")
    @obj.snapshot.should == "abc"
  end
end
