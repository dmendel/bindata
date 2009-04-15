#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require File.expand_path(File.dirname(__FILE__)) + '/example'
require 'bindata'

describe "lambdas with index" do
  before(:all) do
    eval <<-END
      class NestedLambdaWithIndex < BinData::Record
        uint8 :a, :value => lambda { index * 10 }
      end
    END
  end

  it "should use index of containing array" do
    arr = BinData::Array.new(:type =>
                               [:uint8, { :value => lambda { index * 10 } }],
                             :initial_length => 3)
    arr.snapshot.should == [0, 10, 20]
  end

  it "should use index of nearest containing array" do
    arr = BinData::Array.new(:type => :nested_lambda_with_index,
                             :initial_length => 3)
    arr.snapshot.should == [{"a" => 0}, {"a" => 10}, {"a" => 20}]
  end

  it "should fail if there is no containing array" do
    obj = NestedLambdaWithIndex.new
    lambda { obj.a.value }.should raise_error(NoMethodError)
  end
end

describe "lambdas with parent" do
  it "should access immediate parent when no parent is specified" do
    class NestedLambdaWithoutParent < BinData::Record
      int8 :a, :value => 5
      int8 :b, :value => lambda { a }
    end

    class TestLambdaWithoutParent < BinData::Record
      int8   :a, :value => 3
      nested_lambda_without_parent :x
    end

    obj = TestLambdaWithoutParent.new
    obj.x.b.should == 5
  end

  it "should access parent's parent when parent is specified" do
    class NestedLambdaWithParent < BinData::Record
      int8 :a, :value => 5
      int8 :b, :value => lambda { parent.a }
    end

    class TestLambdaWithParent < BinData::Record
      int8   :a, :value => 3
      nested_lambda_with_parent :x
    end

    obj = TestLambdaWithParent.new
    obj.x.b.should == 3
  end
end

describe "Records with choice field" do
  before(:all) do
    eval <<-END
      class TupleRecord < BinData::Record
        uint8 :a, :value => 3
        uint8 :b, :value => 5
      end

      class RecordWithChoiceField < BinData::Record
        choice :x, :choices => [[:tuple_record]], :selection => 0
      end

      class RecordWithNestedChoiceField < BinData::Record
        choice :x, :choices => [
                      [:choice, {
                          :choices => [[:tuple_record]],
                          :selection => 0}
                      ]
                   ],
                   :selection => 0
      end
    END
  end

  it "should treat choice object transparently " do
    obj = RecordWithChoiceField.new

    obj.x.a.should == 3
  end

  it "should treat nested choice object transparently " do
    obj = RecordWithNestedChoiceField.new

    obj.x.a.should == 3
  end

  it "should have correct offset" do
    obj = RecordWithNestedChoiceField.new
    obj.x.b.offset.should == 1
  end
end

describe BinData::Array, "of bits" do
  before(:each) do
    @data = BinData::Array.new(:type => :bit1, :initial_length => 15)
  end

  it "should read" do
    str = [0b0001_0100, 0b1000_1000].pack("CC")
    @data.read(str)
    @data[0].should  == 0
    @data[1].should  == 0
    @data[2].should  == 0
    @data[3].should  == 1
    @data[4].should  == 0
    @data[5].should  == 1
    @data[6].should  == 0
    @data[7].should  == 0
    @data[8].should  == 1
    @data[9].should  == 0
    @data[10].should == 0
    @data[11].should == 0
    @data[12].should == 1
    @data[13].should == 0
    @data[14].should == 0
  end

  it "should write" do
    @data[3] = 1
    @data.to_binary_s.should == [0b0001_0000, 0b0000_0000].pack("CC")
  end

  it "should return num_bytes" do
    @data.num_bytes.should == 2
  end

  it "should have correct offset" do
    @data[7].offset.should == 0
    @data[8].offset.should == 1
  end
end

describe "Objects with debug_name" do
  it "should have default name of obj" do
    el = ExampleSingle.new
    el.debug_name.should == "obj"
  end

  it "should include array index" do
    arr = BinData::Array.new(:type => :example_single, :initial_length => 2)
    arr[2].debug_name.should == "obj[2]"
  end

  it "should include field name" do
    s = BinData::Struct.new(:fields => [[:example_single, :a]])
    s.a.debug_name.should == "obj.a"
  end

  it "should delegate to choice" do
    choice_params = {:choices => [:example_single], :selection => 0}
    s = BinData::Struct.new(:fields => [[:choice, :a, choice_params]])
    s.a.debug_name.should == "obj.a"
  end

  it "should nest" do
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
    io.rewind

    expected = (0..4).collect { |i| "obj[#{i}] => #{i + 1}\n" }.join("")
    io.read.should == expected
  end

  it "should trace custom single values" do
    class DebugNamePrimitive < BinData::Primitive
      int8 :ex
      def get;     self.ex; end
      def set(val) self.ex = val; end
    end

    obj = DebugNamePrimitive.new

    io = StringIO.new
    BinData::trace_reading(io) { obj.read("\x01") }
    io.rewind

    io.read.should == ["obj-internal-.ex => 1\n", "obj => 1\n"].join("")
  end

  it "should trace choice selection" do
    obj = BinData::Choice.new(:choices => [:int8, :int16be], :selection => 0)

    io = StringIO.new
    BinData::trace_reading(io) { obj.read("\x01") }
    io.rewind

    io.read.should == ["obj-selection- => 0\n", "obj => 1\n"].join("")
  end
end

describe "Forward referencing with Single" do
  before(:all) do
    eval <<-END
      class FRSingle < BinData::Record
        uint8  :len, :value => lambda { data.length }
        string :data, :read_length => :len
      end
    END
  end

  it "should initialise" do
    @obj = FRSingle.new
    @obj.snapshot.should == {"len" => 0, "data" => ""}
  end

  it "should read" do
    @obj = FRSingle.new
    @obj.read("\x04test")
    @obj.snapshot.should == {"len" => 4, "data" => "test"}
  end

  it "should set value" do
    @obj = FRSingle.new
    @obj.data = "hello"
    @obj.snapshot.should == {"len" => 5, "data" => "hello"}
  end
end

describe "Forward referencing with Array" do
  before(:all) do
    eval <<-END
      class FRArray < BinData::Record
        uint8  :len, :value => lambda { data.length }
        array :data, :type => :uint8, :initial_length => :len
      end
    END
  end

  it "should initialise" do
    @obj = FRArray.new
    @obj.snapshot.should == {"len" => 0, "data" => []}
  end

  it "should read" do
    @obj = FRArray.new
    @obj.read("\x04\x01\x02\x03\x04")
    @obj.snapshot.should == {"len" => 4, "data" => [1, 2, 3, 4]}
  end

  it "should set value" do
    @obj = FRArray.new
    @obj.data = [1, 2, 3]
    @obj.snapshot.should == {"len" => 3, "data" => [1, 2, 3]}
  end
end

describe "Evaluating custom parameters" do
  before(:all) do
    eval <<-END
      class CustomParameterRecord < BinData::Record
        mandatory_parameter :zz

        uint8 :a, :value => :zz
        uint8 :b, :value => :a
        uint8 :c, :custom => :b
      end
    END
  end

  it "should recursively evaluate parameter" do
    obj = CustomParameterRecord.new(:zz => 5)
    obj.c.eval_parameter(:custom).should == 5
  end
end
