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
  #     skip length: 5
  #     string :a, read_length: 5
  #   end
  #
  #   obj = A.read("abcdefghij")
  #   obj.a #=> "fghij"
  #
  #
  #   class B < BinData::Record
  #     skip until_valid: [:string, {read_length: 2, assert: "ef"} ]
  #     string :b, read_length: 5
  #   end
  #
  #   obj = B.read("abcdefghij")
  #   obj.b #=> "efghi"
  #
  #
  # == Parameters
  #
  # Skip objects accept all the params that BinData::BasePrimitive
  # does, as well as the following:
  #
  # <tt>:length</tt>::        The number of bytes to skip.
  # <tt>:to_abs_offset</tt>:: Skips to the given absolute offset.
  # <tt>:until_valid</tt>::   Skips untils a given byte pattern is matched.
  #                           This parameter contains a type that will raise
  #                           a BinData::ValidityError unless an acceptable byte
  #                           sequence is found.  The type is represented by a
  #                           Symbol, or if the type is to have params #
  #                           passed to it, then it should be provided as #
  #                           <tt>[type_symbol, hash_params]</tt>.
  #
  class Skip < BinData::BasePrimitive
    arg_processor :skip

    optional_parameters :length, :to_abs_offset, :until_valid
    mutually_exclusive_parameters :length, :to_abs_offset, :until_valid

    def initialize_shared_instance
      extend SkipLengthPlugin      if has_parameter?(:length)
      extend SkipToAbsOffsetPlugin if has_parameter?(:to_abs_offset)
      extend SkipUntilValidPlugin  if has_parameter?(:until_valid)
      super
    end

    #---------------
    private

    def value_to_binary_string(_)
      len = skip_length
      if len < 0
        msg = "#{debug_name} attempted to seek backwards by #{len.abs} bytes"
        raise ValidityError, msg
      end

      "\000" * skip_length
    end

    def read_and_return_value(io)
      len = skip_length
      if len < 0
        msg = "#{debug_name} attempted to seek backwards by #{len.abs} bytes"
        raise ValidityError, msg
      end

      io.skipbytes(len)
      ""
    end

    def sensible_default
      ""
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

      def read_and_return_value(io)
        len = skip_length
        if len < 0
          raise ValidityError, "#{debug_name} attempted to seek backwards by #{len.abs} bytes"
        end

        io.seek_to_abs_offset(eval_parameter(:to_abs_offset))
      end
    end

    # Logic for the :until_valid parameter
    module SkipUntilValidPlugin
      def skip_length
        # no skipping when writing
        0
      end

      def read_and_return_value(io)
        prototype = get_parameter(:until_valid)
        validator = prototype.instantiate(nil, self)

        io.transform(ReadaheadIO.new) do |transformed_io, raw_io|
          search = 0
          valid = false
          until valid
            begin
              validator.clear
              validator.do_read(transformed_io)
              valid = true
            rescue ValidityError
              search += 1
            end
            raw_io.rollback
            io.skipbytes(search)
          end
        end
      end

      class ReadaheadIO < BinData::IO::Transform
        def chained(io)
          if !io.seekable?
            raise IOError, "readahead is not supported on unseekable streams"
          end

          @mark = io.offset
          super
        end

        def rollback
          @chain_io.seek_abs(@mark)
        end
      end
    end
  end

  class SkipArgProcessor < BaseArgProcessor
    def sanitize_parameters!(obj_class, params)
      unless params.has_at_least_one_of?(:length, :to_abs_offset, :until_valid)
        raise ArgumentError,
          "#{obj_class} requires either :length, :to_abs_offset or :until_valid"
      end
      params.must_be_integer(:to_abs_offset, :length)
      params.sanitize_object_prototype(:until_valid)
    end
  end
end
