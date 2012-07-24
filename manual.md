Title: BinData Reference Manual

{:ruby: lang=ruby html_use_syntax=true}

# BinData - Parsing Binary Data in Ruby

A declarative way to read and write structured binary data.

## What is it for?

Do you ever find yourself writing code like this?

    io = File.open(...)
    len = io.read(2).unpack("v")[0]
    name = io.read(len)
    width, height = io.read(8).unpack("VV")
    puts "Rectangle #{name} is #{width} x #{height}"
{:ruby}

It's ugly, violates DRY and feels like you're writing Perl, not Ruby.

There is a better way.

    class Rectangle < BinData::Record
      endian :little
      uint16 :len
      string :name, :read_length => :len
      uint32 :width
      uint32 :height
    end

    io = File.open(...)
    r = Rectangle.read(io)
    puts "Rectangle #{r.name} is #{r.width} x #{r.height}"
{:ruby}

BinData makes it easy to specify the structure of the data you are
manipulating.

It supports all the common datatypes that are found in structured binary
data. Support for dependent and variable length fields is built in. 

Last updated: 2012-07-24

## License

BinData is released under the same license as Ruby.

Copyright &copy; 2007 - 2012 [Dion Mendel](mailto:dion@lostrealm.com)

## Donate

Want to donate?  My favourite local charity is
[Perth Raptor Care](http://care.raptor.id.au/help.html#PAL).

---------------------------------------------------------------------------

# Installation

You can install BinData via rubygems.

    gem install bindata

Alternatively, visit the 
[download](http://rubyforge.org/frs/?group_id=3252) page and download
BinData as a tar file.

---------------------------------------------------------------------------

# Overview

BinData declarations are easy to read.  Here's an example.

    class MyFancyFormat < BinData::Record
      stringz :comment
      uint8   :len
      array   :data, :type => :int32be, :initial_length => :len
    end
{:ruby}

This fancy format describes the following collection of data:

`:comment`
:   A zero terminated string

`:len`
:   An unsigned 8bit integer

`:data`
:   A sequence of unsigned 32bit big endian integers.  The number of
    integers is given by the value of `:len`

The BinData declaration matches the English description closely.
Compare the above declaration with the equivalent `#unpack` code to read
such a data record.

    def read_fancy_format(io)
      comment, len, rest = io.read.unpack("Z*Ca*")
      data = rest.unpack("N#{len}")
      {:comment => comment, :len => len, :data => *data}
    end
{:ruby}

The BinData declaration clearly shows the structure of the record.  The
`#unpack` code makes this structure opaque.

The general usage of BinData is to declare a structured collection of
data as a user defined record.  This record can be instantiated, read,
written and manipulated without the user having to be concerned with the
underlying binary data representation.

---------------------------------------------------------------------------

# Records

The general format of a BinData record declaration is a class containing
one or more fields.

    class MyName < BinData::Record
      type field_name, :param1 => "foo", :param2 => bar, ...
      ...
    end
{:ruby}

`type`
:   is the name of a supplied type (e.g. `uint32be`, `string`, `array`)
    or a user defined type.  For user defined types, the class name is
    converted from `CamelCase` to lowercased `underscore_style`.

`field_name`
:   is the name by which you can access the field.  Use a `Symbol` for
    the name.  If the name is omitted, then this particular field 
    is anonymous.  An anonymous field is still read and written, but
    will not appear in `#snapshot`.

Each field may have optional *parameters* for how to process the data.
The parameters are passed as a `Hash` with `Symbols` for keys.
Parameters are designed to be lazily evaluated, possibly multiple times.
This means that any parameter value must not have side effects.

Here are some examples of legal values for parameters.

*   `:param => 5`
*   `:param => lambda { foo + 2 }`
*   `:param => :bar`

The simplest case is when the value is a literal value, such as `5`.

If the value is not a literal, it is expected to be a lambda.  The
lambda will be evaluated in the context of the parent.  In this case
the parent is an instance of `MyName`.

If the value is a symbol, it is taken as syntactic sugar for a lambda
containing the value of the symbol.
e.g `:param => :bar` is `:param => lambda { bar }`

## Specifying default endian

The endianess of numeric types must be explicitly defined so that the
code produced is independent of architecture.  However, explicitly
specifying the endian for each numeric field can result in a bloated
declaration that is difficult to read.

    class A < BinData::Record
      int16be  :a
      int32be  :b
      int16le  :c  # <-- Note little endian!
      int32be  :d
      float_be :e
      array    :f, :type => :uint32be
    end
{:ruby}

The `endian` keyword can be used to set the default endian.  This makes
the declaration easier to read.  Any numeric field that doesn't use the
default endian can explicitly override it.

    class A < BinData::Record
      endian :big

      int16   :a
      int32   :b
      int16le :c   # <-- Note how this little endian now stands out
      int32   :d
      float   :e
      array   :f, :type => :uint32
    end
{:ruby}

The increase in clarity can be seen with the above example.  The
`endian` keyword will cascade to nested types, as illustrated with the
array in the above example.

## Dependencies between fields

A common occurence in binary file formats is one field depending upon
the value of another.  e.g. A string preceded by its length.

As an example, let's assume a Pascal style string where the byte
preceding the string contains the string's length.

    # reading
    io = File.open(...)
    len = io.getc
    str = io.read(len)
    puts "string is " + str

    # writing
    io = File.open(...)
    str = "this is a string"
    io.putc(str.length)
    io.write(str)
{:ruby}

Here's how we'd implement the same example with BinData.

    class PascalString < BinData::Record
      uint8  :len,  :value => lambda { data.length }
      string :data, :read_length => :len
    end

    # reading
    io = File.open(...)
    ps = PascalString.new
    ps.read(io)
    puts "string is " + ps.data

    # writing
    io = File.open(...)
    ps = PascalString.new
    ps.data = "this is a string"
    ps.write(io)
{:ruby}

This syntax needs explaining.  Let's simplify by examining reading and
writing separately.

    class PascalStringReader < BinData::Record
      uint8  :len
      string :data, :read_length => :len
    end
{:ruby}

This states that when reading the string, the initial length of the
string (and hence the number of bytes to read) is determined by the
value of the `len` field.

Note that `:read_length => :len` is syntactic sugar for
`:read_length => lambda { len }`, as described previously.

    class PascalStringWriter < BinData::Record
      uint8  :len, :value => lambda { data.length }
      string :data
    end
{:ruby}

This states that the value of `len` is always equal to the length of
`data`.  `len` may not be manually modified.

Combining these two definitions gives the definition for `PascalString`
as previously defined.

It is important to note with dependencies, that a field can only depend
on one before it.  You can't have a string which has the characters
first and the length afterwards.

## Nested Records

BinData supports anonymous nested records.  The `struct` keyword declares
a nested structure that can be used to imply a grouping of related data.

    class LabeledCoord < BinData::Record
      string :label, :length => 20

      struct :coord do
        endian :little
        double :x
        double :z
        double :y
      end
    end

    pos = LabeledCoord.new(:label => "red leader")
    pos.coord.assign(:x => 2.0, :y => 0, :z => -1.57)
{:ruby}

This nested structure can be put in its own class and reused.
The above example can also be declared as:

    class Coord < BinData::Record
      endian :little
      double :x
      double :z
      double :y
    end

    class LabeledCoord < BinData::Record
      string :label, :length => 20
      coord  :coord
    end
{:ruby}

## Optional fields

A record may contain optional fields.  The optional state of a field is
decided by the `:onlyif` parameter.  If the value of this parameter is
`false`, then the field will be as if it didn't exist in the record.

    class RecordWithOptionalField < BinData::Record
      ...
      uint8  :comment_flag
      string :comment, :length => 20, :onlyif => :has_comment?

      def has_comment?
        comment_flag.nonzero?
      end
    end
{:ruby}

In the above example, the `comment` field is only included in the record
if the value of the `comment_flag` field is non zero.

---------------------------------------------------------------------------

# Primitive Types

BinData provides support for the most commonly used primitive types that
are used when working with binary data.  Namely:

*   fixed size strings
*   zero terminated strings
*   byte based integers - signed or unsigned, big or little endian and
    of any size
*   bit based integers - unsigned big or little endian integers of any
    size
*   floating point numbers - single or double precision floats in either
    big or little endian

Primitives may be manipulated individually, but is more common to work
with them as part of a record.

Examples of individual usage:

    int16 = BinData::Int16be.new(941)
    int16.to_binary_s #=> "\003\255"

    fl = BinData::FloatBe.read("\100\055\370\124") #=> 2.71828174591064
    fl.num_bytes #=> 4

    fl * int16 #=> 2557.90320057996
{:ruby}

There are several parameters that are specific to all primitives.

`:initial_value`

:   This contains the initial value that the primitive will contain
    after initialization.  This is useful for setting default values.

        obj = BinData::String.new(:initial_value => "hello ")
        obj + "world" #=> "hello world"

        obj.assign("good-bye " )
        obj + "world" #=> "good-bye world"
    {:ruby}

`:value`

:   The primitive will always contain this value.  Reading or assigning
    will not change the value.  This parameter is used to define
    constants or dependent fields.

        pi = BinData::FloatLe.new(:value => Math::PI)
        pi.assign(3)
        puts pi #=> 3.14159265358979


        class IntList < BinData::Record
          uint8 :len, :value => lambda { data.length }
          array :data, :type => :uint32be
        end

        list = IntList.new([1, 2, 3])
        list.len #=> 3
    {:ruby}

`:check_value`

:   When reading, will raise a `ValidityError` if the value read does
    not match the value of this parameter.  This is useful when
    [debugging](#debugging), rather than as a general error detection
    system.

        obj = BinData::String.new(:check_value => lambda { /aaa/ =~ value })
        obj.read("baaa!") #=> "baaa!"
        obj.read("bbb") #=> raises ValidityError

        obj = BinData::String.new(:check_value => "foo")
        obj.read("foo") #=> "foo"
        obj.read("bar") #=> raises ValidityError
    {:ruby}

## Numerics

There are three kinds of numeric types that are supported by BinData.

### Byte based integers

These are the common integers that are used in most low level
programming languages (C, C++, Java etc).  These integers can be signed
or unsigned.  The endian must be specified so that the conversion is
independent of architecture.  The bit size of these integers must be a
multiple of 8.  Examples of byte based integers are:

`uint16be`
:   unsigned 16 bit big endian integer

`int8`
:   signed 8 bit integer

`int32le`
:   signed 32 bit little endian integer

`uint40be`
:   unsigned 40 bit big endian integer

The `be` | `le` suffix may be omitted if the `endian` keyword is in use.

### Bit based integers

These unsigned integers are used to define bitfields in records.
Bitfields are big endian by default but little endian may be specified
explicitly.  Little endian bitfields are rare, but do occur in older
file formats (e.g.  The file allocation table for FAT12 filesystems is
stored as an array of 12bit little endian integers).

An array of bit based integers will be packed according to their endian.

In a record, adjacent bitfields will be packed according to their
endian.  All other fields are byte-aligned.

Examples of bit based integers are:

`bit1`
:   1 bit big endian integer (may be used as boolean)

`bit4_le`
:   4 bit little endian integer

`bit32`
:   32 bit big endian integer

The difference between byte and bit base integers of the same number of
bits (e.g. `uint8` vs `bit8`) is one of alignment.

This example is packed as 3 bytes

    class A < BinData::Record
      bit4  :a
      uint8 :b
      bit4  :c
    end

    Data is stored as: AAAA0000 BBBBBBBB CCCC0000
{:ruby}

Whereas this example is packed into only 2 bytes

    class B < BinData::Record
      bit4 :a
      bit8 :b
      bit4 :c
    end

    Data is stored as: AAAABBBB BBBBCCCC
{:ruby}

### Floating point numbers

BinData supports 32 and 64 bit floating point numbers, in both big and
little endian format.  These types are:

`float_le`
:   single precision 32 bit little endian float

`float_be`
:   single precision 32 bit big endian float

`double_le`
:   double precision 64 bit little endian float

`double_be`
:   double precision 64 bit big endian float

The `_be` | `_le` suffix may be omitted if the `endian` keyword is in use.

### Example

Here is an example declaration for an Internet Protocol network packet.

    class IP_PDU < BinData::Record
      endian :big

      bit4   :version, :value => 4
      bit4   :header_length
      uint8  :tos
      uint16 :total_length
      uint16 :ident
      bit3   :flags
      bit13  :frag_offset
      uint8  :ttl
      uint8  :protocol
      uint16 :checksum
      uint32 :src_addr
      uint32 :dest_addr
      string :options, :read_length => :options_length_in_bytes
      string :data, :read_length => lambda { total_length - header_length_in_bytes }

      def header_length_in_bytes
        header_length * 4
      end

      def options_length_in_bytes
        header_length_in_bytes - 20
      end
    end
{:ruby}

Three of the fields have parameters.
*   The version field always has the value 4, as per the standard.
*   The options field is read as a raw string, but not processed.
*   The data field contains the payload of the packet.  Its length is
    calculated as the total length of the packet minus the length of
    the header.

## Strings

BinData supports two types of strings - fixed size and zero terminated.
Strings are treated internally as a sequence of 8bit bytes.  This is the
same as strings in Ruby 1.8.  BinData fully supports Ruby 1.9 string
encodings.  See this [FAQ
entry](#im_using_ruby_19_how_do_i_use_string_encodings_with_bindata) for
details.

### Fixed Sized Strings

Fixed sized strings may have a set length (in bytes).  If an assigned
value is shorter than this length, it will be padded to this length.  If
no length is set, the length is taken to be the length of the assigned
value.

There are several parameters that are specific to fixed sized strings.

`:read_length`

:   The length in bytes to use when reading a value.

        obj = BinData::String.new(:read_length => 5)
        obj.read("abcdefghij")
        obj #=> "abcde"
    {:ruby}

`:length`

:   The fixed length of the string.  If a shorter string is set, it
    will be padded to this length.  Longer strings will be truncated.

        obj = BinData::String.new(:length => 6)
        obj.read("abcdefghij")
        obj #=> "abcdef"

        obj = BinData::String.new(:length => 6)
        obj.assign("abcd")
        obj #=> "abcd\000\000"

        obj = BinData::String.new(:length => 6)
        obj.assign("abcdefghij")
        obj #=> "abcdef"
    {:ruby}

`:pad_front` or `:pad_left`

:   Boolean, default `false`.  Signifies that the padding occurs at the front
    of the string rather than the end.

        obj = BinData::String.new(:length => 6, :pad_front => true)
        obj.assign("abcd")
        obj.snapshot #=> "\000\000abcd"
    {:ruby}

`:pad_byte`

:   Defaults to `"\0"`.  The character to use when padding a string to a
    set length.  Valid values are `Integers` and `Strings` of one byte.
    Multi byte padding is not supported.

        obj = BinData::String.new(:length => 6, :pad_byte => 'A')
        obj.assign("abcd")
        obj.snapshot #=> "abcdAA"
        obj.to_binary_s #=> "abcdAA"
    {:ruby}

`:trim_padding`

:   Boolean, default `false`.  If set, the value of this string will
    have all pad_bytes trimmed from the end of the string.  The value
    will not be trimmed when writing.

        obj = BinData::String.new(:length => 6, :trim_value => true)
        obj.assign("abcd")
        obj.snapshot #=> "abcd"
        obj.to_binary_s #=> "abcd\000\000"
    {:ruby}

### Zero Terminated Strings

These strings are modelled on the C style of string - a sequence of
bytes terminated by a null (`"\0"`) byte.

    obj = BinData::Stringz.new
    obj.read("abcd\000efgh")
    obj #=> "abcd"
    obj.num_bytes #=> 5
    obj.to_binary_s #=> "abcd\000"
{:ruby}

## User Defined Primitive Types

Most user defined types will be Records but occasionally we'd like to
create a custom primitive type.

Let us revisit the Pascal String example.

    class PascalString < BinData::Record
      uint8  :len,  :value => lambda { data.length }
      string :data, :read_length => :len
    end
{:ruby}

We'd like to make `PascalString` a user defined type that behaves like a
`BinData::BasePrimitive` object so we can use `:initial_value` etc.
Here's an example usage of what we'd like:

    class Favourites < BinData::Record
      pascal_string :language, :initial_value => "ruby"
      pascal_string :os,       :initial_value => "unix"
    end

    f = Favourites.new
    f.os = "freebsd"
    f.to_binary_s #=> "\004ruby\007freebsd"
{:ruby}

We create this type of custom string by inheriting from
`BinData::Primitive` (instead of `BinData::Record`) and implementing the
`#get` and `#set` methods.

    class PascalString < BinData::Primitive
      uint8  :len,  :value => lambda { data.length }
      string :data, :read_length => :len

      def get;   self.data; end
      def set(v) self.data = v; end
    end
{:ruby}

A user defined primitive type has both an internal (binary structure)
and an external (ruby interface) representation.  The internal
representation is encapsulated and inaccessible from the external ruby
interface.

Consider a LispBool type that uses `:t` for true and `nil` for false.
The binary representation is a signed byte with value `1` for true and
`-1` for false.

    class LispBool < BinData::Primitive
      int8 :val

      def get
        case self.val
        when 1
          :t
        when -1
          nil
        else
          nil  # unknown value, default to false
        end
      end

      def set(v)
        case v
        when :t
          self.val = 1
        when nil
          self.val = -1
        else
          self.val = -1 # unknown value, default to false
        end
      end
    end

    b = LispBool.new

    b.assign(:t)
    b.to_binary_s #=> "\001"

    b.read("\xff")
    b.snapshot #=> nil
{:ruby}

`#read` and `#write` use the internal representation.  `#assign` and
`#snapshot` use the external representation.  Mixing them up will lead
to undefined behaviour.

    b = LispBool.new
    b.assign(1) #=> undefined.  Don't do this.
{:ruby}

### Advanced User Defined Primitive Types

Sometimes a user defined primitive type can not easily be declaratively
defined.  In this case you should inherit from `BinData::BasePrimitive`
and implement the following three methods:

`def value_to_binary_string(value)`

:   Takes a ruby value (`String`, `Numeric` etc) and converts it to
    the appropriate binary string representation.

`def read_and_return_value(io)`

:   Reads a number of bytes from `io` and returns a ruby object that
    represents these bytes.

`def sensible_default()`

:   The ruby value that a clear object should return.

If you wish to access parameters from inside these methods, you can
use `eval_parameter(key)`.

Here is an example of a big integer implementation.

    # A custom big integer format.  Binary format is:
    #   1 byte  : 0 for positive, non zero for negative
    #   x bytes : Little endian stream of 7 bit bytes representing the
    #             positive form of the integer.  The upper bit of each byte
    #             is set when there are more bytes in the stream.
    class BigInteger < BinData::BasePrimitive

      def value_to_binary_string(value)
        negative = (value < 0) ? 1 : 0
        value = value.abs
        bytes = [negative]
        loop do
          seven_bit_byte = value & 0x7f
          value >>= 7
          has_more = value.nonzero? ? 0x80 : 0
          byte = has_more | seven_bit_byte
          bytes.push(byte)

          break if has_more.zero?
        end

        bytes.collect { |b| b.chr }.join
      end

      def read_and_return_value(io)
        negative = read_uint8(io).nonzero?
        value = 0
        bit_shift = 0
        loop do
          byte = read_uint8(io)
          has_more = byte & 0x80
          seven_bit_byte = byte & 0x7f
          value |= seven_bit_byte << bit_shift
          bit_shift += 7

          break if has_more.zero?
        end

        negative ? -value : value
      end

      def sensible_default
        0
      end

      def read_uint8(io)
        io.readbytes(1).unpack("C").at(0)
      end
    end
{:ruby}

---------------------------------------------------------------------------

# Compound Types

Compound types contain more that a single value.  These types are
Records, Arrays and Choices.

## Arrays

A BinData array is a list of data objects of the same type.  It behaves
much the same as the standard Ruby array, supporting most of the common
methods.

### Array syntax

When instantiating an array, the type of object it contains must be
specified.  The two different ways of declaring this are the `:type`
parameter and the block form.

    class A < BinData::Record
      array :numbers, :type => :uint8, :initial_length => 3
    end
                  -vs-

    class A < BinData::Record
      array :numbers, :initial_length => 3 do
        uint8
      end
    end
{:ruby}

For the simple case, the `:type` parameter is usually clearer.  When the
array type has parameters, the block form becomes easier to read.

    class A < BinData::Record
       array :numbers, :type => [:uint8, {:initial_value => :index}],
                       :initial_length => 3
    end
                  -vs-

    class A < BinData::Record
      array :numbers, :initial_length => 3 do
        uint8 :initial_value => :index
      end
    end
{:ruby}

An array can also be declared as a custom type by moving the contents of
the block into a custom class.  The above example could alternatively be
declared as:

    class NumberArray < BinData::Array
      uint8 :initial_value => :index
    end

    class A < BinData::Record
      number_array :numbers, :initial_length => 3
    end
{:ruby}


If the block form has multiple types declared, they are interpreted as
the contents of an [anonymous `struct`](#nested_records).  To illustrate
this, consider the following representation of a polygon.

    class Polygon < BinData::Record
      endian :little
      uint8 :num_points, :value => lambda { points.length }
      array :points, :initial_length => :num_points do
        double :x
        double :y
      end
    end

    triangle = Polygon.new
    triangle.points[0].assign(:x => 1, :y => 2)
    triangle.points[1].x = 3
    triangle.points[1].y = 4
    triangle.points << {:x => 5, :y => 6}
{:ruby}

### Array parameters

There are two different parameters that specify the length of the array.

`:initial_length`

:    Specifies the initial length of a newly instantiated array.
     The array may grow as elements are inserted.

        obj = BinData::Array.new(:type => :int8, :initial_length => 4)
        obj.read("\002\003\004\005\006\007")
        obj.snapshot #=> [2, 3, 4, 5]
    {:ruby}

`:read_until`

:   While reading, elements are read until this condition is true.  This
    is typically used to read an array until a sentinel value is found.
    The variables `index`, `element` and `array` are made available to
    any lambda assigned to this parameter.  If the value of this
    parameter is the symbol `:eof`, then the array will read as much
    data from the stream as possible.
  
        obj = BinData::Array.new(:type => :int8,
                                 :read_until => lambda { index == 1 })
        obj.read("\002\003\004\005\006\007")
        obj.snapshot #=> [2, 3]

        obj = BinData::Array.new(:type => :int8,
                                 :read_until => lambda { element >= 3.5 })
        obj.read("\002\003\004\005\006\007")
        obj.snapshot #=> [2, 3, 4]

        obj = BinData::Array.new(:type => :int8,
                :read_until => lambda { array[index] + array[index - 1] == 9 })
        obj.read("\002\003\004\005\006\007")
        obj.snapshot #=> [2, 3, 4, 5]

        obj = BinData::Array.new(:type => :int8, :read_until => :eof)
        obj.read("\002\003\004\005\006\007")
        obj.snapshot #=> [2, 3, 4, 5, 6, 7]
    {:ruby}

## Choices

A Choice is a collection of data objects of which only one is active at
any particular time.  Method calls will be delegated to the active
choice.  The possible types of objects that a choice contains is
controlled by the `:choices` parameter, while the `:selection` parameter
specifies the active choice.

### Choice syntax

Choices have two ways of specifying the possible data objects they can
contain.  The `:choices` parameter or the block form.  The block form is
usually clearer and is prefered.

    class MyInt16 < BinData::Record
      uint8  :e, :check_value => lambda { value == 0 or value == 1 }
      choice :int, :selection => :e,
                   :choices => {0 => :int16be, 1 => :int16le}
    end
                  -vs-

    class MyInt16 < BinData::Record
      uint8  :e, :check_value => lambda { value == 0 or value == 1 }
      choice :int, :selection => :e do
        int16be 0
        int16le 1
      end
    end
{:ruby}

Like all compound types, a choice can be declared as its own type.  The
above example can be declared as:

    class BigLittleInt16 < BinData::Choice
      int16be 0
      int16le 1
    end

    class MyInt16 < BinData::Record
      uint8  :e, :check_value => lambda { value == 0 or value == 1 }
      bit_little_int_16 :int, :selection => :e
    end
{:ruby}

The general form of the choice is

    class MyRecord < BinData::Record
      choice :name, :selection => lambda { ... } do
        type key, :param1 => "foo", :param2 => "bar" ... # option 1
        type key, :param1 => "foo", :param2 => "bar" ... # option 2
      end
    end
{:ruby}

`type`
:   is the name of a supplied type (e.g. `uint32be`, `string`)
    or a user defined type.  This is the same as for Records.

`key`
:   is the value that `:selection` will return to specify that this
    choice is currently active.  The key can be any ruby type (`String`,
    `Numeric` etc) except `Symbol`.

### Choice parameters

`:choices`

:   Either an array or a hash specifying the possible data objects.  The
    format of the array/hash.values is a list of symbols representing
    the data object type.  If a choice is to have params passed to it,
    then it should be provided as `[type_symbol, hash_params]`.  An
    implementation constraint is that the hash may not contain symbols
    as keys.

`:selection`

:   An index/key into the `:choices` array/hash which specifies the
    currently active choice.

`:copy_on_change`

:   If set to `true`, copy the value of the previous selection to the
    current selection whenever the selection changes.  Default is
    `false`.

Examples

    type1 = [:string, {:value => "Type1"}]
    type2 = [:string, {:value => "Type2"}]
    
    choices = {5 => type1, 17 => type2}
    obj = BinData::Choice.new(:choices => choices, :selection => 5)
    obj # => "Type1"

    choices = [ type1, type2 ]
    obj = BinData::Choice.new(:choices => choices, :selection => 1)
    obj # => "Type2"

    class MyNumber < BinData::Record
      int8 :is_big_endian
      choice :data, :selection => lambda { is_big_endian != 0 },
                    :copy_on_change => true do
        int32le false
        int32be true
      end
    end

    obj = MyNumber.new
    obj.is_big_endian = 1
    obj.data = 5
    obj.to_binary_s #=> "\001\000\000\000\005"

    obj.is_big_endian = 0
    obj.to_binary_s #=> "\000\005\000\000\000"
{:ruby}

### Default selection

A key of `:default` can be specified as a default selection.  If the value of the
selection isn't specified then the :default will be used.  The previous `MyNumber`
example used a flag for endian.  Zero is little endian while any other value
is big endian.  This can be concisely written as:

    class MyNumber < BinData::Record
      int8 :is_big_endian
      choice :data, :selection => :is_big_endian,
                    :copy_on_change => true do
        int32le 0          # zero is little endian
        int32be :default   # anything else is big endian
      end
    end
{:ruby}

---------------------------------------------------------------------------

# Common Operations

There are operations common to all BinData types, including user defined
ones.  These are summarised here.

## Reading and writing

`::read(io)`

:   Creates a BinData object and reads its value from the given string
    or `IO`.  The newly created object is returned.

        obj = BinData::Int8.read("\xff")
        obj.snapshot #=> -1
    {:ruby}

`#read(io)`

:   Reads and assigns binary data read from `io`.

        obj = BinData::Stringz.new
        obj.read("string 1\0string 2\0")
        obj #=> "string 1"
    {:ruby}

`#write(io)`

:   Writes the binary data representation of the object to `io`.

        File.open("...", "wb") do |io|
          obj = BinData::Uint64be.new(568290145640170)
          obj.write(io)
        end
    {:ruby}

`#to_binary_s`

:   Returns the binary data representation of this object as a string.

        obj = BinData::Uint16be.new(4660)
        obj.to_binary_s #=> "\022\064"
    {:ruby}

## Manipulating

`#assign(value)`

:   Assigns the given value to this object.  `value` can be of the same
    format as produced by `#snapshot`, or it can be a compatible data
    object.
  
        arr = BinData::Array.new(:type => :uint8)
        arr.assign([1, 2, 3, 4])
        arr.snapshot #=> [1, 2, 3, 4]
    {:ruby}

`#clear`

:   Resets this object to its initial state.

        obj = BinData::Int32be.new(:initial_value => 42)
        obj.assign(50)
        obj.clear
        obj #=> 42
    {:ruby}

`#clear?`

:   Returns whether this object is in its initial state.

        arr = BinData::Array.new(:type => :uint16be, :initial_length => 5)
        arr[3] = 42
        arr.clear? #=> false

        arr[3].clear
        arr.clear? #=> true
    {:ruby}

## Inspecting

`#num_bytes`

:   Returns the number of bytes required for the binary data
    representation of this object.

        arr = BinData::Array.new(:type => :uint16be, :initial_length => 5)
        arr[0].num_bytes #=> 2
        arr.num_bytes #=> 10
    {:ruby}

`#snapshot`

:   Returns the value of this object as primitive Ruby objects
    (numerics, strings, arrays and hashs).  The output of `#snapshot`
    may be useful for serialization or as a reduced memory usage
    representation.

        obj = BinData::Uint8.new(2)
        obj.class #=> BinData::Uint8
        obj + 3 #=> 5

        obj.snapshot #=> 2
        obj.snapshot.class #=> Fixnum
    {:ruby}

`#offset`

:   Returns the offset of this object with respect to the most distant
    ancestor structure it is contained within.  This is most likely to
    be used with arrays and records.

        class Tuple < BinData::Record
          int8 :a
          int8 :b
        end

        arr = BinData::Array.new(:type => :tuple, :initial_length => 3)
        arr[2].b.offset #=> 5
    {:ruby}

`#rel_offset`

:   Returns the offset of this object with respect to the parent
    structure it is contained within.  Compare this to `#offset`.

        class Tuple < BinData::Record
          int8 :a
          int8 :b
        end

        arr = BinData::Array.new(:type => :tuple, :initial_length => 3)
        arr[2].b.rel_offset #=> 1
    {:ruby}

`#inspect`

:   Returns a human readable representation of this object.  This is a
    shortcut to #snapshot.inspect.

---------------------------------------------------------------------------

# Advanced Topics

## Debugging

BinData includes several features to make it easier to debug
declarations.

### Tracing

BinData has the ability to trace the results of reading a data
structure.

    class A < BinData::Record
      int8  :a
      bit4  :b
      bit2  :c
      array :d, :initial_length => 6, :type => :bit1
    end

    BinData::trace_reading do
      A.read("\373\225\220")
    end
{:ruby}

Results in the following being written to `STDERR`.

    obj.a => -5
    obj.b => 9
    obj.c => 1
    obj.d[0] => 0
    obj.d[1] => 1
    obj.d[2] => 1
    obj.d[3] => 0
    obj.d[4] => 0
    obj.d[5] => 1
{:ruby}

### Rest

The rest keyword will consume the input stream from the current position
to the end of the stream.

    class A < BinData::Record
      string :a, :read_length => 5
      rest   :rest
    end

    obj = A.read("abcdefghij")
    obj.a #=> "abcde"
    obj.rest #=" "fghij"
{:ruby}

### Hidden fields

The typical way to view the contents of a BinData record is to call
`#snapshot` or `#inspect`.  This gives all fields and their values.  The
`hide` keyword can be used to prevent certain fields from appearing in
this output.  This removes clutter and allows the developer to focus on
what they are currently interested in.

    class Testing < BinData::Record
      hide :a, :b
      string :a, :read_length => 10
      string :b, :read_length => 10
      string :c, :read_length => 10
    end

    obj = Testing.read(("a" * 10) + ("b" * 10) + ("c" * 10))
    obj.snapshot #=> {"c"=>"cccccccccc"}
    obj.to_binary_s #=> "aaaaaaaaaabbbbbbbbbbcccccccccc"
{:ruby}

## Parameterizing User Defined Types

All BinData types have parameters that allow the behaviour of an object
to be specified at initialization time.  User defined types may also
specify parameters.  There are two types of parameters: mandatory and
default.

### Mandatory Parameters

Mandatory parameters must be specified when creating an instance of the
type.

    class Polygon < BinData::Record
      mandatory_parameter :num_vertices

      uint8 :num, :value => lambda { vertices.length }
      array :vertices, :initial_length => :num_vertices do
        int8 :x
        int8 :y
      end
    end

    triangle = Polygon.new
        #=> raises ArgumentError: parameter 'num_vertices' must be specified in Polygon

    triangle = Polygon.new(:num_vertices => 3)
    triangle.snapshot #=> {"num" => 3, "vertices" =>
                             [{"x"=>0, "y"=>0}, {"x"=>0, "y"=>0}, {"x"=>0, "y"=>0}]}
{:ruby}

### Default Parameters

Default parameters are optional.  These parameters have a default value
that may be overridden when an instance of the type is created.

    class Phrase < BinData::Primitive
      default_parameter :number => "three"
      default_parameter :adjective => "blind"
      default_parameter :noun => "mice"

      stringz :a, :initial_value => :number
      stringz :b, :initial_value => :adjective
      stringz :c, :initial_value => :noun

      def get; "#{a} #{b} #{c}"; end
      def set(v)
        if /(.*) (.*) (.*)/ =~ v
          self.a, self.b, self.c = $1, $2, $3
        end
      end
    end

    obj = Phrase.new(:number => "two", :adjective => "deaf")
    obj.to_s #=> "two deaf mice"
{:ruby}

## Extending existing Types

Sometimes you wish to create a new type that is simply an existing type
with some predefined parameters.  Examples could be an array with a
specified type, or an integer with an initial value.

This can be achieved by subclassing the existing type and providing
default parameters.  These parameters can of course be overridden at
initialisation time.

Here we define an array that contains big endian 16 bit integers.  The
array has a preferred initial length.

    class IntArray < BinData::Array
      default_parameters :type => :uint16be, :initial_length => 5
    end

    arr = IntArray.new
    arr.size #=> 5
{:ruby}

The initial length can be overridden at initialisation time.

    arr = IntArray.new(:initial_length => 8)
    arr.size #=> 8
{:ruby}

We can also use the block form syntax:

    class IntArray < BinData::Array
      endian :big
      default_parameter :initial_length => 5

      uint16
    end
{:ruby}

## Skipping over unused data

Some structures contain binary data that is irrelevant to your purposes.  

Say you are interested in 50 bytes of data located 10 megabytes into the
stream.  One way of accessing this useful data is:

    class MyData < BinData::Record
      string :length => 10 * 1024 * 1024
      string :data, :length => 50
    end
{:ruby}

The advantage of this method is that the irrelevant data is preserved
when writing the record.  The disadvantage is that even if you don't care
about preserving this irrelevant data, it still occupies memory.

If you don't need to preserve this data, an alternative is to use
`skip` instead of `string`.  When reading it will seek over the irrelevant
data and won't consume space in memory.  When writing it will write
`:length` number of zero bytes.

    class MyData < BinData::Record
      skip :length => 10 * 1024 * 1024
      string :data, :length => 50
    end
{:ruby}

## Determining stream length

Some file formats don't use length fields but rather read until the end
of the file.  The stream length is needed when reading these formats.  The
`count_bytes_remaining` keyword will give the number of bytes remaining in the
stream.

Consider a string followed by a 2 byte checksum.  The length of the string is
not specified but is implied by the file length.

    class StringWithChecksum < BinData::Record
      count_bytes_remaining :bytes_remaining
      string :the_string, :read_length => lambda { bytes_remaining - 2 }
      int16le :checksum
    end
{:ruby}

These file formats only work with seekable streams (e.g. files).  These formats
do not stream well as they must be buffered by the client before being
processed.  Consider using an explicit length when creating a new file format
as it is easier to work with.

## Advanced Bitfields

Most types in a record are byte oriented.  [Bitfields](#bit_based_integers)
allow access to individual bits in an octet stream.

Sometimes a bitfield has unused elements such as

    class RecordWithBitfield < BinData::Record
      bit1 :foo
      bit1 :bar
      bit1 :baz
      bit5 :unused

      stringz :qux
    end
{:ruby}

The problem with specifying an unused field is that the size of this
field must be manually counted.  This is a potential source of errors.

BinData provides a shortcut to skip to the next byte boundary with the
`resume_byte_alignment` keyword.

    class RecordWithBitfield < BinData::Record
      bit1 :foo
      bit1 :bar
      bit1 :baz
      resume_byte_alignment

      stringz :qux
    end
{:ruby}

Occasionally you will come across a format where primitive types (string
and numerics) are not aligned on byte boundaries but are to be packed in
the bit stream.

    class PackedRecord < BinData::Record
      bit4     :a
      string   :b, :length => 2  # note: byte-aligned
      bit1     :c
      int16le  :d                # note: byte-aligned
      bit3     :e
    end

    obj = PackedRecord.read("\xff" * 10)
    obj.to_binary_s #=> "\360\377\377\200\377\377\340"
{:ruby}

The above declaration does not work as expected because BinData's
internal strings and integers are byte-aligned.  We need bit-aligned
versions of `string` and `int16le`.

    class BitString < BinData::String
      bit_aligned
    end

    class BitInt16le < BinData::Int16le
      bit_aligned
    end

    class PackedRecord < BinData::Record
      bit4        :a
      bit_string  :b, :length => 2
      bit1        :c
      bit_int16le :d
      bit3        :e
    end

    obj = PackedRecord.read("\xff" * 10)
    obj.to_binary_s #=> "\377\377\377\377\377"
{:ruby}

---------------------------------------------------------------------------

# FAQ

## I'm using Ruby 1.9.  How do I use string encodings with BinData?

BinData will internally use 8bit binary strings to represent the data.
You do not need to worry about converting between encodings.

If you wish BinData to present string data in a specific encoding, you
can override `#snapshot` as illustrated below:

    class UTF8String < BinData::String
      def snapshot
        super.force_encoding('UTF-8')
      end
    end

    str = UTF8String.new("\xC3\x85\xC3\x84\xC3\x96")
    str #=> "ÅÄÖ"
    str.to_binary_s #=> "\xC3\x85\xC3\x84\xC3\x96"
{:ruby}

## How do I speed up initialization?

I'm doing this and it's slow.

    999.times do |i|
      foo = Foo.new(:bar => "baz")
      ...
    end
{:ruby}

BinData is optimized to be declarative.  For imperative use, the
above naïve approach will be slow.  Below are faster alternatives.

The fastest approach is to reuse objects by calling `#clear` instead of
instantiating more objects.

    foo = Foo.new(:bar => "baz")
    999.times do
      foo.clear
      ...
    end
{:ruby}

If you can't reuse objects, then consider the prototype pattern.

    prototype = Foo.new(:bar => "baz")
    999.times do
      foo = prototype.new
      ...
    end
{:ruby}

The prefered approach is to be declarative.

    class FooList < BinData::Array
      default_parameter :initial_length => 999

      foo :bar => "baz"
    end

    array = FooList.new
    array.each { ... }
{:ruby}

## How do I model this complex nested format?

A common pattern in file formats and network protocols is
[type-length-value](http://en.wikipedia.org/wiki/Type-length-value).  The
`type` field specifies how to interpret the `value`.  This gives a way to
dynamically structure the data format.  An example is the TCP/IP protocol
suite.  An IP datagram can contain a nested TCP, UDP or other packet type as
decided by the `protocol` field.

Modelling this structure can be difficult when the nesting is recursive, e.g.
IP tunneling.  Here is an example of the simplest possible recursive TLV structure,
a [list that can contains atoms or other
lists](http://bindata.rubyforge.org/svn/trunk/examples/list.rb).

---------------------------------------------------------------------------

# Alternatives

This section is purely historic.  All the alternatives to BinData are
no longer actively maintained.

There are several alternatives to BinData.  Below is a comparison
between BinData and its alternatives.

The short form is that BinData is the best choice for most cases.
It is the most full featured of all the alternatives.  It is also 
arguably the most readable and easiest way to parse and write
binary data.

### [BitStruct](http://rubyforge.org/projects/bit-struct)

BitStruct is the most complete of all the alternatives.  It is
declarative and supports most of the same primitive types as BinData.
Its special feature is a self documenting feature for report generation.
BitStruct's design choice is to favour speed over flexibility.

The major limitation of BitStruct is that it does not support variable
length fields and dependent fields.  This makes it difficult to work
with any non trivial file formats.

If speed is important and you are only dealing with simple binary data
types then BitStruct might be a good choice.  For non trivial data
types, BinData is the better choice.

### [BinaryParse](http://rubyforge.org/projects/binaryparse)

BinaryParse is a declarative style packer / unpacker.  It provides the
same primitives as Ruby's `#pack`, with the addition of date and time.
Like BitStruct, it doesn't provide dependent or variable length fields.

### [BinStruct](http://rubyforge.org/projects/metafuzz)

BinStruct is an imperative approach to unpacking binary data.  It does
provide some declarative style syntax sugar.  It provides support for
the most common primitive types, as well as arbitrary length bitfields.

Its main focus is as a binary fuzzer, rather than as a generic decoding
/ encoding library.

### [Packable](http://github.com/marcandre/packable/tree/master)

Packable makes it much nicer to use Ruby's `#pack` and `#unpack`
methods.  Instead of having to remember that, for example `"n"` is the
code to pack a 16 bit big endian integer, packable provides many
convenient shortcuts.  In the case of `"n"`, `{:bytes => 2, :endian => :big}`
may be used instead.

Using Packable improves the readability of `#pack` and `#unpack`
methods, but explicitly calls to `#pack` and `#unpack` aren't as
readable as a declarative approach.

### [Bitpack](http://rubyforge.org/projects/bitpack)

Bitpack provides methods to extract big endian integers of arbitrary bit
length from an octet stream.

The extraction code is written in `C`, so if speed is important and bit
manipulation is all the functionality you require then this may be an
alternative.

---------------------------------------------------------------------------
