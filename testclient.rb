require 'socket'
require 'json'
s = UDPSocket.new()
message = Hash.new()
message['type'] = "JOINING_NETWORK"
message['node_id'] = "42"
message['ip_address'] = "199.1.5.2"
msg = JSON.generate(message)
s.send(msg, 0, '127.0.0.1', 3456)