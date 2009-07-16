module BinData
  class Base
    def single_value?
      warn "#single_value? is deprecated.  It should no longer be needed"
      false
    end
  end

  class SingleValue < Primitive
    class << self
      def inherited(subclass) #:nodoc:
        warn "BinData::SingleValue is deprecated.  Replacing with BinData::Primitive"
        super
      end
    end
  end

  class MultiValue < Record
    class << self
      def inherited(subclass) #:nodoc:
        warn "BinData::MultiValue is deprecated.  Replacing with BinData::Record"
        super
      end
    end
  end

  class Registry
    def Registry.instance #:nodoc:
      warn "'Registry.instance' is deprecated.  Replacing with 'RegisteredClasses'"
      RegisteredClasses
    end
  end

  class Array
    alias_method :orig_clear?, :clear?
    def clear?(index = nil) #:nodoc:
      if index.nil?
        orig_clear?
      elsif index < elements.length
        warn "'obj.clear?(n)' is deprecated.  Replacing with 'obj[n].clear?'"
        elements[index].clear?
      else
        true
      end
    end

    alias_method :orig_clear, :clear
    def clear(index = nil) #:nodoc:
      if index.nil?
        orig_clear
      elsif index < elements.length
        warn "'obj.clear(n)' is deprecated.  Replacing with 'obj[n].clear'"
        elements[index].clear
      end
    end

    alias_method :orig__do_num_bytes, :_do_num_bytes
    def _do_num_bytes(index) #:nodoc:
      if index.nil?
        orig__do_num_bytes(nil)
      elsif index < elements.length
        warn "'obj.num_bytes(n)' is deprecated.  Replacing with 'obj[n].num_bytes'"
        elements[index].do_num_bytes
      else
        0
      end
    end

    def append(value = nil) #:nodoc:
      warn "#append is deprecated, use push or slice instead"
      if value.nil?
        slice(length)
      else
        push(value)
      end
      self.last
    end
  end

  class String < BinData::BasePrimitive
    class << self
      def deprecate!(params, old_key, new_key) #:nodoc:
        if params.has_parameter?(old_key)
          warn ":#{old_key} is deprecated. Replacing with :#{new_key}"
          params[new_key] = params.delete(old_key)
        end
      end

      alias_method :orig_sanitize_parameters!, :sanitize_parameters!
      def sanitize_parameters!(params, sanitizer) #:nodoc:
        deprecate!(params, :trim_value, :trim_padding)
        orig_sanitize_parameters!(params, sanitizer)
      end
    end
  end


  class Struct < BinData::Base
    class << self
      def inherited(subclass) #:nodoc:
        if subclass != Record
          fail "error: inheriting from BinData::Struct has been deprecated. Inherit from BinData::Record instead."
        end
      end
    end

    alias_method :orig_clear, :clear
    def clear(name = nil) #:nodoc:
      if name.nil?
        orig_clear
      else
        warn "'obj.clear(name)' is deprecated.  Replacing with 'obj.name.clear'"
        obj = find_obj_for_name(name)
        obj.clear unless obj.nil?
      end
    end

    alias_method :orig_clear?, :clear?
    def clear?(name = nil) #:nodoc:
      if name.nil?
        orig_clear?
      else
        warn "'obj.clear?(name)' is deprecated.  Replacing with 'obj.name.clear?'"
        obj = find_obj_for_name(name)
        obj.nil? ? true : obj.clear?
      end
    end

    alias_method :orig__do_num_bytes, :_do_num_bytes
    def _do_num_bytes(name) #:nodoc:
      if name.nil?
        orig__do_num_bytes(nil)
      else
        warn "'obj.num_bytes(name)' is deprecated.  Replacing with 'obj.name.num_bytes'"
        obj = find_obj_for_name(name)
        obj.nil? ? 0 : obj.do_num_bytes
      end
    end

    alias_method :orig_offset_of, :offset_of
    def offset_of(child)
      if child.is_a?(::String) or child.is_a?(Symbol)
        fail "error: 'offset_of(#{child.inspect})' is deprecated.  Use '#{child.to_s}.offset' instead"
      end
      orig_offset_of(child)
    end
  end
end
