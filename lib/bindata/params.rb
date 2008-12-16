module BinData
  module Parameters

    # Definition method for creating a method that maintains a collection
    # of parameters.  This is used for creating collections of mandatory,
    # optional, default etc parameters.  The parameters for a class will
    # include the parameters of its ancestors.
    def define_parameters(name, empty, &block) #:nodoc:
      full_name_singular = "#{name.to_s}_parameter"
      full_name_plural = "#{name.to_s}_parameters"

      sym = full_name_plural.to_sym
      iv = "@#{full_name_plural}".to_sym

      body = Proc.new do |*args|
        # initialize collection to duplicate ancestor's collection
        unless instance_variable_defined?(iv)
          ancestor = ancestors[1..-1].find { |a| a.respond_to?(sym) }
          val = ancestor.nil? ? empty : ancestor.send(sym).dup
          instance_variable_set(iv, val)
        end

        # add new parameters to the collection
        if not args.empty?
          block.call(instance_variable_get(iv), args)
        end

        # return collection
        instance_variable_get(iv)
      end

      define_method(sym, body)
      alias_method(full_name_singular.to_sym, sym)
    end
  end
end
