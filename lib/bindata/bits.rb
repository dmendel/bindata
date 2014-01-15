require 'bindata/base_primitive'

module BinData
  # Defines a number of classes that contain a bit based integer.
  # The integer is defined by endian and number of bits.

  module BitField #:nodoc: all
    class << self
      def define_class(nbits, endian, signed = :unsigned)
        name = ((signed == :signed ) ? "Sbit" : "Bit") + nbits.to_s
        name << "le" if endian == :little
        unless BinData.const_defined?(name)
          BinData.module_eval <<-END
            class #{name} < BinData::BasePrimitive
              BitField.define_methods(self, #{nbits}, :#{endian}, :#{signed})
            end
          END
        end

        BinData.const_get(name)
      end

      def define_methods(bit_class, nbits, endian, signed)
        bit_class.module_eval <<-END
          def assign(val)
            #{create_clamp_code(nbits, signed)}
            super(val)
          end

          def do_write(io)
            val = _value
            #{create_int2uint_code(nbits) if signed == :signed}
            io.writebits(val, #{nbits}, :#{endian})
          end

          def do_num_bytes
            #{nbits / 8.0}
          end

          #---------------
          private

          def read_and_return_value(io)
            val = io.readbits(#{nbits}, :#{endian})
            #{create_uint2int_code(nbits) if signed == :signed}
            val
          end

          def sensible_default
            0
          end
        END
      end

      def create_clamp_code(nbits, signed)
        if nbits == 1 and signed == :signed
          raise "signed bitfield must have more than one bit" 
        end

        if signed == :signed
          max = (1 << (nbits - 1)) - 1
          min = -(max + 1)
        else
          min = 0
          max = (1 << nbits) - 1
        end

        clamp = "(val < #{min}) ? #{min} : (val > #{max}) ? #{max} : val"

        if nbits == 1
          # allow single bits to be used as booleans
          clamp = "(val == true) ? 1 : (not val) ? 0 : #{clamp}"
        end

        "val = #{clamp}"
      end

      def create_int2uint_code(nbits)
        "val = val & #{(1 << nbits) - 1}"
      end

      def create_uint2int_code(nbits)
        "val = val - #{1 << nbits} if (val >= #{1 << (nbits - 1)})"
      end
    end
  end

  # Create classes on demand
  module BitFieldFactory
    def const_missing(name)
      mappings = {
        /^Bit(\d+)$/ => :big,
        /^Bit(\d+)le$/ => :little,
        /^Sbit(\d+)$/ => [:big, :signed],
        /^Sbit(\d+)le$/ => [:little, :signed]
      }

      mappings.each_pair do |regex, args|
        if regex =~ name.to_s
          nbits = $1.to_i
          return BitField.define_class(nbits, *args)
        end
      end

      super(name)
    end
  end
  BinData.extend BitFieldFactory
end
