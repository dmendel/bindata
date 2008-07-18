#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata/bits'

describe "Bits of size 1" do
  it "should accept true as value" do
    obj = BinData::Bit1.new
    obj.value = true
    obj.value.should == 1

    obj = BinData::Bit1le.new
    obj.value = true
    obj.value.should == 1
  end

  it "should accept false as value" do
    obj = BinData::Bit1.new
    obj.value = false
    obj.value.should == 0

    obj = BinData::Bit1le.new
    obj.value = false
    obj.value.should == 0
  end

  it "should accept nil as value" do
    obj = BinData::Bit1.new
    obj.value = nil
    obj.value.should == 0

    obj = BinData::Bit1le.new
    obj.value = nil
    obj.value.should == 0
  end
end

describe "All bitfields" do
  it "should have a sensible value of zero" do
    begin
      nbits = 1
      loop do
        ["", "le"].each do |suffix|
          klass = BinData.const_get("Bit#{nbits}#{suffix}")
          klass.new.value.should be_zero
        end

        nbits += 1
      end
    rescue NameError
    end
  end

  it "should clamp " do
    begin
      nbits = 1
      loop do
        ["", "le"].each do |suffix|
          klass = BinData.const_get("Bit#{nbits}#{suffix}")
          obj = klass.new

          obj.value = -1
          obj.value.should == 0

          obj.value = 1 << nbits
          obj.value.should == ((1 << nbits) - 1)
        end

        nbits += 1
      end
    rescue NameError
    end
  end

  it "should read big endian value" do
    begin
      nbits = 1
      loop do
        klass = BinData.const_get("Bit#{nbits}")
        obj = klass.new

        str = [0b1000_0000].pack("C") + "\000" * (nbits / 8)
        obj.read(str)
        obj.value.should == 1 << (nbits - 1)

        nbits += 1
      end
    rescue NameError
    end
  end

  it "should read little endian value" do
    begin
      nbits = 1
      loop do
        klass = BinData.const_get("Bit#{nbits}le")
        obj = klass.new

        str = [0b0000_0001].pack("C") + "\000" * (nbits / 8)
        obj.read(str)
        obj.value.should == 1

        nbits += 1
      end
    rescue NameError
    end
  end

  it "should read written values" do
    begin
      nbits = 1
      loop do
        ["", "le"].each do |suffix|
          klass = BinData.const_get("Bit#{nbits}#{suffix}")

          min = 0
          max = (1 << nbits) - 1
          range = (min .. max)

          values = []
          values << (min + 1) if range.include?(min + 1)
          values << (min + 3) if range.include?(min + 3)
          values << (max - 1) if range.include?(max - 1)

          values.each do |val|
            obj = klass.new
            obj.value = val
            str = obj.to_s
            obj.read(str)
            obj.value.should == val
          end
        end

        nbits += 1
      end
    rescue NameError
    end
  end
end
