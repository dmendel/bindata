#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

context "A Struct with hidden fields" do
  context_setup do
    eval <<-END
      class TestStruct < BinData::Struct
        hide :b, 'c'
        int8 :a
        int8 'b', :initial_value => 10
        int8 :c
        int8 :d, :value => :b
      end
    END
    @obj = TestStruct.new
  end

  specify "should only show fields that aren't hidden" do
    @obj.field_names.should == ["a", "d"]
  end

  specify "should be able to access hidden fields directly" do
    @obj.b.should eql(10)
    @obj.c = 15
    @obj.c.should eql(15)

    @obj.should respond_to?(:b=)
  end

  specify "should not include hidden fields in snapshot" do
    @obj.b = 5
    @obj.snapshot.should == {"a" => 0, "d" => 5}
  end
end

context "Defining a Struct" do
  specify "should fail on non registered types" do
    lambda {
      eval <<-END
        class BadType < BinData::Struct
          non_registerd_type :a
        end
      END
    }.should raise_error(TypeError)
  end

  specify "should fail on duplicate names" do
    lambda {
      eval <<-END
        class DuplicateName < BinData::Struct
          int8 :a
          int8 :b
          int8 :a
        end
      END
    }.should raise_error(SyntaxError)
  end

  specify "should fail when field name shadows an existing method" do
    lambda {
      eval <<-END
        class ExistingName < BinData::Struct
          int8 :object_id
        end
      END
    }.should raise_error(NameError)

    lambda {
      BinData::Struct.new(:fields => [[:int8, :object_id]])
    }.should raise_error(NameError)
  end

  specify "should fail on unknown endian" do
    lambda {
      eval <<-END
        class BadEndian < BinData::Struct
          endian 'a bad value'
        end
      END
    }.should raise_error(ArgumentError)
  end
end

context "A Struct with multiple fields" do
  setup do
    fields = [ [:int8, :a], [:int8, :b] ]
    @obj = BinData::Struct.new(:fields => fields) 
    @obj.a = 1
    @obj.b = 2
  end

  specify "should return num_bytes" do
    @obj.num_bytes(:a).should eql(1)
    @obj.num_bytes(:b).should eql(1)
    @obj.num_bytes.should     eql(2)
  end

  specify "should clear" do
    @obj.a = 6
    @obj.clear
    @obj.clear?.should be_true
  end

  specify "should clear individual elements" do
    @obj.a = 6
    @obj.b = 7
    @obj.clear(:a)
    @obj.clear?(:a).should be_true
    @obj.clear?(:b).should be_false
  end

  specify "should write ordered" do
    io = StringIO.new
    @obj.write(io)

    io.rewind
    io.read.should eql("\x01\x02")
  end

  specify "should read ordered" do
    io = StringIO.new "\x03\x04"
    @obj.read(io)

    @obj.a.should eql(3)
    @obj.b.should eql(4)
  end

  specify "should return a snapshot" do
    snap = @obj.snapshot
    snap.a.should eql(1)
    snap.b.should eql(2)
    snap.should == { "a" => 1, "b" => 2 }
  end

  specify "should return field_names" do
    @obj.field_names.should == ["a", "b"]
  end
  
  specify "should fail on unknown method call" do
    lambda { @obj.does_not_exist }.should raise_error(NoMethodError)
  end
end

context "A Struct with a value method" do
  context_setup do
    eval <<-END
      class StructWithValue < BinData::Struct
        int8 :a
        int8 :b

        def value
          a
        end
      end
    END
    @obj = StructWithValue.new
  end

  specify "should be single value object" do
    @obj.should be_a_single_value
  end

  specify "should have no field names" do
    @obj.field_names.should be_empty
  end

  specify "should not respond to field accesses" do
    @obj.should_not respond_to?(:a)
  end
end

context "A Struct with nested structs" do
  context_setup do
    eval <<-END
      class StructInner1 < BinData::Struct
        int8 :w, :initial_value => 3
        int8 :x, :value => :the_val
      end

      class StructInner2 < BinData::Struct
        int8 :y, :value => lambda { parent.b.w }
        int8 :z
      end

      class StructOuter < BinData::Struct
        int8          :a, :initial_value => 6
        struct_inner1 :b, :the_val => :a
        struct_inner2 nil
      end
    END
    @obj = StructOuter.new
  end

  specify "should included nested field names" do
    @obj.field_names.should == ["a", "b", "y", "z"]
  end

  specify "should access nested fields" do
    @obj.a.should   eql(6)
    @obj.b.w.should eql(3)
    @obj.b.x.should eql(6)
    @obj.y.should   eql(3)
  end

  specify "should return correct offset of" do
    @obj.offset_of("b").should eql(1)
    @obj.offset_of("y").should eql(3)
    @obj.offset_of("z").should eql(4)
  end
end

context "A Struct with an endian defined" do
  context_setup do
    eval <<-END
      class StructWithEndian < BinData::Struct
        endian :little

        uint16 :a
        float  :b
        array  :c, :type => :int8, :initial_length => 2
        choice :d, :choices => [ [:uint16], [:uint32] ], :selection => 1
        struct :e, :fields => [ [:uint16, :f], [:uint32be, :g] ]
      end
    END
    @obj = StructWithEndian.new
  end

  specify "should use correct endian" do
    @obj.a = 1
    @obj.b = 2.0
    @obj.c[0] = 3
    @obj.c[1] = 4
    @obj.d = 5
    @obj.e.f = 6
    @obj.e.g = 7

    expected = [1, 2.0, 3, 4, 5, 6, 7].pack('veCCVvN')

    io = StringIO.new
    @obj.write(io)

    io.rewind
    io.read.should == expected
  end
end
