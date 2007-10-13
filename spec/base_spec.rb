#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/base'

describe "A data object with mandatory option" do
  before(:all) do
    eval <<-END
      class Mandatory < BinData::Base
        mandatory_parameter :p1
      end
    END
  end
  it "should ensure that those options are present" do
    lambda { Mandatory.new(:p1 => "a") }.should_not raise_error
  end

  it "should fail when those options are not present" do
    lambda { Mandatory.new(:p2 => "a") }.should raise_error(ArgumentError)
  end
end

describe "A data object with mutually exclusive options" do
  before(:all) do
    eval <<-END
      class MutexParam < BinData::Base
        optional_parameters :p1, :p2
        def initialize(params = {}, env = nil)
          super(params, env)
          ensure_mutual_exclusion(:p1, :p2)
        end
      end
    END
  end

  it "should not fail when neither of those options is present" do
    lambda { MutexParam.new }.should_not raise_error
  end

  it "should not fail when only one of those options is present" do
    lambda { MutexParam.new(:p1 => "a") }.should_not raise_error
    lambda { MutexParam.new(:p2 => "a") }.should_not raise_error
  end

  it "should fail when both those options are present" do
    lambda { MutexParam.new(:p1 => "a", :p2 => "b") }.should raise_error(ArgumentError)
  end
end

describe "A data object with parameters" do
  before(:all) do
    eval <<-END
      class WithParam < BinData::Base
        mandatory_parameter :p1
        optional_parameters :p2, :p3
        public :has_param?, :eval_param, :param
      end
    END
  end

  it "should not allow nil parameters" do
    lambda { WithParam.new(:p1 => 1, :p2 => nil) }.should raise_error(ArgumentError)
  end

  it "should identify extra parameters" do
    env = mock("env")
    env.should_receive(:params=).with(:p4 => 4, :p5 => 5)
    env.should_receive(:data_object=)
    obj = WithParam.new({:p1 => 1, :p3 => 3, :p4 => 4, :p5 => 5}, env)
  end

  it "should only recall mandatory and optional parameters" do
    obj = WithParam.new(:p1 => 1, :p3 => 3, :p4 => 4, :p5 => 5)
    obj.should     have_param(:p1)
    obj.should_not have_param(:p2)
    obj.should     have_param(:p3)
    obj.should_not have_param(:p4)
    obj.should_not have_param(:p5)
  end

  it "should evaluate mandatory and optional parameters" do
    obj = WithParam.new(:p1 => 1, :p3 => lambda {1 + 2}, :p4 => 4, :p5 => 5)
    obj.eval_param(:p1).should eql(1)
    obj.eval_param(:p2).should be_nil
    obj.eval_param(:p3).should eql(3)
    obj.eval_param(:p4).should be_nil
    obj.eval_param(:p5).should be_nil
  end

  it "should be able to access without evaluating" do
    obj = WithParam.new(:p1 => :asym, :p3 => lambda {1 + 2})
    obj.param(:p1).should eql(:asym)
    obj.param(:p2).should be_nil
    obj.param(:p3).should respond_to(:arity)
  end

  it "should identify unsupplied parameters" do
    obj = WithParam.new(:p1 => 1, :p3 => 3, :p4 => 4, :p5 => 5)
    obj.unsupplied_parameters.should include(:p2)
    obj.unsupplied_parameters.should_not include(:p1)
    obj.unsupplied_parameters.should_not include(:p3)
    obj.unsupplied_parameters.should_not include(:p4)
  end
end

describe "A data object with :check_offset" do
  before(:all) do
    eval <<-END
      class TenByteOffset < BinData::Base
        def do_read(io)
          # advance the io position before checking offset
          io.seek(10, IO::SEEK_CUR)
          super(io)
        end
        def _do_read(io) end
        def done_read; end
        def clear; end
      end
    END
  end

  it "should fail if offset is incorrect" do
    io = StringIO.new("12345678901234567890")
    io.seek(2)
    obj = TenByteOffset.new(:check_offset => 8)
    lambda { obj.read(io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if offset is correct" do
    io = StringIO.new("12345678901234567890")
    io.seek(3)
    obj = TenByteOffset.new(:check_offset => 10)
    lambda { obj.read(io) }.should_not raise_error
  end

  it "should fail if :check_offset fails" do
    io = StringIO.new("12345678901234567890")
    io.seek(4)
    obj = TenByteOffset.new(:check_offset => lambda { offset == 11 } )
    lambda { obj.read(io) }.should raise_error(BinData::ValidityError)
  end

  it "should succeed if :check_offset succeeds" do
    io = StringIO.new("12345678901234567890")
    io.seek(5)
    obj = TenByteOffset.new(:check_offset => lambda { offset == 10 } )
    lambda { obj.read(io) }.should_not raise_error
  end
end

describe "A data object with :readwrite => false" do
  before(:all) do
    eval <<-END
      class NoIO < BinData::Base
        def _do_read(io)
          @_do_read = true
        end
        def _write(io)
          @_do_write = true
        end
        def _num_bytes
          5
        end
        def done_read; end
        def clear; end
        attr_reader :_do_read, :_do_write
      end
    END
    @obj = NoIO.new :readwrite => false
  end

  it "should not read" do
    io = StringIO.new("12345678901234567890")
    @obj.read(io)
    @obj._do_read.should_not eql(true)
  end

  it "should not write" do
    io = StringIO.new
    @obj.write(io)
    @obj._do_write.should_not eql(true)
  end

  it "should have zero num_bytes" do
    @obj.num_bytes.should eql(0)
  end
end

describe "A data object defining a value method" do
  before(:all) do
    eval <<-END
      class SingleValueObject < BinData::Base
        def value; end
      end
    END
  end

  it "should be a single value object" do
    obj = SingleValueObject.new
    obj.should be_a_single_value
  end
end
