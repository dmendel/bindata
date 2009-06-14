# BinData -- Binary data manipulator.
# Copyright (c) 2007,2008 Dion Mendel.

require 'bindata/array'
require 'bindata/bits'
require 'bindata/choice'
require 'bindata/float'
require 'bindata/int'
require 'bindata/primitive'
require 'bindata/record'
require 'bindata/rest'
require 'bindata/string'
require 'bindata/stringz'
require 'bindata/struct'
require 'bindata/trace'
require 'bindata/deprecated'

# = BinData
# 
# A declarative way to read and write structured binary data.
# 
module BinData
  VERSION = "0.10.0"
end
