#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

describe BinData::MultiValue, "with hidden fields" do
  before(:all) do
    eval <<-END
      class HiddenMultiValue < BinData::MultiValue
        hide :b, 'c'
        int8 :a
        int8 'b', :initial_value => 10
        int8 :c
        int8 :d, :value => :b
      end
    END
  end

  before(:each) do
    @obj = HiddenMultiValue.new
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

describe BinData::MultiValue, "when defining" do
  it "should fail on non registered types" do
    lambda {
      eval <<-END
        class BadTypeMultiValue < BinData::MultiValue
          non_registerd_type :a
        end
      END
    }.should raise_error(TypeError)
  end

  it "should fail on duplicate names" do
    lambda {
      eval <<-END
        class DuplicateNameMultiValue < BinData::MultiValue
          int8 :a
          int8 :b
          int8 :a
        end
      END
    }.should raise_error(SyntaxError)
  end

  it "should fail on reserved names" do
    lambda {
      eval <<-END
        class ReservedNameMultiValue < BinData::MultiValue
          int8 :a
          int8 :invert # from Hash.instance_methods
        end
      END
    }.should raise_error(NameError)
  end

  it "should fail when field name shadows an existing method" do
    lambda {
      eval <<-END
        class ExistingNameMultiValue < BinData::MultiValue
          int8 :object_id
        end
      END
    }.should raise_error(NameError)
  end

  it "should fail on unknown endian" do
    lambda {
      eval <<-END
        class BadEndianMultiValue < BinData::MultiValue
          endian 'a bad value'
        end
      END
    }.should raise_error(ArgumentError)
  end
end

describe BinData::MultiValue, "with multiple fields" do
  before(:all) do
    eval <<-END
      class MultiFieldMultiValue < BinData::MultiValue
        int8 :a
        int8 :b
      end
    END
  end

  before(:each) do
    @obj = MultiFieldMultiValue.new
    @obj.a = 1
    @obj.b = 2
  end

  it "should return num_bytes" do
    @obj.num_bytes(:a).should == 1
    @obj.num_bytes(:b).should == 1
    @obj.num_bytes.should     == 2
  end

  it "should identify accepted parameters" do
    BinData::MultiValue.accepted_parameters.should include(:hide)
    BinData::MultiValue.accepted_parameters.should include(:endian)
  end

  it "should clear" do
    @obj.a = 6
    @obj.clear
    @obj.clear?.should be_true
  end

  it "should clear individual elements" do
    @obj.a = 6
    @obj.b = 7
    @obj.clear(:a)
    @obj.clear?(:a).should be_true
    @obj.clear?(:b).should be_false
  end

  it "should write ordered" do
    io = StringIO.new
    @obj.write(io)

    io.rewind
    io.read.should == "\x01\x02"
  end

  it "should read ordered" do
    io = StringIO.new "\x03\x04"
    @obj.read(io)

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

describe BinData::MultiValue, "with nested structs" do
  before(:all) do
    eval <<-END
      class MultiValueInner1 < BinData::MultiValue
        int8 :w, :initial_value => 3
        int8 :x, :value => :the_val
      end

      class MultiValueInner2 < BinData::MultiValue
        int8 :y, :value => lambda { parent.b.w }
        int8 :z
      end

      class MultiValueOuter < BinData::MultiValue
        int8               :a, :initial_value => 6
        multi_value_inner1 :b, :the_val => :a
        multi_value_inner2 nil
      end
    END
  end

  before(:each) do
    @obj = MultiValueOuter.new
  end

  it "should included nested field names" do
    @obj.field_names.should == ["a", "b", "y", "z"]
  end

  it "should access nested fields" do
    @obj.a.should   == 6
    @obj.b.w.should == 3
    @obj.b.x.should == 6
    @obj.y.should   == 3
  end

  it "should return correct offset of" do
    @obj.offset_of("b").should == 1
    @obj.offset_of("y").should == 3
    @obj.offset_of("z").should == 4
  end
end

describe BinData::MultiValue, "with an endian defined" do
  before(:all) do
    eval <<-END
      class MultiValueWithEndian < BinData::MultiValue
        endian :little

        uint16 :a
        float  :b
        array  :c, :type => :int8, :initial_length => 2
        choice :d, :choices => [ [:uint16], [:uint32] ], :selection => 1
        struct :e, :fields => [ [:uint16, :f], [:uint32be, :g] ]
        struct :h, :fields => [ [:struct, :i, {:fields => [[:uint16, :j]]}] ]
      end
    END
  end

  before(:each) do
    @obj = MultiValueWithEndian.new
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

    io = StringIO.new
    @obj.write(io)

    io.rewind
    io.read.should == expected
  end
end
