module BinData
  class SingleValue
    class << self
      def inherited(subclass) #:nodoc:
        fail "BinData::SingleValue is deprecated.  Downgrade to BinData 0.11.1.\nYou will need to make changes to your code before you can use BinData 1.0.0"
      end
    end
  end

  class MultiValue
    class << self
      def inherited(subclass) #:nodoc:
        fail "BinData::MultiValue is deprecated.  Downgrade to BinData 0.11.1.\nYou will need to make changes to your code before you can use BinData 1.0.0"
      end
    end
  end
end
