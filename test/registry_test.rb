#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "common"))

describe BinData::Registry do
  A = Class.new
  B = Class.new
  C = Class.new
  D = Class.new

  let(:r) { BinData::Registry.new }

  it "lookups registered names" do
    r.register('ASubClass', A)
    r.register('AnotherSubClass', B)

    r.lookup('ASubClass').must_equal A
    r.lookup('a_sub_class').must_equal A
    r.lookup('AnotherSubClass').must_equal B
    r.lookup('another_sub_class').must_equal B
  end

  it "does not lookup unregistered names" do
    lambda {
      r.lookup('a_non_existent_sub_class')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "unregisters names" do
    r.register('ASubClass', A)
    r.unregister('ASubClass')

    lambda {
      r.lookup('ASubClass')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "allows overriding of registered classes" do
    r.register('A', A)
    r.register('A', B)

    r.lookup('a').must_equal B
  end

  it "converts CamelCase to underscores" do
    r.underscore_name('CamelCase').must_equal 'camel_case'
  end

  it "converts adjacent caps camelCase to underscores" do
    r.underscore_name('XYZCamelCase').must_equal 'xyz_camel_case'
  end

  it "ignores the outer nestings of classes" do
    r.underscore_name('A::B::C').must_equal 'c'
  end
end

describe BinData::Registry, "with numerics" do
  let(:r) { BinData::RegisteredClasses }

  it "lookup integers with endian" do
    r.lookup("int24", :big).to_s.must_equal "BinData::Int24be"
    r.lookup("int24", :little).to_s.must_equal "BinData::Int24le"
    r.lookup("uint24", :big).to_s.must_equal "BinData::Uint24be"
    r.lookup("uint24", :little).to_s.must_equal "BinData::Uint24le"
  end

  it "does not lookup integers without endian" do
    lambda {
      r.lookup("int24")
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "does not lookup non byte based integers" do
    lambda {
      r.lookup("int3")
    }.must_raise BinData::UnRegisteredTypeError
    lambda {
      r.lookup("int3", :big)
    }.must_raise BinData::UnRegisteredTypeError
    lambda {
      r.lookup("int3", :little)
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "lookup floats with endian" do
    r.lookup("float", :big).to_s.must_equal "BinData::FloatBe"
    r.lookup("float", :little).to_s.must_equal "BinData::FloatLe"
    r.lookup("double", :big).to_s.must_equal "BinData::DoubleBe"
    r.lookup("double", :little).to_s.must_equal "BinData::DoubleLe"
  end

  it "lookup bits" do
    r.lookup("bit5").to_s.must_equal "BinData::Bit5"
    r.lookup("bit6le").to_s.must_equal "BinData::Bit6le"
  end

  it "lookup bits by ignoring endian" do
    r.lookup("bit2", :big).to_s.must_equal "BinData::Bit2"
    r.lookup("bit3le", :big).to_s.must_equal "BinData::Bit3le"
    r.lookup("bit2", :little).to_s.must_equal "BinData::Bit2"
    r.lookup("bit3le", :little).to_s.must_equal "BinData::Bit3le"
  end

  it "lookup custom types with endian" do
    fields = [
      [:uint32, :x],
      [:uint32, :y],
      [:uint32, :z],
    ]
    BinData::Struct.new(
      name: :vector_le,
      endian: :little,
      fields: fields
    )
    BinData::Struct.new(
      name: :vector_be,
      endian: :big,
      fields: fields
    )
    BinData::Struct.new(
      endian: :little,
      fields: [[:vector, :position]]
    )
    BinData::Struct.new(
      endian: :big,
      fields: [[:vector, :position]]
    )
  end
end
