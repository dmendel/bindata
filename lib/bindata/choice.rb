require 'forwardable'
require 'bindata/base'
require 'bindata/sanitize'

module BinData
  # A Choice is a collection of data objects of which only one is active
  # at any particular time.
  #
  #   require 'bindata'
  #
  #   type1 = [:string, {:value => "Type1"}]
  #   type2 = [:string, {:value => "Type2"}]
  #
  #   choices = [ type1, type2 ]
  #   a = BinData::Choice.new(:choices => choices, :selection => 1)
  #   a.value # => "Type2"
  #
  #   choices = [ nil, nil, nil, type1, nil, type2 ]
  #   a = BinData::Choice.new(:choices => choices, :selection => 3)
  #   a.value # => "Type1"
  #
  #   choices = {5 => type1, 17 => type2}
  #   a = BinData::Choice.new(:choices => choices, :selection => 5)
  #   a.value # => "Type1"
  #
  #   mychoice = 'big'
  #   choices = {'big' => :uint16be, 'little' => :uint16le}
  #   a = BinData::Choice.new(:choices => choices,
  #                           :selection => lambda { mychoice })
  #   a.value  = 256
  #   a.to_s #=> "\001\000"
  #   mychoice[0..-1] = 'little'
  #   a.to_s #=> "\000\001"
  #
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:choices</tt>::   Either an array or a hash specifying the possible
  #                       data objects.  The format of the array/hash.values is
  #                       a list of symbols representing the data object type.
  #                       If a choice is to have params passed to it, then it
  #                       should be provided as [type_symbol, hash_params].
  #                       An implementation gotcha is that the hash may not
  #                       contain symbols as keys.
  # <tt>:selection</tt>:: An index/key into the :choices array/hash which
  #                       specifies the currently active choice.
  class Choice < BinData::Base
    extend Forwardable

    # Register this class
    register(self.name, self)

    # These are the parameters used by this class.
    mandatory_parameters :choices, :selection

    class << self

      # Returns a sanitized +params+ that is of the form expected
      # by #initialize.
      def sanitize_parameters(params, endian = nil)
        params = params.dup

        if params.has_key?(:choices)
          choices = params[:choices]

          case choices
          when ::Hash
            new_choices = {}
            choices.keys.each do |key|
              # ensure valid hash keys
              if Symbol === key
                msg = ":choices hash may not have symbols for keys"
                raise ArgumentError, msg
              elsif key.nil?
                raise ArgumentError, ":choices hash may not have nil key"
              end

              # collect sanitized choice values
              type, param = choices[key]
              klass = lookup(type, endian)
              if klass.nil?
                raise TypeError, "unknown type '#{type}' for #{self}"
              end
              val = [klass, SanitizedParameters.new(klass, param, endian)]
              new_choices[key] = val
            end
            params[:choices] = new_choices
          when ::Array
            choices.collect! do |type, param|
              if type.nil?
                # allow sparse arrays
                nil
              else
                klass = lookup(type, endian)
                if klass.nil?
                  raise TypeError, "unknown type '#{type}' for #{self}"
                end
                [klass, SanitizedParameters.new(klass, param, endian)]
              end
            end
            params[:choices] = choices
          else
            raise ArgumentError, "unknown type for :choices (#{choices.class})"
          end
        end

        super(params, endian)
      end

      # Returns all the possible field names a :choice may have.
      def all_possible_field_names(sanitized_params)
        unless SanitizedParameters === sanitized_params
          raise ArgumentError, "parameters aren't sanitized"
        end

        choices = sanitized_params[:choices]

        names = []
        if ::Array === choices
          choices.each do |cklass, cparams|
            names.concat(cklass.all_possible_field_names(cparams))
          end
        elsif ::Hash === choices
          choices.values.each do |cklass, cparams|
            names.concat(cklass.all_possible_field_names(cparams))
          end
        end
        names
      end
    end

    def initialize(params = {}, env = nil)
      super(params, env)

      # prepare collection of instantiated choice objects
      @choices = (param(:choices) === ::Array) ? [] : {}
      @last_key = nil
    end

    def_delegators :the_choice, :clear, :clear?, :single_value?, :field_names
    def_delegators :the_choice, :snapshot, :done_read
    def_delegators :the_choice, :_do_read, :_do_write, :_do_num_bytes

    # Returns the data object that stores values for +name+.
    def find_obj_for_name(name)
      field_names.include?(name) ? the_choice.find_obj_for_name(name) : nil
    end

    # Override to include selected data object.
    def respond_to?(symbol, include_private = false)
      super || the_choice.respond_to?(symbol, include_private)
    end

    def method_missing(symbol, *args, &block)
      if the_choice.respond_to?(symbol)
        the_choice.__send__(symbol, *args, &block)
      else
        super
      end
    end

    #---------------
    private

    # Returns the selected data object.
    def the_choice
      key = eval_param(:selection)

      if key.nil?
        raise IndexError, ":selection returned nil value"
      end

      obj = @choices[key]
      if obj.nil?
        # instantiate choice object
        choice_klass, choice_params = param(:choices)[key]
        if choice_klass.nil?
          raise IndexError, "selection #{key} does not exist in :choices"
        end
        obj = choice_klass.new(choice_params, create_env)
        @choices[key] = obj
      end

      # for single_values copy the value when the selected object changes
      if key != @last_key
        if @last_key != nil
          prev = @choices[@last_key]
          if prev != nil and prev.single_value? and obj.single_value?
            obj.value = prev.value
          end
        end
        @last_key = key
      end

      obj
    end
  end
end
