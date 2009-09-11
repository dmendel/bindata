#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

def capture_exception(exception_type, &block)
  block.call
rescue Exception => err
  err.class.should == exception_type
  return err
else
  lambda {}.should raise_error(exception_type)
end

describe BinData::Record, "when defining" do
  it "should fail on non registered types" do
    err = capture_exception(TypeError) {
      class BadTypeRecord < BinData::Record
        non_registered_type :a
      end
    }
    err.message.should == "unknown type 'non_registered_type' for #{BadTypeRecord}"
  end

  it "should give correct error message for non registered nested types" do
    err = capture_exception(TypeError) {
      class BadNestedTypeRecord < BinData::Record
        array :a, :type => :non_registered_type
      end
    }
    err.message.should == "unknown type 'non_registered_type' for #{BadNestedTypeRecord}"
  end

  it "should fail on duplicate names" do
    err = capture_exception(SyntaxError) {
      class DuplicateNameRecord < BinData::Record
        int8 :a
        int8 :b
        int8 :a
      end
    }
    err.message.should == "duplicate field 'a' in #{DuplicateNameRecord}"
  end

  it "should fail on reserved names" do
    err = capture_exception(NameError) {
      class ReservedNameRecord < BinData::Record
        int8 :a
        int8 :invert # from Hash.instance_methods
      end
    }
    err.message.should == "field 'invert' is a reserved name in #{ReservedNameRecord}"
  end

  it "should fail when field name shadows an existing method" do
    err = capture_exception(NameError) {
      class ExistingNameRecord < BinData::Record
        int8 :object_id
      end
    }
    err.message.should == "field 'object_id' shadows an existing method in #{ExistingNameRecord}"
  end

  it "should fail on unknown endian" do
    err = capture_exception(ArgumentError) {
      class BadEndianRecord < BinData::Record
        endian 'a bad value'
      end
    }
    err.message.should == "unknown value for endian 'a bad value' in #{BadEndianRecord}"
  end
end

describe BinData::Record, "with hidden fields" do
  class HiddenRecord < BinData::Record
    hide :b, 'c'
    int8 :a
    int8 'b', :initial_value => 10
    int8 :c
    int8 :d, :value => :b
  end

  before(:each) do
    @obj = HiddenRecord.new
  end

  it "should only show fields that aren't hidden" do
    @obj.field_names.should == ["a", "d"]
  end

  it "should be able to access hidden fields directly" do
    @obj.b.should == 10
    @obj.c = 15
    @obj.c.should == 15

    @obj.should respond_to(:b=)
  end

  it "should not include hidden fields in snapshot" do
    @obj.b = 5
    @obj.snapshot.should == {"a" => 0, "d" => 5}
  end
end

describe BinData::Record, "with multiple fields" do
  class MultiFieldRecord < BinData::Record
    int8 :a
    int8 :b
  end

  before(:each) do
    @obj = MultiFieldRecord.new
    @obj.a = 1
    @obj.b = 2
  end

  it "should return num_bytes" do
    @obj.a.num_bytes.should == 1
    @obj.b.num_bytes.should == 1
    @obj.num_bytes.should     == 2
  end

  it "should identify accepted parameters" do
    BinData::Record.accepted_parameters.all.should include(:hide)
    BinData::Record.accepted_parameters.all.should include(:endian)
  end

  it "should clear" do
    @obj.a = 6
    @obj.clear
    @obj.should be_clear
  end

  it "should clear individual elements" do
    @obj.a = 6
    @obj.b = 7
    @obj.a.clear
    @obj.a.should be_clear
    @obj.b.should_not be_clear
  end

  it "should write ordered" do
    @obj.to_binary_s.should == "\x01\x02"
  end

  it "should read ordered" do
    @obj.read("\x03\x04")

    @obj.a.should == 3
    @obj.b.should == 4
  end

  it "should return a snapshot" do
    snap = @obj.snapshot
    snap.a.should == 1
    snap.b.should == 2
    snap.should == { "a" => 1, "b" => 2 }
  end

  it "should return field_names" do
    @obj.field_names.should == ["a", "b"]
  end
  
  it "should fail on unknown method call" do
    lambda { @obj.does_not_exist }.should raise_error(NoMethodError)
  end
end

describe BinData::Record, "with nested structs" do
  class Inner1Record < BinData::Record
    int8 :w, :initial_value => 3
    int8 :x, :value => :the_val
  end

  class Inner2Record < BinData::Record
    int8 :y, :value => lambda { parent.b.w }
    int8 :z
  end

  class RecordOuter < BinData::Record
    int8               :a, :initial_value => 6
    inner1_record :b, :the_val => :a
    inner2_record :c
  end

  before(:each) do
    @obj = RecordOuter.new
  end

  it "should included nested field names" do
    @obj.field_names.should == ["a", "b", "c"]
  end

  it "should access nested fields" do
    @obj.a.should   == 6
    @obj.b.w.should == 3
    @obj.b.x.should == 6
    @obj.c.y.should == 3
  end

  it "should return correct offset" do
    @obj.offset.should == 0
    @obj.b.offset.should == 1
    @obj.b.w.offset.should == 1
    @obj.c.offset.should == 3
    @obj.c.z.offset.should == 4
  end

  it "should return correct rel_offset" do
    @obj.rel_offset.should == 0
    @obj.b.rel_offset.should == 1
    @obj.b.w.rel_offset.should == 0
    @obj.c.rel_offset.should == 3
    @obj.c.z.rel_offset.should == 1
  end
end

describe BinData::Record, "with an endian defined" do
  class RecordWithEndian < BinData::Record
    endian :little

    uint16 :a
    float  :b
    array  :c, :type => :int8, :initial_length => 2
    choice :d, :choices => [ [:uint16], [:uint32] ], :selection => 1
    struct :e, :fields => [ [:uint16, :f], [:uint32be, :g] ]
    struct :h, :fields => [ [:struct, :i, {:fields => [[:uint16, :j]]}] ]
  end

  before(:each) do
    @obj = RecordWithEndian.new
  end

  it "should use correct endian" do
    @obj.a = 1
    @obj.b = 2.0
    @obj.c[0] = 3
    @obj.c[1] = 4
    @obj.d = 5
    @obj.e.f = 6
    @obj.e.g = 7
    @obj.h.i.j = 8

    expected = [1, 2.0, 3, 4, 5, 6, 7, 8].pack('veCCVvNv')

    @obj.to_binary_s.should == expected
  end
end

describe BinData::Record, "defined recursively" do
  class RecursiveRecord < BinData::Record
    endian  :big
    uint16  :val
    uint8   :has_nxt, :value => lambda { nxt.clear? ? 0 : 1 }
    recursive_record :nxt, :onlyif => lambda { has_nxt > 0 }
  end

  it "should be able to be created" do
    obj = RecursiveRecord.new
  end

  it "should read" do
    str = "\x00\x01\x01\x00\x02\x01\x00\x03\x00"
    obj = RecursiveRecord.read(str)
    obj.val.should == 1
    obj.nxt.val.should == 2
    obj.nxt.nxt.val.should == 3
  end

  it "should be assignable on demand" do
    obj = RecursiveRecord.new
    obj.val = 13
    obj.nxt.val = 14
    obj.nxt.nxt.val = 15
  end

  it "should write" do
    obj = RecursiveRecord.new
    obj.val = 5
    obj.nxt.val = 6
    obj.nxt.nxt.val = 7
    obj.to_binary_s.should == "\x00\x05\x01\x00\x06\x01\x00\x07\x00"
  end
end

describe BinData::Record, "with custom mandatory parameters" do
  class MandatoryRecord < BinData::Record
    mandatory_parameter :arg1

    uint8 :a, :value => :arg1
  end

  it "should raise error if mandatory parameter is not supplied" do
    lambda { MandatoryRecord.new }.should raise_error(ArgumentError)
  end

  it "should use mandatory parameter" do
    obj = MandatoryRecord.new(:arg1 => 5)
    obj.a.should == 5
  end
end

describe BinData::Record, "with custom default parameters" do
  class DefaultRecord < BinData::Record
    default_parameter :arg1 => 5

    uint8 :a, :value => :arg1
  end

  it "should not raise error if default parameter is not supplied" do
    lambda { DefaultRecord.new }.should_not raise_error(ArgumentError)
  end

  it "should use default parameter" do
    obj = DefaultRecord.new
    obj.a.should == 5
  end

  it "should be able to override default parameter" do
    obj = DefaultRecord.new(:arg1 => 7)
    obj.a.should == 7
  end
end

describe BinData::Record, "with :onlyif" do
  class OnlyIfRecord < BinData::Record
    uint8 :a, :initial_value => 3
    uint8 :b, :initial_value => 5, :onlyif => lambda { a == 3 }
    uint8 :c, :initial_value => 7, :onlyif => lambda { a != 3 }
  end

  before(:each) do
    @obj = OnlyIfRecord.new
  end

  it "should have correct num_bytes" do
    @obj.num_bytes.should == 2
  end

  it "should have expected snapshot" do
    @obj.snapshot.should == {"a" => 3, "b" => 5}
  end

  it "should read as expected" do
    @obj.read("\x01\x02")
    @obj.snapshot.should == {"a" => 1, "c" => 2}
  end

  it "should write as expected" do
    @obj.to_binary_s.should == "\x03\x05"
  end
end
