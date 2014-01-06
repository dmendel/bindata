require "bindata/base"

module BinData
  # A virtual field is one that is neither read, written nor occupies space.
  # It is used to make assertions or as a convenient label for determining
  # offsets.
  #
  #   require 'bindata'
  #
  #   class A < BinData::Record
  #     string  :a, :read_length => 5
  #     string  :b, :read_length => 5
  #     virtual :c, :assert => lambda { a == b }
  #   end
  #
  #   obj = A.read("abcdeabcde")
  #   obj.a #=> "abcde"
  #   obj.c.offset #=> 10
  #
  #   obj = A.read("abcdeABCDE") #=> BinData::ValidityError: assertion failed for obj.c
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params include those for BinData::Base as well as:
  #
  # [<tt>:assert</tt>]    Raise an error when reading if the value of this
  #                       evaluated parameter is false.
  #
  class Virtual < BinData::Base

    optional_parameter :assert

    def clear?; true; end
    def assign(val); end
    def snapshot; nil; end
    def do_num_bytes; 0; end
    def do_write(io); end

    def do_read(io)
      assert!
    end

    def assert!
      if has_parameter?(:assert) and not eval_parameter(:assert)
        raise ValidityError, "assertion failed for #{debug_name}"
      end
    end
  end
end
