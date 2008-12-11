require 'bindata/single'

module BinData
  # Provides a number of classes that contain an integer.  The integer
  # is defined by endian, signedness and number of bytes.

  module Integer #:nodoc: all
    def self.define_class(nbits, endian, signed)
      endian_str = (endian == :big) ? "be" : "le"
      name = (signed ? "Int" : "Uint") + nbits.to_s + endian_str
      creation_method = signed ? "create_int_methods" : "create_uint_methods"
      BinData.module_eval <<-END
        class #{name} < BinData::Single
          register(self.name, self)
          Integer.#{creation_method}(self, #{nbits}, :#{endian.to_s})
        end
      END
    end

    def self.create_int_methods(int_class, nbits, endian)
      max = (1 << (nbits - 1)) - 1
      min = -(max + 1)

      clamp = create_clamp_code(min, max)
      read = create_read_code(nbits, endian)
      to_s = create_to_s_code(nbits, endian)

      int2uint = "val = val & #{(1 << nbits) - 1}"
      uint2int = "val = ((val & #{1 << (nbits - 1)}).zero?) ? " +
                 "val & #{max} : -(((~val) & #{max}) + 1)"

      define_methods(int_class, nbits / 8, clamp, read, to_s, int2uint, uint2int)
    end

    def self.create_uint_methods(int_class, nbits, endian)
      min = 0
      max = (1 << nbits) - 1

      clamp = create_clamp_code(min, max)
      read = create_read_code(nbits, endian)
      to_s = create_to_s_code(nbits, endian)

      define_methods(int_class, nbits / 8, clamp, read, to_s)
    end

    def self.create_clamp_code(min, max)
      "val = (val < #{min}) ? #{min} : (val > #{max}) ? #{max} : val"
    end

    def self.create_read_code(nbits, endian)
      raise "nbits must be divisible by 8" unless (nbits % 8).zero?

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

    def self.create_to_s_code(nbits, endian)
      raise "nbits must be divisible by 8" unless (nbits % 8).zero?

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

    def self.define_methods(int_class, nbytes, clamp, read, to_s,
                            int2uint = nil, uint2int = nil)
      int_class.module_eval <<-END
        def value=(val)
          #{clamp}
          super(val)
        end

        def _do_num_bytes(ignored)
          #{nbytes}
        end

        #---------------
        private

        def sensible_default
          0
        end

        def val_to_str(val)
          #{clamp}
          #{int2uint unless int2uint.nil?}
          #{to_s}
        end

        def read_val(io)
          val = #{read}
          #{uint2int unless uint2int.nil?}
        end
      END
    end
  end


  # Unsigned 1 byte integer.
  class Uint8 < BinData::Single
    register(self.name, self)
    Integer.create_uint_methods(self, 8, :little)
  end

  # Signed 1 byte integer.
  class Int8 < BinData::Single
    register(self.name, self)
    Integer.create_int_methods(self, 8, :little)
  end

  # Create commonly used integers
  [8, 16, 32, 64, 128].each do |nbits|
    Integer.define_class(nbits, :little, false)
    Integer.define_class(nbits, :little, true)
    Integer.define_class(nbits, :big, false)
    Integer.define_class(nbits, :big, true)
  end
end
