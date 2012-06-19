#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "spec_common"))
require File.expand_path(File.join(File.dirname(__FILE__), "example"))
require 'bindata'

describe "lambdas with index" do
  class NestedLambdaWithIndex < BinData::Record
    uint8 :a, :value => lambda { index * 10 }
  end

  it "uses index of containing array" do
    arr = BinData::Array.new(:type =>
                               [:uint8, { :value => lambda { index * 10 } }],
                             :initial_length => 3)
    arr.snapshot.should == [0, 10, 20]
  end

  it "uses index of nearest containing array" do
    arr = BinData::Array.new(:type => :nested_lambda_with_index,
                             :initial_length => 3)
    arr.snapshot.should == [{"a" => 0}, {"a" => 10}, {"a" => 20}]
  end

  it "fails if there is no containing array" do
    subject = NestedLambdaWithIndex.new
    expect { subject.a.to_s }.to raise_error(NoMethodError)
  end
end

describe "lambdas with parent" do
  it "accesses immediate parent when no parent is specified" do
    class NestedLambdaWithoutParent < BinData::Record
      int8 :a, :value => 5
      int8 :b, :value => lambda { a }
    end

    class TestLambdaWithoutParent < BinData::Record
      int8   :a, :value => 3
      nested_lambda_without_parent :x
    end

    subject = TestLambdaWithoutParent.new
    subject.x.b.should == 5
  end

  it "accesses parent's parent when parent is specified" do
    class NestedLambdaWithParent < BinData::Record
      int8 :a, :value => 5
      int8 :b, :value => lambda { parent.a }
    end

    class TestLambdaWithParent < BinData::Record
      int8   :a, :value => 3
      nested_lambda_with_parent :x
    end

    subject = TestLambdaWithParent.new
    subject.x.b.should == 3
  end
end

describe BinData::Record, "with choice field" do
  class TupleRecord < BinData::Record
    uint8 :a, :value => 3
    uint8 :b, :value => 5
  end

  class RecordWithChoiceField < BinData::Record
    choice :x, :selection => 0 do
      tuple_record
    end
  end

  class RecordWithNestedChoiceField < BinData::Record
    uint8  :sel, :value => 0
    choice :x, :selection => 0 do
      choice :selection => :sel do
        tuple_record
      end
    end
  end

  it "treats choice object transparently " do
    subject = RecordWithChoiceField.new

    subject.x.a.should == 3
  end

  it "treats nested choice object transparently " do
    subject = RecordWithNestedChoiceField.new

    subject.x.a.should == 3
  end

  it "has correct offset" do
    subject = RecordWithNestedChoiceField.new
    subject.x.b.offset.should == 2
  end
end

describe BinData::Array, "of bits" do
  let(:data) { BinData::Array.new(:type => :bit1, :initial_length => 15) }

  it "reads" do
    str = [0b0001_0100, 0b1000_1000].pack("CC")
    data.read(str)
    data[0].should  == 0
    data[1].should  == 0
    data[2].should  == 0
    data[3].should  == 1
    data[4].should  == 0
    data[5].should  == 1
    data[6].should  == 0
    data[7].should  == 0
    data[8].should  == 1
    data[9].should  == 0
    data[10].should == 0
    data[11].should == 0
    data[12].should == 1
    data[13].should == 0
    data[14].should == 0
  end

  it "writes" do
    data[3] = 1
    data.to_binary_s.should == [0b0001_0000, 0b0000_0000].pack("CC")
  end

  it "returns num_bytes" do
    data.num_bytes.should == 2
  end

  it "has correct offset" do
    data[7].offset.should == 0
    data[8].offset.should == 1
  end
end

describe BinData::Record, "containing bitfields" do
  class BCD < BinData::Primitive
    bit4 :d1
    bit4 :d2
    bit4 :d3

    def set(v)
      self.d1 = (v / 100) % 10
      self.d2 = (v /  10) % 10
      self.d3 =  v        % 10
    end

    def get()
      d1 * 100 + d2 * 10 + d3
    end
  end

  class BitfieldRecord < BinData::Record
    struct :a do
      bit4 :w
    end

    array  :b, :type => :bit1, :initial_length => 9

    struct :c do
      bit2 :x
    end

    bcd    :d
    bit6   :e
  end

  subject { BitfieldRecord.new }

  it "has correct num_bytes" do
    subject.num_bytes.should == 5
  end

  it "reads across bitfield boundaries" do
    subject.read [0b0111_0010, 0b0110_0101, 0b0010_1010, 0b1000_0101, 0b1000_0000].pack("CCCCC")

    subject.a.w.should == 7
    subject.b.should == [0, 0, 1, 0, 0, 1, 1, 0, 0]
    subject.c.x.should == 2
    subject.d.should == 954
    subject.e.should == 11
  end

  it "writes across bitfield boundaries" do
    subject.a.w = 3
    subject.b[2] = 1
    subject.b[5] = 1
    subject.c.x = 1
    subject.d = 850
    subject.e = 35
    subject.to_binary_s.should == [0b0011_0010, 0b0100_0011, 0b0000_1010, 0b0001_0001, 0b1000_0000].pack("CCCCC")
  end
end

describe "Objects with debug_name" do
  it "haves default name of obj" do
    el = ExampleSingle.new
    el.debug_name.should == "obj"
  end

  it "includes array index" do
    arr = BinData::Array.new(:type => :example_single, :initial_length => 2)
    arr[2].debug_name.should == "obj[2]"
  end

  it "includes field name" do
    s = BinData::Struct.new(:fields => [[:example_single, :a]])
    s.a.debug_name.should == "obj.a"
  end

  it "delegates to choice" do
    choice_params = {:choices => [:example_single], :selection => 0}
    s = BinData::Struct.new(:fields => [[:choice, :a, choice_params]])
    s.a.debug_name.should == "obj.a"
  end

  it "nests" do
    nested_struct_params = {:fields => [[:example_single, :c]]}
    struct_params = {:fields => [[:struct, :b, nested_struct_params]]}
    s = BinData::Struct.new(:fields => [[:struct, :a, struct_params]])
    s.a.b.c.debug_name.should == "obj.a.b.c"
  end
end

describe "Tracing"  do
  it "should trace arrays" do
    arr = BinData::Array.new(:type => :int8, :initial_length => 5)

    io = StringIO.new
    BinData::trace_reading(io) { arr.read("\x01\x02\x03\x04\x05") }

    expected = (0..4).collect { |i| "obj[#{i}] => #{i + 1}\n" }.join("")
    io.value.should == expected
  end

  it "traces custom single values" do
    class DebugNamePrimitive < BinData::Primitive
      int8 :ex
      def get;     self.ex; end
      def set(val) self.ex = val; end
    end

    subject = DebugNamePrimitive.new

    io = StringIO.new
    BinData::trace_reading(io) { subject.read("\x01") }

    io.value.should == ["obj-internal-.ex => 1\n", "obj => 1\n"].join("")
  end

  it "traces choice selection" do
    subject = BinData::Choice.new(:choices => [:int8, :int16be], :selection => 0)

    io = StringIO.new
    BinData::trace_reading(io) { subject.read("\x01") }

    io.value.should == ["obj-selection- => 0\n", "obj => 1\n"].join("")
  end

  it "trims long trace values" do
    subject = BinData::String.new(:read_length => 40)

    io = StringIO.new
    BinData::trace_reading(io) { subject.read("0000000000111111111122222222223333333333") }

    io.value.should == "obj => \"000000000011111111112222222222...\n"
  end
end

describe "Forward referencing with Primitive" do
  class FRPrimitive < BinData::Record
    uint8  :len, :value => lambda { data.length }
    string :data, :read_length => :len
  end

  subject { FRPrimitive.new }

  it "initialises" do
    subject.snapshot.should == {"len" => 0, "data" => ""}
  end

  it "reads" do
    subject.read("\x04test")
    subject.snapshot.should == {"len" => 4, "data" => "test"}
  end

  it "sets value" do
    subject.data = "hello"
    subject.snapshot.should == {"len" => 5, "data" => "hello"}
  end
end

describe "Forward referencing with Array" do
  class FRArray < BinData::Record
    uint8  :len, :value => lambda { data.length }
    array :data, :type => :uint8, :initial_length => :len
  end

  subject { FRArray.new }

  it "initialises" do
    subject.snapshot.should == {"len" => 0, "data" => []}
  end

  it "reads" do
    subject.read("\x04\x01\x02\x03\x04")
    subject.snapshot.should == {"len" => 4, "data" => [1, 2, 3, 4]}
  end

  it "sets value" do
    subject.data = [1, 2, 3]
    subject.snapshot.should == {"len" => 3, "data" => [1, 2, 3]}
  end
end

describe "Evaluating custom parameters" do
  class CustomParameterRecord < BinData::Record
    mandatory_parameter :zz

    uint8 :a, :value => :zz
    uint8 :b, :value => :a
    uint8 :c, :custom => :b
  end

  it "recursively evaluates parameter" do
    subject = CustomParameterRecord.new(:zz => 5)
    subject.c.eval_parameter(:custom).should == 5
  end
end

describe BinData::Record, "with custom sized integers" do
  class CustomIntRecord < BinData::Record
    int40be :a
  end

  it "reads as expected" do
    str = "\x00\x00\x00\x00\x05"
    CustomIntRecord.read(str).should == {"a" => 5}
  end
end

describe BinData::Record, "with choice field" do
  class ChoiceFieldRecord < BinData::Record
    int8 :a
    choice :b, :selection => :a do
      struct 1, :fields => [[:int8, :v]]
    end
  end

  it "assigns" do
    subject = BinData::Array.new(:type => :choice_field_record)
    obj = ChoiceFieldRecord.new(:a => 1, :b => {:v => 3})
    subject.assign([obj])
  end
end

describe BinData::Primitive, "representing a string" do
  class PascalStringPrimitive < BinData::Primitive
    uint8  :len,  :value => lambda { data.length }
    string :data, :read_length => :len

    def get;   self.data; end
    def set(v) self.data = v; end
  end

  subject { PascalStringPrimitive.new("testing") }

  it "compares to regexp" do
    (subject =~ /es/).should == 1
  end

  it "compares to regexp" do
    (/es/ =~ subject).should == 1
  end
end

