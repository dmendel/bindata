require 'bindata'

# A custom type representing an IP address.
# The underlying binary representation is a sequence of four octets.
# The human accessible representation is a dotted quad.
class IPAddr < BinData::Primitive
  array :octets, :type => :uint8, :initial_length => 4

  def set(val)
    ints = val.split(/\./).collect { |int| int.to_i }
    self.octets = ints
  end

  def get
    self.octets.collect { |octet| "%d" % octet }.join(".")
  end
end

ip = IPAddr.new("127.0.0.1")

puts "human readable value:  #{ip}"                     #=> 127.0.0.1
puts "binary representation: #{ip.to_binary_s.inspect}" #=> "\177\000\000\001"
