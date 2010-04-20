require 'bindata/base_primitive'

module BinData
  # Defines a number of classes that contain an integer.  The integer
  # is defined by endian, signedness and number of bytes.

  module Int #:nodoc: all
    class << self
      def define_class(nbits, endian, signed)
        name = class_name(nbits, endian, signed)
        unless BinData.const_defined?(name)
          int_type = (signed == :signed) ? 'int' : 'uint'
          creation_method = "create_#{int_type}_methods"

          BinData.module_eval <<-END
            class #{name} < BinData::BasePrimitive
              register_self
              Int.#{creation_method}(self, #{nbits}, :#{endian})
            end
          END
        end
        BinData.const_get(name)
      end

      def class_name(nbits, endian, signed)
        endian_str = (endian == :big) ? "be" : "le"
        base = (signed == :signed) ? "Int" : "Uint"

        "#{base}#{nbits}#{endian_str}"
      end

      def create_uint_methods(int_class, nbits, endian)
        raise "nbits must be divisible by 8" unless (nbits % 8).zero?

        min = 0
        max = (1 << nbits) - 1

        clamp = create_clamp_code(min, max)
        read = create_read_code(nbits, endian)
        to_binary_s = create_to_binary_s_code(nbits, endian)

        define_methods(int_class, nbits / 8, clamp, read, to_binary_s)
      end

      def create_int_methods(int_class, nbits, endian)
        raise "nbits must be divisible by 8" unless (nbits % 8).zero?

        max = (1 << (nbits - 1)) - 1
        min = -(max + 1)

        clamp = create_clamp_code(min, max)
        read = create_read_code(nbits, endian)
        to_binary_s = create_to_binary_s_code(nbits, endian)

        int2uint = create_int2uint_code(nbits)
        uint2int = create_uint2int_code(nbits)

        define_methods(int_class, nbits / 8, clamp, read, to_binary_s,
                         int2uint, uint2int)
      end

      def create_clamp_code(min, max)
        "val = (val < #{min}) ? #{min} : (val > #{max}) ? #{max} : val"
      end

      def create_int2uint_code(nbits)
        "val = val & #{(1 << nbits) - 1}"
      end

      def create_uint2int_code(nbits)
        mask = (1 << (nbits - 1)) - 1

        "val = ((val & #{1 << (nbits - 1)}).zero?) ? " +
                 "val & #{mask} : -(((~val) & #{mask}) + 1)"
      end

      def create_read_code(nbits, endian)
        # determine "word" size and unpack directive
        if (nbits % 32).zero?
          bytes_per_word = 4
          d = (endian == :big) ? 'N' : 'V'
        elsif (nbits % 16).zero?
          bytes_per_word = 2
          d = (endian == :big) ? 'n' : 'v'
        else
          bytes_per_word = 1
          d = 'C'
        end

        bits_per_word = bytes_per_word * 8
        nwords        = nbits / bits_per_word
        nbytes        = nbits / 8

        idx = (0 ... nwords).to_a
        idx.reverse! if (endian == :big)

        unpack_str = "a = io.readbytes(#{nbytes}).unpack('#{d * nwords}')"

        parts = (0 ... nwords).collect do |i|
                  i.zero? ? "a.at(#{idx[i]})" :
                            "(a.at(#{idx[i]}) << #{bits_per_word * i})"
                end
        assemble_str = parts.join(" + ")

        "(#{unpack_str}; #{assemble_str})"
      end

      def create_to_binary_s_code(nbits, endian)
        # special case 8bit integers for speed
        return "val.chr" if nbits == 8

        # determine "word" size and pack directive
        if (nbits % 32).zero?
          bytes_per_word = 4
          d = (endian == :big) ? 'N' : 'V'
        elsif (nbits % 16).zero?
          bytes_per_word = 2
          d = (endian == :big) ? 'n' : 'v'
        else
          bytes_per_word = 1
          d = 'C'
        end

        bits_per_word = bytes_per_word * 8
        nwords        = nbits / bits_per_word
        mask          = (1 << bits_per_word) - 1

        vals = (0 ... nwords).collect do |i|
                 i.zero? ? "val" : "(val >> #{bits_per_word * i})"
               end
        vals.reverse! if (endian == :big)

        parts = (0 ... nwords).collect { |i| "#{vals[i]} & #{mask}" }
        array_str = "[" + parts.join(", ") + "]"

        "#{array_str}.pack('#{d * nwords}')"
      end

      def define_methods(int_class, nbytes, clamp, read, to_binary_s,
                           int2uint = nil, uint2int = nil)
        int_class.module_eval <<-END
          #---------------
          private

          def _assign(val)
            #{clamp}
            super(val)
          end

          def _do_num_bytes
            #{nbytes}
          end

          def sensible_default
            0
          end

          def value_to_binary_string(val)
            #{clamp}
            #{int2uint unless int2uint.nil?}
            #{to_binary_s}
          end

          def read_and_return_value(io)
            val = #{read}
            #{uint2int unless uint2int.nil?}
          end
        END
      end
    end
  end


  # Unsigned 1 byte integer.
  class Uint8 < BinData::BasePrimitive
    register_self
    Int.create_uint_methods(self, 8, :little)
  end

  # Signed 1 byte integer.
  class Int8 < BinData::BasePrimitive
    register_self
    Int.create_int_methods(self, 8, :little)
  end

  # Create classes on demand
  class << self
    alias_method :const_missing_without_int, :const_missing
    def const_missing_with_int(name)
      name = name.to_s
      mappings = {
        /^Uint(\d+)be$/ => [:big, :unsigned],
        /^Uint(\d+)le$/ => [:little, :unsigned],
        /^Int(\d+)be$/ => [:big, :signed],
        /^Int(\d+)le$/ => [:little, :signed],
      }

      mappings.each_pair do |regex, args|
        if regex =~ name
          nbits = $1.to_i
          if (nbits % 8).zero?
            return Int.define_class(nbits, *args)
          end
        end
      end

      const_missing_without_int(name)
    end
    alias_method :const_missing, :const_missing_with_int
  end
end
