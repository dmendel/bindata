#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "test_helper"))

describe BinData::Registry do
  A = Class.new
  B = Class.new
  C = Class.new
  D = Class.new
  E = Class.new

  let(:r) { BinData::Registry.new }

  it "lookups registered names" do
    r.register("", 'ASubClass', A)
    r.register("", 'AnotherSubClass', B)

    _(r.lookup("", 'ASubClass')).must_equal A
    _(r.lookup("", 'a_sub_class')).must_equal A
    _(r.lookup("", 'AnotherSubClass')).must_equal B
    _(r.lookup("", 'another_sub_class')).must_equal B
  end

  it "does not lookup unregistered names" do
    _ {
      r.lookup("", 'a_non_existent_sub_class')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "unregisters names" do
    r.register("", 'ASubClass', A)
    r.unregister("", 'ASubClass')

    _ {
      r.lookup("", 'ASubClass')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "allows overriding of registered classes" do
    w, $-w = $-w, nil  # disable warning

    begin
      r.register("", 'A', A)
      r.register("", 'A', B)

      _(r.lookup("", 'a')).must_equal B
    ensure
      $-w = w
    end
  end

  it "converts CamelCase to underscores" do
    _(r.underscore_name('CamelCase')).must_equal 'camel_case'
  end

  it "converts adjacent caps camelCase to underscores" do
    _(r.underscore_name('XYZCamelCase')).must_equal 'xyz_camel_case'
  end
end

describe BinData::Registry, "with numerics" do
  let(:r) { BinData::RegisteredClasses }

  it "lookup integers with endian" do
    _(r.lookup("", 'int24', {endian: :big}).to_s).must_equal "BinData::Int24be"
    _(r.lookup("", 'int24', {endian: :little}).to_s).must_equal "BinData::Int24le"
    _(r.lookup("xx", 'uint24', {endian: :big}).to_s).must_equal "BinData::Uint24be"
    _(r.lookup("yy", 'uint24', {endian: :little}).to_s).must_equal "BinData::Uint24le"
  end

  it "does not lookup integers without endian" do
    _ {
      r.lookup("", 'int24')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "provides a nice error message when endian is omitted" do
    begin
      r.lookup("", 'int24')
    rescue BinData::UnRegisteredTypeError => e
      _(e.message).must_equal "int24, do you need to specify endian?"
    end
  end

  it "does not lookup non byte based integers" do
    _ {
      r.lookup("", 'int3')
    }.must_raise BinData::UnRegisteredTypeError
    _ {
      r.lookup("", 'int3', {endian: :big})
    }.must_raise BinData::UnRegisteredTypeError
    _ {
      r.lookup("", 'int3', {endian: :little})
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "lookup floats with endian" do
    _(r.lookup("", 'float', {endian: :big}).to_s).must_equal "BinData::FloatBe"
    _(r.lookup("", 'float', {endian: :little}).to_s).must_equal "BinData::FloatLe"
    _(r.lookup("xx", 'double', {endian: :big}).to_s).must_equal "BinData::DoubleBe"
    _(r.lookup("yy", 'double', {endian: :little}).to_s).must_equal "BinData::DoubleLe"
  end

  it "lookup bits" do
    _(r.lookup("", 'bit5').to_s).must_equal "BinData::Bit5"
    _(r.lookup("", 'sbit5').to_s).must_equal "BinData::Sbit5"
    _(r.lookup("", 'bit6le').to_s).must_equal "BinData::Bit6le"
  end

  it "lookup bits by ignoring endian" do
    _(r.lookup("", 'bit2', {endian: :big}).to_s).must_equal "BinData::Bit2"
    _(r.lookup("", 'bit3le', {endian: :big}).to_s).must_equal "BinData::Bit3le"
    _(r.lookup("", 'bit2', {endian: :little}).to_s).must_equal "BinData::Bit2"
    _(r.lookup("", 'bit3le', {endian: :little}).to_s).must_equal "BinData::Bit3le"
  end

  it "lookup signed bits by ignoring endian" do
    _(r.lookup("", 'sbit2', {endian: :big}).to_s).must_equal "BinData::Sbit2"
    _(r.lookup("", 'sbit3le', {endian: :big}).to_s).must_equal "BinData::Sbit3le"
    _(r.lookup("", 'sbit2', {endian: :little}).to_s).must_equal "BinData::Sbit2"
    _(r.lookup("", 'sbit3le', {endian: :little}).to_s).must_equal "BinData::Sbit3le"
  end
end

describe BinData::Registry, "with endian specific types" do
  let(:r) { BinData::Registry.new }

  before do
    r.register("", 'a_le', A)
    r.register("", 'b_be', B)
  end
  
  it "lookup little endian types" do
    _(r.lookup("", 'a', {endian: :little})).must_equal A
  end

  it "lookup big endian types" do
    _(r.lookup("", 'b', {endian: :big})).must_equal B
  end

  it "does not lookup types with non existent endian" do
    _ {
      r.lookup("", 'a', {endian: :big})
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "lookup prefers exact type" do
    r.register("", 'c', C)
    r.register("", 'c_le', D)

    _(r.lookup("", 'c', {endian: :little})).must_equal C
  end
end

describe BinData::Registry, "with search_namespace" do
  let(:r) { BinData::Registry.new }

  before do
    r.register("", 'a_f', A)
    r.register("", 'b_f', B)
  end

  it "lookup single search_namespace" do
    _(r.lookup("", 'f', {search_namespace: :a})).must_equal A
  end

  it "lookup single search_namespace with endian" do
    _(r.lookup("", 'f', {search_namespace: :a, endian: :little})).must_equal A
  end

  it "lookup multiple search_namespace" do
    _(r.lookup("", 'f', {search_namespace: [:x, :a]})).must_equal A
  end

  it "lookup first match in search_namespace" do
    _(r.lookup("", 'f', {search_namespace: [:a, :b]})).must_equal A
  end
end

describe BinData::Registry, "with namespaces" do
  let(:r) { BinData::Registry.new }

  before do
    r.register('ModA::ModB', 'obj1', A)       # ModA::ModB::Obj1
    r.register('ModA::ModB', 'obj2', B)       # ModA::ModB::Obj2
    r.register('mod_a_mod_b', 'ns1_obj3', C)  # ModA::ModB::Ns1Obj3
    r.register('mod_a_mod_c', 'Obj1', D)      # ModA::ModC::Obj1
    r.register('mod_a_mod_c', 'Obj4', E)      # ModA::ModC::Obj4
  end

  it "lookups inside the namespace" do
    _(r.lookup("mod_a_mod_c", 'obj1')).must_equal D
    _(r.lookup("ModA::ModC", 'obj4')).must_equal E
  end

  it "doesn't lookup inside a different namespace" do
    _ {
      r.lookup("mod_a_mod_c", 'obj2')
    }.must_raise BinData::UnRegisteredTypeError

    _ {
      r.lookup("mod_a", 'obj2')
    }.must_raise BinData::UnRegisteredTypeError

    _ {
      r.lookup("", 'obj2')
    }.must_raise BinData::UnRegisteredTypeError
  end

  it "lookups with relative namespace" do
    _(r.lookup("mod_a_mod_c", 'mod_b_obj1')).must_equal A
    _(r.lookup("mod_a", 'mod_b_obj1')).must_equal A
  end

  it "lookups with absolute namespace" do
    _(r.lookup("mod_a_mod_c", 'mod_a_mod_b_obj1')).must_equal A
    _(r.lookup("", 'mod_a_mod_b_obj1')).must_equal A
  end

  it "lookups with search_namespace" do
    _(r.lookup("mod_a_mod_c", 'obj1', {search_namespace: :mod_b})).must_equal D
    _(r.lookup("mod_a", 'obj1', {search_namespace: :mod_b})).must_equal A
    _(r.lookup("mod_a_mod_c", 'obj2', {search_namespace: :mod_b})).must_equal B
    _(r.lookup("mod_a_mod_c", 'obj2', {search_namespace: :mod_a_mod_b})).must_equal B
    _(r.lookup("", 'obj1', {search_namespace: [:mod_a_mod_b, :mod_a_mod_c]})).must_equal A
    _(r.lookup("", 'obj1', {search_namespace: [:mod_a_mod_c, :mod_a_mod_b]})).must_equal D
  end

  it "lookups with old style search_prefix" do
    _(r.lookup("mod_a_mod_b", 'obj3', {search_prefix: :ns1})).must_equal C
    _(r.lookup("mod_a_mod_c", 'obj3', {search_prefix: :ns1})).must_equal C
    _(r.lookup("", 'obj3', {search_prefix: :ns1})).must_equal C
  end
end
