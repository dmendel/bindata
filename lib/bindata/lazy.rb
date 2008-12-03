module BinData
  # A LazyEvaluator is bound to a data object.  The evaluator will evaluate
  # lambdas in the context of this data object.  These lambdas
  # are those that are passed to data objects as parameters, e.g.:
  #
  #    BinData::String.new(:value => lambda { %w{a test message}.join(" ") })
  #
  # When evaluating lambdas, unknown methods are resolved in the context of
  # the parent of the bound data object, first as keys in #parameters, and
  # secondly as methods in this parent.  This resolution propagates up the
  # chain of parent data objects.
  #
  # This resolution process makes the lambda easier to read as we just write
  # <tt>field</tt> instead of <tt>obj.field</tt>.
  class LazyEvaluator
    class << self
      # Lazily evaluates +val+ in the context of +obj+, with possibility of
      # +overrides+.
      def eval(val, obj, overrides = nil)
        env = self.new(obj)
        env.lazy_eval(val, overrides)
      end
    end

    # An empty hash shared by all instances
    @@empty_hash = Hash.new.freeze

    # Creates a new evaluator.  All lazy evaluation is performed in the
    # context of +obj+.
    def initialize(obj)
      @obj = obj
      @overrides = @@empty_hash
    end

    # Returns a LazyEvaluator for the parent of this data object.
    def parent
      if @obj.parent
        LazyEvaluator.new(@obj.parent)
      else
        nil
      end
    end

    # Evaluates +val+ in the context of this data object.  Evaluation
    # recurses until it yields a value that is not a symbol or lambda.
    # +overrides+ is an optional +obj.parameters+ like hash.
    def lazy_eval(val, overrides = nil)
      result = val
      @overrides = overrides if overrides
      if val.is_a? Symbol
        # treat :foo as lambda { foo }
        result = __send__(val)
      elsif val.respond_to? :arity
        result = instance_eval(&val)
      end
      @overrides = @@empty_hash
      result
    end

    def method_missing(symbol, *args)
      if @overrides.include?(symbol)
        @overrides[symbol]
      elsif symbol == :index
        array_index
      elsif @obj.parent
        val = symbol
        if @obj.parent.parameters and @obj.parent.parameters.has_key?(symbol)
          val = @obj.parent.parameters[symbol]
        elsif @obj.parent and @obj.parent.respond_to?(symbol)
          val = @obj.parent.__send__(symbol, *args)
        end
        LazyEvaluator.eval(val, @obj.parent)
      else
        super
      end
    end

    #---------------
    private

    # Returns the index in the closest ancestor array of this data object.
    def array_index
      bindata_array_klass = BinData.const_defined?("Array") ? 
                              BinData.const_get("Array") : nil
      child = @obj
      parent = @obj.parent
      while parent
        if parent.class == bindata_array_klass
          return parent.index(child)
        end
        child = parent
        parent = parent.parent
      end
      raise NoMethodError, "no index found"
    end

  end
end
