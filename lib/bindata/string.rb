require "bindata/base_primitive"

module BinData
  # A String is a sequence of bytes.  This is the same as strings in Ruby 1.8.
  # The issue of character encoding is ignored by this class.
  #
  #   require 'bindata'
  #
  #   data = "abcdefghij"
  #
  #   obj = BinData::String.new(:read_length => 5)
  #   obj.read(data)
  #   obj #=> "abcde"
  #
  #   obj = BinData::String.new(:length => 6)
  #   obj.read(data)
  #   obj #=> "abcdef"
  #   obj.assign("abcdefghij")
  #   obj #=> "abcdef"
  #   obj.assign("abcd")
  #   obj #=> "abcd\000\000"
  #
  #   obj = BinData::String.new(:length => 6, :trim_padding => true)
  #   obj.assign("abcd")
  #   obj #=> "abcd"
  #   obj.to_binary_s #=> "abcd\000\000"
  #
  #   obj = BinData::String.new(:length => 6, :pad_byte => 'A')
  #   obj.assign("abcd")
  #   obj #=> "abcdAA"
  #   obj.to_binary_s #=> "abcdAA"
  #
  # == Parameters
  #
  # String objects accept all the params that BinData::BasePrimitive
  # does, as well as the following:
  #
  # <tt>:read_length</tt>::    The length in bytes to use when reading a value.
  # <tt>:length</tt>::         The fixed length of the string.  If a shorter
  #                            string is set, it will be padded to this length.
  # <tt>:pad_byte</tt>::       The byte to use when padding a string to a
  #                            set length.  Valid values are Integers and
  #                            Strings of length 1.  "\0" is the default.
  # <tt>:pad_front</tt>::      Signifies that the padding occurs at the front
  #                            of the string rather than the end.  Default
  #                            is false.
  # <tt>:trim_padding</tt>::   Boolean, default false.  If set, #value will
  #                            return the value with all pad_bytes trimmed
  #                            from the end of the string.  The value will
  #                            not be trimmed when writing.
  class String < BinData::BasePrimitive

    optional_parameters :read_length, :length, :trim_padding, :pad_front, :pad_left
    default_parameters  :pad_byte => "\0"
    mutually_exclusive_parameters :read_length, :length
    mutually_exclusive_parameters :length, :value

    class << self

      def sanitize_parameters!(params) #:nodoc:
        params.warn_replacement_parameter(:initial_length, :read_length)

        params.warn_renamed_parameter(:pad_char, :pad_byte) # Remove this line in the future

        if params.has_parameter?(:pad_left)
          params[:pad_front] = params.delete(:pad_left)
        end

        if params.has_parameter?(:pad_byte)
          byte = params[:pad_byte]
          params[:pad_byte] = sanitized_pad_byte(byte)
        end
      end

      #-------------
      private

      def sanitized_pad_byte(byte)
        result = byte.is_a?(Integer) ? byte.chr : byte.to_s
        len = result.respond_to?(:bytesize) ? result.bytesize : result.length
        if len > 1
          raise ArgumentError, ":pad_byte must not contain more than 1 byte"
        end
        result
      end
    end

    def assign(val)
      super(binary_string(val))
    end

    def snapshot
      # override to trim padding
      result = super
      result = clamp_to_length(result)

      if get_parameter(:trim_padding)
        result = trim_padding(result)
      end
      result
    end

    #---------------
    private

    def clamp_to_length(str)
      str = binary_string(str)

      len = eval_parameter(:length) || str.length
      if str.length == len
        str
      elsif str.length > len
        str.slice(0, len)
      else
        padding = (eval_parameter(:pad_byte) * (len - str.length))
        if get_parameter(:pad_front)
          padding + str
        else
          str + padding
        end
      end
    end

    def trim_padding(str)
      if get_parameter(:pad_front)
        str.sub(/\A#{eval_parameter(:pad_byte)}*/, "")
      else
        str.sub(/#{eval_parameter(:pad_byte)}*\z/, "")
      end
    end

    def value_to_binary_string(val)
      clamp_to_length(val)
    end

    def read_and_return_value(io)
      len = eval_parameter(:read_length) || eval_parameter(:length) || 0
      io.readbytes(len)
    end

    def sensible_default
      ""
    end
  end
end
