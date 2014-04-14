require 'bindata/base_primitive'

module BinData
  # Defines a number of classes that contain an integer.  The integer
  # is defined by endian, signedness and number of bytes.

  module Int #:nodoc: all
    class << self
      def define_class(name, nbits, endian, signed)
        unless BinData.const_defined?(name)
          BinData.module_eval <<-END
            class #{name} < BinData::BasePrimitive
              Int.define_methods(self, #{nbits}, :#{endian}, :#{signed})
            end
          END
        end

        BinData.const_get(name)
      end

      def define_methods(int_class, nbits, endian, signed)
        raise "nbits must be divisible by 8" unless (nbits % 8).zero?

        int_class.module_eval <<-END
          def assign(val)
            #{create_clamp_code(nbits, signed)}
            super(val)
          end

          def do_num_bytes
            #{nbits / 8}
          end

          #---------------
          private

          def sensible_default
            0
          end

          def value_to_binary_string(val)
            #{create_clamp_code(nbits, signed)}
            #{create_to_binary_s_code(nbits, endian, signed)}
          end

          def read_and_return_value(io)
            #{create_read_code(nbits, endian, signed)}
          end
        END
      end

      #-------------
      private

      def create_clamp_code(nbits, signed)
        if signed == :signed
          max = (1 << (nbits - 1)) - 1
          min = -(max + 1)
        else
          max = (1 << nbits) - 1
          min = 0
        end

        "val = (val < #{min}) ? #{min} : (val > #{max}) ? #{max} : val"
      end

      def create_read_code(nbits, endian, signed)
        unpack_str   = create_read_unpack_code(nbits, endian, signed)
        assemble_str = create_read_assemble_code(nbits, endian, signed)

        read_str = "(#{unpack_str} ; #{assemble_str})"

        if need_conversion_code?(nbits, signed)
          "val = #{read_str} ; #{create_uint2int_code(nbits)}"
        else
          read_str
        end
      end

      def create_read_unpack_code(nbits, endian, signed)
        nbytes = nbits / 8

        "ints = io.readbytes(#{nbytes}).unpack('#{pack_directive(nbits, endian, signed)}')"
      end

      def create_read_assemble_code(nbits, endian, signed)
        bits_per_word = bytes_per_word(nbits) * 8
        nwords        = nbits / bits_per_word

        idx = (0 ... nwords).to_a
        idx.reverse! if (endian == :big)

        parts = (0 ... nwords).collect do |i|
                  if i.zero?
                    "ints.at(#{idx[i]})"
                  else
                    "(ints.at(#{idx[i]}) << #{bits_per_word * i})"
                  end
                end

        assemble_str = parts.join(" + ")
      end

      def create_to_binary_s_code(nbits, endian, signed)
        # special case 8bit integers for speed
        return "(val & 0xff).chr" if nbits == 8

        bits_per_word = bytes_per_word(nbits) * 8
        nwords        = nbits / bits_per_word
        mask          = (1 << bits_per_word) - 1

        vals = (0 ... nwords).collect do |i|
                 i.zero? ? "val" : "val >> #{bits_per_word * i}"
               end
        vals.reverse! if (endian == :big)

        array_str = "[" + vals.collect { |val| "#{val} & #{mask}" }.join(", ") + "]" # TODO: "& mask" is needed to work around jruby bug
        pack_str  = "#{array_str}.pack('#{pack_directive(nbits, endian, signed)}')"

        if need_conversion_code?(nbits, signed)
          "#{create_int2uint_code(nbits)} ; #{pack_str}"
        else
          pack_str
        end
      end

      def create_int2uint_code(nbits)
        "val &= #{(1 << nbits) - 1}"
      end

      def create_uint2int_code(nbits)
        "(val >= #{1 << (nbits - 1)}) ? val - #{1 << nbits} : val"
      end

      def bytes_per_word(nbits)
        (nbits % 64).zero? ? 8 :
        (nbits % 32).zero? ? 4 :
        (nbits % 16).zero? ? 2 :
                             1
      end

      def pack_directive(nbits, endian, signed)
        bits_per_word = bytes_per_word(nbits) * 8
        nwords        = nbits / bits_per_word

        if (nbits % 64).zero?
          d = (endian == :big) ? 'Q>' : 'Q<'
        elsif (nbits % 32).zero?
          d = (endian == :big) ? 'L>' : 'L<'
        elsif (nbits % 16).zero?
          d = (endian == :big) ? 'S>' : 'S<'
        else
          d = 'C'
        end

        if pack_directive_signed?(nbits, signed)
          (d * nwords).downcase
        else
          d * nwords
        end
      end

      def need_conversion_code?(nbits, signed)
        signed == :signed and not pack_directive_signed?(nbits, signed)
      end

      def pack_directive_signed?(nbits, signed)
        signed == :signed and [64, 32, 16, 8].include?(nbits)
      end
    end
  end


  # Unsigned 1 byte integer.
  class Uint8 < BinData::BasePrimitive
    Int.define_methods(self, 8, :little, :unsigned)
  end

  # Signed 1 byte integer.
  class Int8 < BinData::BasePrimitive
    Int.define_methods(self, 8, :little, :signed)
  end

  # Create classes on demand
  module IntFactory
    def const_missing(name)
      mappings = {
        /^Uint(\d+)be$/ => [:big,    :unsigned],
        /^Uint(\d+)le$/ => [:little, :unsigned],
        /^Int(\d+)be$/  => [:big,    :signed],
        /^Int(\d+)le$/  => [:little, :signed],
      }

      mappings.each_pair do |regex, args|
        if regex =~ name.to_s
          nbits = $1.to_i
          if (nbits % 8).zero?
            return Int.define_class(name, nbits, *args)
          end
        end
      end

      super
    end
  end
  BinData.extend IntFactory
end
