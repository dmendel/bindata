module BinData
  class Base
    class << self
      def register(name, class_to_register)
        if class_to_register == self
          warn "#{caller[0]} `register(name, class_to_register)' is deprecated as of BinData 1.2.0.  Replace with `register_self'"
        elsif /inherited/ =~ caller[0]
          warn "#{caller[0]} `def self.inherited(subclass); register(subclass.name, subclass); end' is deprecated as of BinData 1.2.0.  Replace with `register_subclasses'"
        else
          warn "#{caller[0]} `register(name, class_to_register)' is deprecated as of BinData 1.2.0.  Replace with `register_class(class_to_register)'"
        end
        register_class(class_to_register)
      end
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
