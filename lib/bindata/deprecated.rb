# Implement Kernel#instance_exec for Ruby 1.8.6 and below
unless Object.respond_to? :instance_exec
  module Kernel
    # Taken from http://eigenclass.org/hiki/instance_exec
    def instance_exec(*args, &block)
      mname = "__instance_exec_#{Thread.current.object_id.abs}_#{object_id.abs}"
      Object.class_eval{ define_method(mname, &block) }
      begin
        ret = send(mname, *args)
      ensure
        Object.class_eval{ undef_method(mname) } rescue nil
      end
      ret
    end
  end
end

module BinData
  class Base

    alias_method :initialize_without_deprecation, :initialize
    def initialize_with_deprecation(*args)
      owner = method(:initialize).owner
      if owner != BinData::Base
        fail "implementing #initialize on #{owner} is not allowed.\nEither downgrade to BinData 1.2.2, or rename #initialize to #initialize_instance."
      end
      initialize_without_deprecation(*args)
    end
    alias_method :initialize, :initialize_with_deprecation

    def initialize_instance(*args)
      unless args.empty?
        warn "#{caller[0]} remove the call to super in #initialize_instance"
      end
    end

    class << self
      def register_self
        warn "#{caller[0]} `register_self' is no longer needed as of BinData 1.3.2.  You can delete this line"
      end

      def register(name, class_to_register)
        warn "#{caller[0]} `register' is no longer needed as of BinData 1.3.2.  You can delete this line"
      end
    end

    def _do_read(io)
      warn "#{caller[0]} `_do_read(io)' is deprecated as of BinData 1.3.0.  Replace with `do_read(io)'"
      do_read(io)
    end

    def _do_write(io)
      warn "#{caller[0]} `_do_write(io)' is deprecated as of BinData 1.3.0.  Replace with `do_write(io)'"
      do_write(io)
    end

    def _do_num_bytes
      warn "#{caller[0]} `_do_num_bytes' is deprecated as of BinData 1.3.0.  Replace with `do_num_bytes'"
      do_num_bytes
    end

    def _assign(val)
      warn "#{caller[0]} `_assign(val)' is deprecated as of BinData 1.3.0.  Replace with `assign(val)'"
      assign(val)
    end

    def _snapshot
      warn "#{caller[0]} `_snapshot' is deprecated as of BinData 1.3.0.  Replace with `snapshot'"
      snapshot
    end
  end

  class SingleValue
    class << self
      def inherited(subclass) #:nodoc:
        fail "BinData::SingleValue is deprecated.  Downgrade to BinData 0.11.1.\nYou will need to make changes to your code before you can use BinData >= 1.0.0"
      end
    end
  end

  class MultiValue
    class << self
      def inherited(subclass) #:nodoc:
        fail "BinData::MultiValue is deprecated.  Downgrade to BinData 0.11.1.\nYou will need to make changes to your code before you can use BinData >= 1.0.0"
      end
    end
  end
end
