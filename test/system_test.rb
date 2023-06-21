#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe "lambdas with index" do
  class NestedLambdaWithIndex < BinData::Record
    uint8 :a, value: -> { index * 10 }
  end

  it "uses index of containing array" do
    arr = BinData::Array.new(type:
                               [:uint8, { value: -> { index * 10 } }],
                             initial_length: 3)
    _(arr.snapshot).must_equal [0, 10, 20]
  end

  it "uses index of nearest containing array" do
    arr = BinData::Array.new(type: :nested_lambda_with_index,
                             initial_length: 3)
    _(arr.snapshot).must_equal [{a: 0}, {a: 10}, {a: 20}]
  end

  it "fails if there is no containing array" do
    obj = NestedLambdaWithIndex.new
    _ { obj.a.to_s }.must_raise NoMethodError
  end
end

describe "lambdas with parent" do
  it "accesses immediate parent when no parent is specified" do
    class NestedLambdaWithoutParent < BinData::Record
      int8 :a, value: 5
      int8 :b, value: -> { a }
    end

    class TestLambdaWithoutParent < BinData::Record
      int8   :a, value: 3
      nested_lambda_without_parent :x
    end

    obj = TestLambdaWithoutParent.new
    _(obj.x.b).must_equal 5
  end

  it "accesses parent's parent when parent is specified" do
    class NestedLambdaWithParent < BinData::Record
      int8 :a, value: 5
      int8 :b, value: -> { parent.a }
    end

    class TestLambdaWithParent < BinData::Record
      int8   :a, value: 3
      nested_lambda_with_parent :x
    end

    obj = TestLambdaWithParent.new
    _(obj.x.b).must_equal 3
  end
end

describe BinData::Record, "with choice field" do
  class TupleRecord < BinData::Record
    uint8 :a, value: 3
    uint8 :b, value: 5
  end

  class RecordWithChoiceField < BinData::Record
    choice :x, selection: 0 do
      tuple_record
    end
  end

  class RecordWithNestedChoiceField < BinData::Record
    uint8  :sel, value: 0
    choice :x, selection: 0 do
      choice selection: :sel do
        tuple_record
      end
    end
  end

  it "treats choice object transparently " do
    obj = RecordWithChoiceField.new

    _(obj.x.a).must_equal 3
  end

  it "treats nested choice object transparently " do
    obj = RecordWithNestedChoiceField.new

    _(obj.x.a).must_equal 3
  end

  it "has correct offset" do
    obj = RecordWithNestedChoiceField.new
    _(obj.x.b.abs_offset).must_equal 2
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

    array  :b, type: :bit1, initial_length: 9

    struct :c do
      bit2 :x
    end

    bcd    :d
    bit6   :e
  end

  let(:obj) { BitfieldRecord.new }

  it "has correct num_bytes" do
    _(obj.num_bytes).must_equal 5
  end

  it "reads across bitfield boundaries" do
    obj.read [0b0111_0010, 0b0110_0101, 0b0010_1010, 0b1000_0101, 0b1000_0000].pack("CCCCC")

    _(obj.a.w).must_equal 7
    _(obj.b).must_equal [0, 0, 1, 0, 0, 1, 1, 0, 0]
    _(obj.c.x).must_equal 2
    _(obj.d).must_equal 954
    _(obj.e).must_equal 11
  end

  it "writes across bitfield boundaries" do
    obj.a.w = 3
    obj.b[2] = 1
    obj.b[5] = 1
    obj.c.x = 1
    obj.d = 850
    obj.e = 35
    _(obj.to_binary_s).must_equal_binary [0b0011_0010, 0b0100_0011, 0b0000_1010, 0b0001_0001, 0b1000_0000].pack("CCCCC")
  end
end

describe "Objects with debug_name" do
  it "haves default name of obj" do
    el = BinData::Uint8.new
    _(el.debug_name).must_equal "obj"
  end

  it "includes array index" do
    arr = BinData::Array.new(type: :uint8, initial_length: 2)
    _(arr[2].debug_name).must_equal "obj[2]"
  end

  it "includes field name" do
    s = BinData::Struct.new(fields: [[:uint8, :a]])
    _(s.a.debug_name).must_equal "obj.a"
  end

  it "delegates to choice" do
    choice_params = {choices: [:uint8], selection: 0}
    s = BinData::Struct.new(fields: [[:choice, :a, choice_params]])
    _(s.a.debug_name).must_equal "obj.a"
  end

  it "nests" do
    nested_struct_params = {fields: [[:uint8, :c]]}
    struct_params = {fields: [[:struct, :b, nested_struct_params]]}
    s = BinData::Struct.new(fields: [[:struct, :a, struct_params]])
    _(s.a.b.c.debug_name).must_equal "obj.a.b.c"
  end
end

describe "Tracing"  do
  it "should trace arrays" do
    arr = BinData::Array.new(type: :int8, initial_length: 5)

    io = StringIO.new
    BinData::trace_reading(io) { arr.read("\x01\x02\x03\x04\x05") }

    expected = (0..4).collect { |i| "obj[#{i}] => #{i + 1}\n" }.join("")
    _(io.value).must_equal expected
  end

  it "traces custom single values" do
    class DebugNamePrimitive < BinData::Primitive
      int8 :ex
      def get;     self.ex; end
      def set(val) self.ex = val; end
    end

    obj = DebugNamePrimitive.new

    io = StringIO.new
    BinData::trace_reading(io) { obj.read("\x01") }

    _(io.value).must_equal ["obj-internal-.ex => 1\n", "obj => 1\n"].join("")
  end

  it "traces choice selection" do
    obj = BinData::Choice.new(choices: [:int8, :int16be], selection: 0)

    io = StringIO.new
    BinData::trace_reading(io) { obj.read("\x01") }

    _(io.value).must_equal ["obj-selection- => 0\n", "obj => 1\n"].join("")
  end

  it "trims long trace values" do
    obj = BinData::String.new(read_length: 40)

    io = StringIO.new
    BinData::trace_reading(io) { obj.read("0000000000111111111122222222223333333333") }

    _(io.value).must_equal "obj => \"000000000011111111112222222222...\n"
  end

  it "can be nested" do
    obj = BinData::String.new(read_length: 5)

    io = StringIO.new
    BinData::trace_reading(io) {
      BinData::trace_reading(io) {
        obj.read("12345")
      }
    }

    _(io.value).must_equal "obj => \"12345\"\n"
  end
end

describe "Forward referencing with Primitive" do
  class FRPrimitive < BinData::Record
    uint8  :len, value: -> { data.length }
    string :data, read_length: :len
  end

  let(:obj) { FRPrimitive.new }

  it "initialises" do
    _(obj.snapshot).must_equal({len: 0, data: ""})
  end

  it "reads" do
    obj.read("\x04test")
    _(obj.snapshot).must_equal({len: 4, data: "test"})
  end

  it "sets value" do
    obj.data = "hello"
    _(obj.snapshot).must_equal({len: 5, data: "hello"})
  end
end

describe "Forward referencing with Array" do
  class FRArray < BinData::Record
    uint8  :len, value: -> { data.length }
    array :data, type: :uint8, initial_length: :len
  end

  let(:obj) { FRArray.new }

  it "initialises" do
    _(obj.snapshot).must_equal({len: 0, data: []})
  end

  it "reads" do
    obj.read("\x04\x01\x02\x03\x04")
    _(obj.snapshot).must_equal({len: 4, data: [1, 2, 3, 4]})
  end

  it "sets value" do
    obj.data = [1, 2, 3]
    _(obj.snapshot).must_equal({len: 3, data: [1, 2, 3]})
  end
end

describe "Evaluating custom parameters" do
  class CustomParameterRecord < BinData::Record
    mandatory_parameter :zz

    uint8 :a, value: :zz
    uint8 :b, value: :a
    uint8 :c, custom: :b
  end

  it "recursively evaluates parameter" do
    obj = CustomParameterRecord.new(zz: 5)
    _(obj.c.eval_parameter(:custom)).must_equal 5
  end
end

describe BinData::Record, "with custom sized integers" do
  class CustomIntRecord < BinData::Record
    int40be :a
  end

  it "reads as expected" do
    str = "\x00\x00\x00\x00\x05"
    _(CustomIntRecord.read(str).snapshot).must_equal({a: 5})
  end
end

describe BinData::Record, "with choice field" do
  class ChoiceFieldRecord < BinData::Record
    int8 :a
    choice :b, selection: :a do
      struct 1, fields: [[:int8, :v]]
    end
  end

  it "assigns" do
    obj = BinData::Array.new(type: :choice_field_record)
    data = ChoiceFieldRecord.new(a: 1, b: {v: 3})
    obj.assign([data])
  end
end

describe BinData::Primitive, "representing a string" do
  class PascalStringPrimitive < BinData::Primitive
    uint8  :len,  value: -> { data.length }
    string :data, read_length: :len

    def get;   self.data; end
    def set(v) self.data = v; end
  end

  let(:obj) { PascalStringPrimitive.new("testing") }

  it "compares to regexp" do
    _((obj =~ /es/)).must_equal 1
  end

  it "compares to regexp" do
    _((/es/ =~ obj)).must_equal 1
  end
end

describe BinData::Record, "with boolean parameters" do
  class BooleanParameterRecord < BinData::Record
    default_parameter flag: true

    int8 :a, value: -> { flag ? 2 : 3 }
  end

  it "uses default parameter" do
    obj = BooleanParameterRecord.new
    _(obj.a).must_equal 2
  end

  it "overrides parameter" do
    obj = BooleanParameterRecord.new(flag: false)
    _(obj.a).must_equal 3
  end

  it "overrides parameter with same value" do
    obj = BooleanParameterRecord.new(flag: true)
    _(obj.a).must_equal 2
  end
end

describe BinData::Record, "encoding" do
  class EncodingTestBufferRecord < BinData::Record
    endian :big
    default_parameter length: 5

    uint16 :num
    string :str, length: 10
  end

  it "returns binary encoded data" do
    obj = EncodingTestBufferRecord.new(num: 3)
    _(obj.to_binary_s.encoding).must_equal Encoding::ASCII_8BIT
  end

  it "returns binary encoded data with utf-8 string" do
    obj = EncodingTestBufferRecord.new(num: 3, str: "日本語")
    _(obj.to_binary_s.encoding).must_equal Encoding::ASCII_8BIT
  end

  it "returns binary encoded data despite Encoding.default_internal" do
    w, $-w = $-w, nil
    before_enc = Encoding.default_internal

    begin
      Encoding.default_internal = Encoding::UTF_8
      obj = EncodingTestBufferRecord.new(num: 3, str: "日本語")
      _(obj.to_binary_s.encoding).must_equal Encoding::ASCII_8BIT
    ensure
      Encoding.default_internal = before_enc
      $-w = w
    end
  end
end

describe BinData::Record, "buffer num_bytes" do
  class BufferNumBytesRecord < BinData::Record
    buffer :b, length: 10 do
      int8 :a
      count_bytes_remaining :nbytes
    end
  end

  it "counts bytes remaining in the buffer" do
    obj = BufferNumBytesRecord.read "12345678901234567890"
    _(obj.b.nbytes).must_equal 9
  end

  it "counts bytes remaining in the buffer with short streams" do
    obj = BufferNumBytesRecord.read "12345"
    _(obj.b.nbytes).must_equal 4
  end

  it "assumes buffer is full with non-seekable short streams" do
    rd, wr = IO::pipe
    io = BinData::IO::Read.new(rd)
    wr.write "12345"
    wr.close

    obj = BufferNumBytesRecord.read(io)
    _(obj.b.nbytes).must_equal 9
    rd.close
  end
end

describe BinData::Buffer, "with seek_abs" do
  class BufferSkipRecord < BinData::Record
    endian :little
    mandatory_parameter :seek_offset

    uint8
    buffer :buf, length: 5 do
      uint8
      uint8
      skip to_abs_offset: :seek_offset
      uint8 :a
    end
    uint8
  end

  let(:str) { "\001\002\003\004\005\006\007" }

  ## TODO: enable this if we decide to allow backwards seeking
  #backwards_seeking = false
  #
  #it "won't seek backwards before buffer" do
  #  skip unless backwards_seeking
  #  _ { BufferSkipRecord.new(seek_offset: 0).read(str) }.must_raise(IOError)
  #end
  #
  #it "seeks backwards to start of buffer" do
  #  skip unless backwards_seeking
  #  obj = BufferSkipRecord.new(seek_offset: 1).read(str)
  #  _(obj.buf.a).must_equal 2
  #end
  #
  #it "seeks backwards inside buffer" do
  #  skip unless backwards_seeking
  #  obj = BufferSkipRecord.new(seek_offset: 2).read(str)
  #  _(obj.buf.a).must_equal 3
  #end

  it "seeks forwards inside buffer" do
    obj = BufferSkipRecord.new(seek_offset: 4).read(str)
    _(obj.buf.a).must_equal 5
  end

  it "seeks to end of buffer" do
    obj = BufferSkipRecord.new(seek_offset: 5).read(str)
    _(obj.buf.a).must_equal 6
  end

  it "won't seek after buffer" do
    _ { BufferSkipRecord.new(seek_offset: 6).read(str) }.must_raise(IOError)
  end
end


describe BinData::Record, "buffered readahead" do
  class BufferedReadaheadRecord < BinData::Record
    buffer :a, length: 5 do
      skip do
        string read_length: 1, assert: "X"
      end
      string :b, read_length: 1
    end
    string :c, read_length: 1
  end

  it "reads ahead inside the buffer" do
    obj = BufferedReadaheadRecord.read "12X4567890"
    _(obj.a.b).must_equal "X"
    _(obj.c).must_equal "6"
  end

  it "doesn't readahead outside the buffer" do
    _ { BufferedReadaheadRecord.read "123456X890" }.must_raise IOError
  end
end
