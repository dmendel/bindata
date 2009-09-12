require 'bindata/base_primitive'

module BinData
  # Defines a number of classes that contain a floating point number.
  # The float is defined by precision and endian.

  module FloatingPoint #:nodoc: all
    def self.create_float_methods(float_class, precision, endian)
      read = create_read_code(precision, endian)
      to_binary_s = create_to_binary_s_code(precision, endian)
      nbytes = (precision == :single) ? 4 : 8

      define_methods(float_class, nbytes, read, to_binary_s)
    end

    def self.create_read_code(precision, endian)
      if precision == :single
        unpack = (endian == :little) ? 'e' : 'g'
        nbytes = 4
      else # double_precision
        unpack = (endian == :little) ? 'E' : 'G'
        nbytes = 8
      end

      "io.readbytes(#{nbytes}).unpack('#{unpack}').at(0)"
    end

    def self.create_to_binary_s_code(precision, endian)
      if precision == :single
        pack = (endian == :little) ? 'e' : 'g'
      else # double_precision
        pack = (endian == :little) ? 'E' : 'G'
      end

      "[val].pack('#{pack}')"
    end

    def self.define_methods(float_class, nbytes, read, to_binary_s)
      float_class.module_eval <<-END
        def _do_num_bytes
          #{nbytes}
        end

        #---------------
        private

        def sensible_default
          0.0
        end

        def value_to_binary_string(val)
          #{to_binary_s}
        end

        def read_and_return_value(io)
          #{read}
        end
      END
    end
  end


  # Single precision floating point number in little endian format
  class FloatLe < BinData::BasePrimitive
    register(self.name, self)
    FloatingPoint.create_float_methods(self, :single, :little)
  end

  # Single precision floating point number in big endian format
  class FloatBe < BinData::BasePrimitive
    register(self.name, self)
    FloatingPoint.create_float_methods(self, :single, :big)
  end

  # Double precision floating point number in little endian format
  class DoubleLe < BinData::BasePrimitive
    register(self.name, self)
    FloatingPoint.create_float_methods(self, :double, :little)
  end

  # Double precision floating point number in big endian format
  class DoubleBe < BinData::BasePrimitive
    register(self.name, self)
    FloatingPoint.create_float_methods(self, :double, :big)
  end
end
