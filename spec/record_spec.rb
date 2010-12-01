#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::Record, "when defining with errors" do
  it "should fail on non registered types" do
    lambda {
      class BadTypeRecord < BinData::Record
        non_registered_type :a
      end
    }.should raise_error_on_line(TypeError, 2) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BadTypeRecord}"
    }
  end

  it "should give correct error message for non registered nested types" do
    lambda {
      class BadNestedTypeRecord < BinData::Record
        array :a, :type => :non_registered_type
      end
    }.should raise_error_on_line(TypeError, 2) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BadNestedTypeRecord}"
    }
  end

  it "should give correct error message for non registered nested types in blocks" do
    lambda {
      class BadNestedTypeInBlockRecord < BinData::Record
        array :a do
          non_registered_type
        end
      end
    }.should raise_error_on_line(TypeError, 3) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BinData::Array}"
    }
  end

  it "should fail on nested choice when missing names" do
    lambda {
      class MissingChoiceNamesRecord < BinData::Record
        choice do
          int8 :a
          int8
        end
      end
    }.should raise_error_on_line(SyntaxError, 4) { |err|
      err.message.should == "fields must either all have names, or none must have names in BinData::Choice"
    }
  end

  it "should fail on malformed names" do
    lambda {
      class MalformedNameRecord < BinData::Record
        int8 :a
        int8 45
      end
    }.should raise_error_on_line(NameError, 3) { |err|
      err.message.should == "field '45' is an illegal fieldname in #{MalformedNameRecord}"
    }
  end

  it "should fail on duplicate names" do
    lambda {
      class DuplicateNameRecord < BinData::Record
        int8 :a
        int8 :b
        int8 :a
      end
    }.should raise_error_on_line(SyntaxError, 4) { |err|
      err.message.should == "duplicate field 'a' in #{DuplicateNameRecord}"
    }
  end

  it "should fail on reserved names" do
    lambda {
      class ReservedNameRecord < BinData::Record
        int8 :a
        int8 :invert # from Hash.instance_methods
      end
    }.should raise_error_on_line(NameError, 3) { |err|
      err.message.should == "field 'invert' is a reserved name in #{ReservedNameRecord}"
    }
  end

  it "should fail when field name shadows an existing method" do
    lambda {
      class ExistingNameRecord < BinData::Record
        int8 :object_id
      end
    }.should raise_error_on_line(NameError, 2) { |err|
      err.message.should == "field 'object_id' shadows an existing method in #{ExistingNameRecord}"
    }
  end

  it "should fail on unknown endian" do
    lambda {
      class BadEndianRecord < BinData::Record
        endian 'a bad value'
      end
    }.should raise_error_on_line(ArgumentError, 2) { |err|
      err.message.should == "unknown value for endian 'a bad value' in #{BadEndianRecord}"
    }
  end
end

describe BinData::Record, "with anonymous fields" do
  class AnonymousRecord < BinData::Record
    int8 'a', :initial_value => 10
    int8 ''
    int8
    int8 :value => :a
  end

  before(:each) do
    @obj = AnonymousRecord.new
  end

  it "should only show non anonymous fields" do
    @obj.field_names.should == ["a"]
  end

  it "should not include anonymous fields in snapshot" do
    @obj.a = 5
    @obj.snapshot.should == {"a" => 5}
  end

  it "should write anonymous fields" do
    str = "\001\002\003\004"
    @obj.read(str)
    @obj.a.clear
    @obj.to_binary_s.should == "\012\002\003\012"
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
  class NestedStructRecord < BinData::Record
    int8   :a, :initial_value => 6
    struct :b, :the_val => :a do
      hide :w
      int8 :w, :initial_value => 3
      int8 :x, :value => :the_val
    end
    struct :c do
      int8 :y, :value => lambda { b.w }
      int8 :z
    end
  end

  before(:each) do
    @obj = NestedStructRecord.new
  end

  it "should included nested field names" do
    @obj.field_names.should == ["a", "b", "c"]
  end

  it "should hide nested field names" do
    @obj.b.field_names.should == ["x"]
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

describe BinData::Record, "with nested array of primitives" do
  class NestedPrimitiveArrayRecord < BinData::Record
    array :a, :initial_length => 3 do
      uint8 :value => lambda { index }
    end
  end

  before(:each) do
    @obj = NestedPrimitiveArrayRecord.new
  end

  it "should use block as :type" do
    @obj.snapshot.should == {"a" => [0, 1, 2]}
  end
end

describe BinData::Record, "with nested array of structs" do
  class NestedStructArrayRecord < BinData::Record
    array :a do
      uint8 :b
      uint8 :c
    end
  end

  before(:each) do
    @obj = NestedStructArrayRecord.new
  end

  it "should use block as struct for :type" do
    @obj.a[0].b = 2
    @obj.snapshot.should == {"a" => [{"b" => 2, "c" => 0}]}
  end
end

describe BinData::Record, "with nested choice without names" do
  class NestedChoiceRecord < BinData::Record
    choice :a, :selection => 1 do
      uint8 :value => 1
      uint8 :value => 2
    end
  end

  before(:each) do
    @obj = NestedChoiceRecord.new
  end

  it "should select choices by index" do
    @obj.a.should == 2
  end
end

describe BinData::Record, "with nested choice with names" do
  class NestedChoiceWithNamesRecord < BinData::Record
    choice :a, :selection => "b" do
      uint8 "b", :value => 1
      uint8 "c", :value => 2
    end
  end

  before(:each) do
    @obj = NestedChoiceWithNamesRecord.new
  end

  it "should select choices by name" do
    @obj.a.should == 1
  end
end

describe BinData::Record, "with an endian defined" do
  class RecordWithEndian < BinData::Record
    endian :little

    uint16 :a
    float  :b
    array  :c, :initial_length => 2 do
      int8
    end
    choice :d, :selection => 1 do
      uint16
      uint32
    end
    struct :e do
      uint16   :f
      uint32be :g
    end
    struct :h do
      endian :big
      struct :i do
        uint16 :j
      end
    end
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

    expected = [1, 2.0, 3, 4, 5, 6, 7, 8].pack('veCCVvNn')

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

describe BinData::Record, "derived classes" do
  class ParentDerivedRecord < BinData::Record
    uint8 :a
  end

  class ChildDerivedRecord < ParentDerivedRecord
    uint8 :b
  end

  it "should not affect parent" do
    parent = ParentDerivedRecord.new
    parent.field_names.should == ["a"]
  end

  it "should inherit fields" do
    child = ChildDerivedRecord.new
    child.field_names.should == ["a", "b"]
  end
end
