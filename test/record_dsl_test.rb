#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "common"))

describe BinData::DSLMixin do
  it "supports record" do
    Class.new BinData::Record do
      endian :little
      record :uint32, :radius
      struct :position do
        record :uint32, :x
        record :uint32, :y
        record :uint32, :z
      end
    end
  end

  it "supports record for arrays" do
    Class.new BinData::Record do
      endian :little
      uint32 :radius
      record :array, :position, initial_length: 3 do
        uint8
      end
    end
  end

  it "supports record with class references" do
    vector = Class.new BinData::Record do
      endian :little
      uint32 :x
      uint32 :y
      uint32 :z
    end

    Class.new BinData::Record do
      endian :little
      uint32 :radius
      record vector, :position
    end
  end
end
