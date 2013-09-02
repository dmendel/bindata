require "bindata/base_primitive"

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
  class Virtual < BinData::BasePrimitive

    default_parameter :onlyif => false

    class << self
      def sanitize_parameters!(params) #:nodoc:
        if params.has_parameter?(:asserted_value)
          fail ":asserted_value can not be used on virtual field"
        end
      end
    end

    #---------------
    private

    def value_to_binary_string(val)
      ""
    end

    def read_and_return_value(io)
      ""
    end

    def sensible_default
      ""
    end
  end
end
