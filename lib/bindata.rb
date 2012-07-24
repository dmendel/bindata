# BinData -- Binary data manipulator.
# Copyright (c) 2007 - 2012 Dion Mendel.

require 'bindata/array'
require 'bindata/bits'
require 'bindata/choice'
require 'bindata/count_bytes_remaining'
require 'bindata/float'
require 'bindata/int'
require 'bindata/primitive'
require 'bindata/record'
require 'bindata/rest'
require 'bindata/skip'
require 'bindata/string'
require 'bindata/stringz'
require 'bindata/struct'
require 'bindata/trace'
require 'bindata/wrapper'
require 'bindata/alignment'
require 'bindata/deprecated'

# = BinData
# 
# A declarative way to read and write structured binary data.
# 
# A full reference manual is available online at
# http://bindata.rubyforge.org.
#
# == License
#
# BinData is released under the same license as Ruby.
#
# Copyright (c) 2007 - 2012 Dion Mendel.
module BinData
  VERSION = "1.4.5"
end
