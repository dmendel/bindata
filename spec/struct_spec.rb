#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

describe BinData::Struct, "with hidden fields" do
  before(:each) do
    @params = { :hide => [:b, 'c'],
                :fields => [
                   [:int8, :a],
                   [:int8, 'b', {:initial_value => 10}],
                   [:int8, :c],
                   [:int8, :d, {:value => :b}]] }
    @obj = BinData::Struct.new(@params)
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

describe BinData::Struct do
  it "should fail on non registered types" do
    params = {:fields => [[:non_registered_type, :a]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(TypeError)
  end

  it "should fail on duplicate names" do
    params = {:fields => [[:int8, :a], [:int8, :b], [:int8, :a]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail on reserved names" do
    # note that #invert is from Hash.instance_methods
    params = {:fields => [[:int8, :a], [:int8, :invert]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail when field name shadows an existing method" do
    # note that #invert is from Hash.instance_methods
    params = {:fields => [[:int8, :object_id]]}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(NameError)
  end

  it "should fail on unknown endian" do
    params = {:endian => 'bad value', :fields => []}
    lambda {
      BinData::Struct.new(params)
    }.should raise_error(ArgumentError)
  end
end

describe BinData::Struct, "with multiple fields" do
  before(:each) do
    @params = { :fields => [ [:int8, :a], [:int8, :b] ] }
    @obj = BinData::Struct.new(@params)
    @obj.a = 1
    @obj.b = 2
  end

  it "should return num_bytes" do
    @obj.num_bytes(:a).should == 1
    @obj.num_bytes(:b).should == 1
    @obj.num_bytes.should     == 2
  end

  it "should identify accepted parameters" do
    BinData::Struct.accepted_parameters.should include(:fields)
    BinData::Struct.accepted_parameters.should include(:hide)
    BinData::Struct.accepted_parameters.should include(:endian)
  end

  it "should return field names" do
    @obj.field_names.should == ["a", "b"]
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

describe BinData::Struct, "with nested structs" do
  before(:each) do
    inner1 = [ [:int8, :w, {:initial_value => 3}],
               [:int8, :x, {:value => :the_val}] ]

    inner2 = [ [:int8, :y, {:value => lambda { parent.b.w }}],
               [:int8, :z] ]

    @params = { :fields => [
                  [:int8, :a, {:initial_value => 6}],
                  [:struct, :b, {:fields => inner1, :the_val => :a}],
                  [:struct, :c, {:fields => inner2}]] }
    @obj = BinData::Struct.new(@params)
  end

  it "should included nested field names" do
    @obj.field_names.should == ["a", "b", "c"]
  end

  it "should return num_bytes" do
    @obj.num_bytes(:b).should == 2
    @obj.num_bytes(:c).should == 2
    @obj.num_bytes.should == 5
  end

  it "should access nested fields" do
    @obj.a.should   == 6
    @obj.b.w.should == 3
    @obj.b.x.should == 6
    @obj.c.y.should == 3
    @obj.c.z.should == 0
  end

  it "should return correct offset of" do
    @obj.offset_of("b").should == 1
    @obj.offset_of("b").should == 1
    @obj.offset_of("c").should == 3
    @obj.offset_of("y").should be_nil
  end
end

describe BinData::Struct, "with an endian defined" do
  before(:each) do
    @obj = BinData::Struct.new(:endian => :little,
                               :fields => [
                                 [:uint16, :a],
                                 [:float, :b],
                                 [:array, :c,
                                   {:type => :int8, :initial_length => 2}],
                                 [:choice, :d,
                                   {:choices => [[:uint16], [:uint32]],
                                    :selection => 1}],
                                 [:struct, :e,
                                   {:fields => [[:uint16, :f],
                                                [:uint32be, :g]]}],
                                 [:struct, :h,
                                   {:fields => [
                                     [:struct, :i,
                                       {:fields => [[:uint16, :j]]}]]}]])

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

describe BinData::Struct, "with bit fields" do
  before(:each) do
    @params = { :fields => [ [:bit1le, :a], [:bit2le, :b] ] }
    @obj = BinData::Struct.new(@params)
    @obj.a = 1
    @obj.b = 2
  end

  it "should return num_bytes" do
    @obj.num_bytes.should == 1
  end

  it "should write" do
    @obj.to_s.should == [0b0000_0101].pack("C")
  end

  it "should read" do
    str = [0b0000_0110].pack("C")
    @obj.read(str)
    @obj.a.should == 0
    @obj.b.should == 3
  end
end

describe BinData::Struct, "with nested endian" do
  it "should use correct endian" do
    nested_params = { :endian => :little,
                      :fields => [[:int16, :b], [:int16, :c]] }
    params = { :endian => :big, 
               :fields => [[:int16, :a],
                           [:struct, :s, nested_params],
                           [:int16, :d]] }
    obj = BinData::Struct.new(params)
    str = "\x00\x01\x02\x00\x03\x00\x00\x04"
    obj.read(str)

    obj.a.should   == 1
    obj.s.b.should == 2
    obj.s.c.should == 3
    obj.d.should   == 4
  end
end
