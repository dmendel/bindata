require 'bindata'

class A < BinData::Choice
  int8  1
  uint8 :default
end

a = A.new(:selection => 1)

p a.class

class BinData::Choice
  def selected_object
    current_choice
  end
end

case a.selected_object
when BinData::Int8
  p "int8"
else
  p "else"
end

