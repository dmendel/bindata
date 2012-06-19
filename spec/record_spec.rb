#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require 'bindata'

describe BinData::Record do
  it "is not registered" do
    expect {
      BinData::RegisteredClasses.lookup("Record")
    }.to raise_error(BinData::UnRegisteredTypeError)
  end
end

describe BinData::Record, "when defining with errors" do
  it "fails on non registered types" do
    lambda {
      class BadTypeRecord < BinData::Record
        non_registered_type :a
      end
    }.should raise_error_on_line(TypeError, 2) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BadTypeRecord}"
    }
  end

  it "gives correct error message for non registered nested types" do
    lambda {
      class BadNestedTypeRecord < BinData::Record
        array :a, :type => :non_registered_type
      end
    }.should raise_error_on_line(TypeError, 2) { |err|
      err.message.should == "unknown type 'non_registered_type' in #{BadNestedTypeRecord}"
    }
  end

  it "gives correct error message for non registered nested types in blocks" do
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

  it "fails on nested choice when missing names" do
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

  it "fails on malformed names" do
    lambda {
      class MalformedNameRecord < BinData::Record
        int8 :a
        int8 "45"
      end
    }.should raise_error_on_line(NameError, 3) { |err|
      err.message.should == "field '45' is an illegal fieldname in #{MalformedNameRecord}"
    }
  end

  it "fails on duplicate names" do
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

  it "fails on reserved names" do
    lambda {
      class ReservedNameRecord < BinData::Record
        int8 :a
        int8 :invert # from Hash.instance_methods
      end
    }.should raise_error_on_line(NameError, 3) { |err|
      err.message.should == "field 'invert' is a reserved name in #{ReservedNameRecord}"
    }
  end

  it "fails when field name shadows an existing method" do
    lambda {
      class ExistingNameRecord < BinData::Record
        int8 :object_id
      end
    }.should raise_error_on_line(NameError, 2) { |err|
      err.message.should == "field 'object_id' shadows an existing method in #{ExistingNameRecord}"
    }
  end

  it "fails on unknown endian" do
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
    int8 nil
    int8
    int8 :value => :a
  end

  subject { AnonymousRecord.new }

  it "only shows non anonymous fields" do
    subject.field_names.should == ["a"]
  end

  it "does not include anonymous fields in snapshot" do
    subject.a = 5
    subject.snapshot.should == {"a" => 5}
  end

  it "writes anonymous fields" do
    str = "\001\002\003\004\005"
    subject.read(str)
    subject.a.clear
    subject.to_binary_s.should == "\012\002\003\004\012"
  end
end

describe BinData::Record, "with hidden fields" do
  class HiddenRecord < BinData::Record
    hide :b, :c
    int8 :a
    int8 'b', :initial_value => 10
    int8 :c
    int8 :d, :value => :b
  end

  subject { HiddenRecord.new }

  it "only shows fields that aren't hidden" do
    subject.field_names.should == ["a", "d"]
  end

  it "accesses hidden fields directly" do
    subject.b.should == 10
    subject.c = 15
    subject.c.should == 15

    subject.should respond_to(:b=)
  end

  it "does not include hidden fields in snapshot" do
    subject.b = 5
    subject.snapshot.should == {"a" => 0, "d" => 5}
  end
end

describe BinData::Record, "with multiple fields" do
  class MultiFieldRecord < BinData::Record
    int8 :a
    int8 :b
  end

  subject { MultiFieldRecord.new(:a => 1, :b => 2) }

  it "returns num_bytes" do
    subject.a.num_bytes.should == 1
    subject.b.num_bytes.should == 1
    subject.num_bytes.should     == 2
  end

  it "identifies accepted parameters" do
    BinData::Record.accepted_parameters.all.should include(:hide)
    BinData::Record.accepted_parameters.all.should include(:endian)
  end

  it "clears" do
    subject.a = 6
    subject.clear
    subject.should be_clear
  end

  it "clears individual elements" do
    subject.a = 6
    subject.b = 7
    subject.a.clear
    subject.a.should be_clear
    subject.b.should_not be_clear
  end

  it "writes ordered" do
    subject.to_binary_s.should == "\x01\x02"
  end

  it "reads ordered" do
    subject.read("\x03\x04")

    subject.a.should == 3
    subject.b.should == 4
  end

  it "returns a snapshot" do
    snap = subject.snapshot
    snap.a.should == 1
    snap.b.should == 2
    snap.should == { "a" => 1, "b" => 2 }
  end

  it "returns field_names" do
    subject.field_names.should == ["a", "b"]
  end
  
  it "fails on unknown method call" do
    expect { subject.does_not_exist }.to raise_error(NoMethodError)
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

  subject { NestedStructRecord.new }

  it "includes nested field names" do
    subject.field_names.should == ["a", "b", "c"]
  end

  it "hides nested field names" do
    subject.b.field_names.should == ["x"]
  end

  it "accesses nested fields" do
    subject.a.should   == 6
    subject.b.w.should == 3
    subject.b.x.should == 6
    subject.c.y.should == 3
  end

  it "returns correct offset" do
    subject.offset.should == 0
    subject.b.offset.should == 1
    subject.b.w.offset.should == 1
    subject.c.offset.should == 3
    subject.c.z.offset.should == 4
  end

  it "returns correct rel_offset" do
    subject.rel_offset.should == 0
    subject.b.rel_offset.should == 1
    subject.b.w.rel_offset.should == 0
    subject.c.rel_offset.should == 3
    subject.c.z.rel_offset.should == 1
  end

  it "assigns nested fields" do
    subject.assign(:a => 2, :b => {:w => 4})
    subject.a.should   == 2
    subject.b.w.should == 4
    subject.b.x.should == 2
    subject.c.y.should == 4
  end
end

describe BinData::Record, "with nested array of primitives" do
  class NestedPrimitiveArrayRecord < BinData::Record
    array :a, :initial_length => 3 do
      uint8 :value => lambda { index }
    end
  end

  subject { NestedPrimitiveArrayRecord.new }

  it "uses block as :type" do
    subject.snapshot.should == {"a" => [0, 1, 2]}
  end
end

describe BinData::Record, "with nested array of structs" do
  class NestedStructArrayRecord < BinData::Record
    array :a do
      uint8 :b
      uint8 :c
    end
  end

  subject { NestedStructArrayRecord.new }

  it "uses block as struct for :type" do
    subject.a[0].b = 2
    subject.snapshot.should == {"a" => [{"b" => 2, "c" => 0}]}
  end
end

describe BinData::Record, "with nested choice with implied keys" do
  class NestedChoiceWithImpliedKeysRecord < BinData::Record
    choice :a, :selection => 1 do
      uint8 :value => 1
      uint8 :value => 2
    end
  end

  subject { NestedChoiceWithImpliedKeysRecord.new }

  its(:a) { should == 2 }
end

describe BinData::Record, "with nested choice with explicit keys" do
  class NestedChoiceWithKeysRecord < BinData::Record
    choice :a, :selection => 5 do
      uint8 3, :value => 1
      uint8 5, :value => 2
    end
  end

  subject { NestedChoiceWithKeysRecord.new }

  its(:a) { should == 2 }
end

describe BinData::Record, "with nested choice with names" do
  class NestedChoiceWithNamesRecord < BinData::Record
    choice :a, :selection => "b" do
      uint8 "b", :value => 1
      uint8 "c", :value => 2
    end
  end

  subject { NestedChoiceWithNamesRecord.new }

  its(:a) { should == 1 }
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

  subject { RecordWithEndian.new }

  it "uses correct endian" do
    subject.a = 1
    subject.b = 2.0
    subject.c[0] = 3
    subject.c[1] = 4
    subject.d = 5
    subject.e.f = 6
    subject.e.g = 7
    subject.h.i.j = 8

    expected = [1, 2.0, 3, 4, 5, 6, 7, 8].pack('veCCVvNn')

    subject.to_binary_s.should == expected
  end
end

describe BinData::Record, "defined recursively" do
  class RecursiveRecord < BinData::Record
    endian  :big
    uint16  :val
    uint8   :has_nxt, :value => lambda { nxt.clear? ? 0 : 1 }
    recursive_record :nxt, :onlyif => lambda { has_nxt > 0 }
  end

  it "can be created" do
    subject = RecursiveRecord.new
  end

  it "reads" do
    str = "\x00\x01\x01\x00\x02\x01\x00\x03\x00"
    subject = RecursiveRecord.read(str)
    subject.val.should == 1
    subject.nxt.val.should == 2
    subject.nxt.nxt.val.should == 3
  end

  it "is assignable on demand" do
    subject = RecursiveRecord.new
    subject.val = 13
    subject.nxt.val = 14
    subject.nxt.nxt.val = 15
  end

  it "writes" do
    subject = RecursiveRecord.new
    subject.val = 5
    subject.nxt.val = 6
    subject.nxt.nxt.val = 7
    subject.to_binary_s.should == "\x00\x05\x01\x00\x06\x01\x00\x07\x00"
  end
end

describe BinData::Record, "with custom mandatory parameters" do
  class MandatoryRecord < BinData::Record
    mandatory_parameter :arg1

    uint8 :a, :value => :arg1
  end

  it "raises error if mandatory parameter is not supplied" do
    expect { MandatoryRecord.new }.to raise_error(ArgumentError)
  end

  it "uses mandatory parameter" do
    subject = MandatoryRecord.new(:arg1 => 5)
    subject.a.should == 5
  end
end

describe BinData::Record, "with custom default parameters" do
  class DefaultRecord < BinData::Record
    default_parameter :arg1 => 5

    uint8 :a, :value => :arg1
    uint8 :b
  end

  it "does not raise error if default parameter is not supplied" do
    expect { DefaultRecord.new }.not_to raise_error(ArgumentError)
  end

  it "uses default parameter" do
    subject = DefaultRecord.new
    subject.a.should == 5
  end

  it "overrides default parameter" do
    subject = DefaultRecord.new(:arg1 => 7)
    subject.a.should == 7
  end

  it "accepts values" do
    subject = DefaultRecord.new(:b => 2)
    subject.b.should == 2
  end

  it "accepts values and parameters" do
    subject = DefaultRecord.new({:b => 2}, :arg1 => 3)
    subject.a.should == 3
    subject.b.should == 2
  end
end

describe BinData::Record, "with :onlyif" do
  class OnlyIfRecord < BinData::Record
    uint8 :a, :initial_value => 3
    uint8 :b, :initial_value => 5, :onlyif => lambda { a == 3 }
    uint8 :c, :initial_value => 7, :onlyif => lambda { a != 3 }
  end

  subject { OnlyIfRecord.new }

  its(:num_bytes) { should == 2 }
  its(:snapshot) { should == {"a" => 3, "b" => 5} }
  its(:to_binary_s) { should == "\x03\x05" }

  it "reads as expected" do
    subject.read("\x01\x02")
    subject.snapshot.should == {"a" => 1, "c" => 2}
  end
end

describe BinData::Record, "derived classes" do
  class ParentRecord < BinData::Record
    uint8 :a
  end

  class Child1Record < ParentRecord
    uint8 :b
  end

  class Child2Record < Child1Record
    uint8 :c
  end

  it "does not affect parent" do
    ParentRecord.new.field_names.should == ["a"]
  end

  it "inherits fields for first child" do
    Child1Record.new.field_names.should == ["a", "b"]
  end

  it "inherits fields for second child" do
    Child2Record.new.field_names.should == ["a", "b", "c"]
  end
end
