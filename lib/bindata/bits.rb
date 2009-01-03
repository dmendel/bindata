require 'bindata/single'

module BinData
  # Defines a number of classes that contain a bit based integer.
  # The integer is defined by endian and number of bits.

  module BitField #:nodoc: all
    def self.define_class(nbits, endian)
      name = "Bit#{nbits}"
      name += "le" if endian == :little

      BinData.module_eval <<-END
        class #{name} < BinData::Single
          register(self.name, self)
          BitField.create_methods(self, #{nbits}, :#{endian.to_s})
        end
      END
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
        def value=(val)
          #{clamp}
          super(val)
        end

        #---------------
        private

        def _do_write(io)
          raise "can't write whilst reading \#{debug_name}" if @in_read
          io.writebits(_value, #{nbits}, :#{endian})
        end

        def _do_num_bytes(ignored)
          #{nbits} / 8.0
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

  # Create commonly used bit based integers
  (1 .. 63).each do |nbits|
    BitField.define_class(nbits, :little)
    BitField.define_class(nbits, :big)
  end
end
