require 'bindata/base_primitive'

module BinData
  # Defines a number of classes that contain a bit based integer.
  # The integer is defined by endian and number of bits.

  module BitField #:nodoc: all
    def self.define_class(nbits, endian)
      name = "Bit#{nbits}"
      name += "le" if endian == :little
      unless BinData.const_defined?(name)
        BinData.module_eval <<-END
          class #{name} < BinData::BasePrimitive
            register(self.name, self)
            BitField.create_methods(self, #{nbits}, :#{endian.to_s})
          end
        END
      end
      BinData.const_get(name)
    end

    def self.create_methods(bit_class, nbits, endian)
      min = 0
      max = (1 << nbits) - 1
      clamp = "val = (val < #{min}) ? #{min} : (val > #{max}) ? #{max} : val"

      # allow single bits to be used as booleans
      if nbits == 1
        clamp = "val = (val == true) ? 1 : (not val) ? 0 : #{clamp}"
      end

      define_methods(bit_class, nbits, endian.to_s, clamp)
    end

    def self.define_methods(bit_class, nbits, endian, clamp)
      bit_class.module_eval <<-END
        #---------------
        private

        def _assign(val)
          #{clamp}
          super(val)
        end

        def _do_write(io)
          raise "can't write whilst reading \#{debug_name}" if @in_read
          io.writebits(_value, #{nbits}, :#{endian})
        end

        def _do_num_bytes
          #{nbits / 8.0}
        end

        def read_and_return_value(io)
          io.readbits(#{nbits}, :#{endian})
        end

        def sensible_default
          0
        end
      END
    end
  end

  # Create classes on demand
  class << self
    alias_method :const_missing_without_bits, :const_missing
    def const_missing_with_bits(name)
      name = name.to_s
      mappings = {
        /^Bit(\d+)$/ => :big,
        /^Bit(\d+)le$/ => :little
      }

      mappings.each_pair do |regex, endian|
        if regex =~ name
          nbits = $1.to_i
          return BitField.define_class(nbits, endian)
        end
      end

      const_missing_without_bits(name)
    end
    alias_method :const_missing, :const_missing_with_bits
  end
end
