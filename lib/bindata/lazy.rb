module BinData
  # The enviroment in which a lazily evaluated lamba is called.  These lambdas
  # are those that are passed to data objects as parameters.  Each lambda
  # has access to the following:
  #
  # parent:: the environment of the parent data object
  # params:: any extra parameters that have been passed to the data object.
  #          The value of a parameter is either a lambda, a symbol or a
  #          literal value (such as a Fixnum).
  # value::  the value of the data object if it is single
  # index::  the index of the data object if it is in an array
  # offset:: the current offset of the IO object when reading
  #
  # Unknown methods are resolved in the context of the parent data object,
  # first as keys in the extra parameters, and secondly as methods in the
  # parent data object.  This makes the lambda easier to read as we just write
  # <tt>field</tt> instead of <tt>obj.field</tt>.
  class LazyEvalEnv
    # Creates a new environment.  +parent+ is the environment of the
    # parent data object.
    def initialize(parent = nil)
      @parent = parent
    end
    attr_reader :parent
    attr_accessor :data_object, :params, :index, :offset

    # only accessible by another LazyEvalEnv
    protected :data_object

    # TODO: offset_of needs to be better thought out
    def offset_of(sym)
      if @parent and @parent.data_object and
              @parent.data_object.respond_to?(:offset_of)
        @parent.data_object.offset_of(sym)
      else
        nil
      end
    end

    # Returns the data_object for the parent environment.
    def parent_data_object
      @parent.nil? ? nil : @parent.data_object
    end

    # Returns the value of the data object wrapped by this environment.
    def value
      @data_object.respond_to?(:value) ? @data_object.value : nil
    end

    # Evaluates +obj+ in the context of this environment.  Evaluation
    # recurses until it yields a value that is not a symbol or lambda.
    def lazy_eval(obj)
      if obj.is_a? Symbol
        # treat :foo as lambda { foo }
        lazy_eval(__send__(obj))
      elsif obj.respond_to? :arity
        instance_eval(&obj)
      else
        obj
      end
    end

    def method_missing(symbol, *args)
      if @parent and @parent.params and @parent.params.has_key?(symbol)
        # is there a param with this name?
        @parent.lazy_eval(@parent.params[symbol])
      elsif @parent and @parent.data_object and
              @parent.data_object.respond_to?(symbol)
        # how about a field or method in the parent?
        @parent.data_object.__send__(symbol, *args)
      else
        super
      end
    end
  end
end
