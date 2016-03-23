require "bindata/base_primitive"

module BinData
  # Skip will skip over bytes from the input stream.  If the stream is not
  # seekable, then the bytes are consumed and discarded.
  #
  # When writing, skip will write the appropriate number of zero bytes.
  #
  #   require 'bindata'
  #
  #   class A < BinData::Record
  #     skip :length => 5
  #     string :a, :read_length => 5
  #   end
  #
  #   obj = A.read("abcdefghij")
  #   obj.a #=> "fghij"
  #
  # == Parameters
  #
  # Skip objects accept all the params that BinData::BasePrimitive
  # does, as well as the following:
  #
  # <tt>:length</tt>::        The number of bytes to skip.
  # <tt>:to_abs_offset</tt>:: Skips to the given absolute offset.
  #
  class Skip < BinData::BasePrimitive

    arg_processor :skip

    optional_parameters :length, :to_abs_offset
    mutually_exclusive_parameters :length, :to_abs_offset

    def initialize_shared_instance
      extend SkipLengthPlugin      if has_parameter?(:length)
      extend SkipToAbsOffsetPlugin if has_parameter?(:to_abs_offset)
      super
    end

    #---------------
    private

    def value_to_binary_string(val)
      len = skip_length
      if len < 0
        raise ValidityError, "#{debug_name} attempted to seek backwards by #{len.abs} bytes"
      end

      "\000" * skip_length
    end

    def read_and_return_value(io)
      len = skip_length
      if len < 0
        raise ValidityError, "#{debug_name} attempted to seek backwards by #{len.abs} bytes"
      end

      io.seekbytes(len)
      ""
    end

    def sensible_default
      ""
    end
  end

  class SkipArgProcessor < BaseArgProcessor
    def sanitize_parameters!(obj_class, params)
      unless (params.has_parameter?(:length) or params.has_parameter?(:to_abs_offset))
        raise ArgumentError, "#{obj_class} requires either :length or :to_abs_offset"
      end
      params.must_be_integer(:to_abs_offset, :length)
    end
  end

  # Logic for the :length parameter
  module SkipLengthPlugin
    def skip_length
      eval_parameter(:length)
    end
  end

  # Logic for the :to_abs_offset parameter
  module SkipToAbsOffsetPlugin
    def skip_length
      eval_parameter(:to_abs_offset) - abs_offset
    end
  end
end
