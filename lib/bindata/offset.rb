module BinData
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These parameters are:
  #
  # [<tt>:check_offset</tt>]  Raise an error if the current IO offset doesn't
  #                           meet this criteria.  A boolean return indicates
  #                           success or failure.  Any other return is compared
  #                           to the current offset.  The variable +offset+
  #                           is made available to any lambda assigned to
  #                           this parameter.  This parameter is only checked
  #                           before reading.
  # [<tt>:adjust_offset</tt>] Ensures that the current IO offset is at this
  #                           position before reading.  This is like
  #                           <tt>:check_offset</tt>, except that it will
  #                           adjust the IO offset instead of raising an error.
  module CheckOrAdjustOffsetMixin

    def self.included(base) #:nodoc:
      base.optional_parameters :check_offset, :adjust_offset
      base.mutually_exclusive_parameters :check_offset, :adjust_offset
    end

    # Ideally these two methods should be protected,
    # but Ruby 1.9.2 requires them to be public.
    # see http://redmine.ruby-lang.org/issues/show/2375

    def do_read_with_check_offset(io) #:nodoc:
      check_offset(io)
      do_read_without_check_offset(io)
    end

    def do_read_with_adjust_offset(io) #:nodoc:
      adjust_offset(io)
      do_read_without_adjust_offset(io)
    end

    #---------------
    private

    # To be called from BinData::Base#initialize.
    #
    # Monkey patches #do_read to check or adjust the stream offset
    # as appropriate.
    def add_methods_for_check_or_adjust_offset
      if has_parameter?(:check_offset)
        class << self
          alias_method :do_read_without_check_offset, :do_read
          alias_method :do_read, :do_read_with_check_offset
        end
      end
      if has_parameter?(:adjust_offset)
        class << self
          alias_method :do_read_without_adjust_offset, :do_read
          alias_method :do_read, :do_read_with_adjust_offset
        end
      end
    end

    def check_offset(io)
      actual_offset = io.offset
      expected = eval_parameter(:check_offset, :offset => actual_offset)

      if not expected
        raise ValidityError, "offset not as expected for #{debug_name}"
      elsif actual_offset != expected and expected != true
        raise ValidityError,
              "offset is '#{actual_offset}' but " +
              "expected '#{expected}' for #{debug_name}"
      end
    end

    def adjust_offset(io)
      actual_offset = io.offset
      expected = eval_parameter(:adjust_offset)
      if actual_offset != expected
        begin
          seek = expected - actual_offset
          io.seekbytes(seek)
          warn "adjusting stream position by #{seek} bytes" if $VERBOSE
        rescue
          raise ValidityError,
                "offset is '#{actual_offset}' but couldn't seek to " +
                "expected '#{expected}' for #{debug_name}"
        end
      end
    end
  end
end

