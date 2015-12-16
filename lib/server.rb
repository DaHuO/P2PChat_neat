require "./lib/ThreadPool.rb"
require "./lib/RoutingTable.rb"
require "./lib/ChatRecord.rb"
require "./lib/TimeOut.rb"
require "socket"
require "net/http"
require "json"
require "thread"

class Server
	def initialize(info, para)
		if info == "start"
			@identifier = para[0]
			@selfport = para[1]
		elsif info == "join"
			@identifier = para[1]
			@destport = para[0]
			@selfport = para[2]
		else
			raise SystemExit
		end

		@server = UDPSocket.new()
		@server.bind(nil, @selfport)
		@routing_table = RoutingTable.new(@identifier)
		@routing_table.insertNode(@identifier, @selfport)
		@chat_record = ChatRecord.new()
		@time_out = TimeOut.new()
		uri = URI("http://ipecho.net/plain")
		body = Net::HTTP.get(uri)
		if body.length != 0
			@self_ip = body
		else
			@self_ip = '127.0.0.1'
		end
		if info == "join"
			join(@identifier, @destport, @selfport)
		else
			start_boost(@identifier, @selfport)
		end
	end

	def join(identifier, destport, selfport)
		message = Hash.new()
		message['type'] = "JOINING_NETWORK"
		message['node_id'] = identifier.to_s
		message['port'] = selfport
		msg = JSON.generate(message)
		s = UDPSocket.new()
		s.send(msg, 0, '127.0.0.1', destport)
		run
	end

	def start_boost(identifier, port)
		run
	end

	def run
		puts 'ARE you ready to start the chat? Y/N'
		temp = false
		thread_pool = ThreadPool.new(2)
		while line = $stdin.gets.chomp
			if temp == false
				if (line == 'N') || (line == 'n')
					p 'exiting the program'
					raise SystemExit
				end
				temp = true
			end
			handle_stdin(line)
			Thread.new{
				loop{
					text, sender = @server.recvfrom(5000)
					thread_pool.schedule(sender) do
						handle_client(text)
					end
				}
			}
		end
	end

	def handle_stdin(text)
		if text.include?('#')
			tag = getTag(text)
			if text == '#' + tag
				send_chat_retrieve(tag)
			else
				send_chat(tag, text)
			end
		else
			if text == 'KILL_SERVICE'
				send_leaving_network()
			end
		end
	end

	def send_chat_retrieve(tag)
		target_id = hashcode(tag)
		target_node_id = @routing_table.get_next_from_ls(target_id)
		if target_node_id == @identifier
			# puts @chat_record.retrieveChat(tag)
			for msg in @chat_record.retrieveChat(tag)
				puts msg['text']
			end
		else
			target_port = @routing_table.getport(target_node_id)
			message = Hash.new()
			message['type'] = 'CHAT_RETRIEVE'
			message['tag'] = tag
			message['node_id'] = target_id
			message['sender_id'] = @identifier
			msg = JSON.generate(message)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		end
	end

	def send_chat(tag, text)
		target_id = hashcode(tag)
		target_node_id = @routing_table.get_next_from_ls(target_id)
		if target_node_id == @identifier
			@chat_record.insertChat(tag, text, @identifier)
			# p @chat_record.retrieveChat(tag)
			for msg in @chat_record.retrieveChat(tag)
				puts msg['text']
			end
			return
		else
			target_port = @routing_table.getport(target_node_id)
			message = Hash.new()
			message["type"] = "CHAT"
			message["target_id"] = target_id
			message["sender_id"] = @identifier
			message["tag"] = tag
			message["text"] = text
			msg = JSON.generate(message)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		end
		@time_out.start(tag)
		tout = @time_out.monitor(tag, 5)
		if tout == false
			send_ping(target_id)
		end
	end

	def send_ping(target_id)
		target_node_id = @routing_table.get_next_from_ls(target_id)
		if target_node_id == @identifier
		else
			target_port = @routing_table.getport(target_node_id)
			message = Hash.new()
			message['type'] = 'PING'
			message['target_id'] = target_id
			message['sender_id'] = @identifier
			message['port'] = @selfport
			msg = JSON.generate(message)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
			@time_out.start(target_id)
			tout = @time_out.monitor(target_id, 5)
			if tout == false
				puts "we will delete this node #{target_node_id}"
				@routing_table.del(target_node_id)
			end
		end
	end

	def send_leaving_network()
		message = Hash.new()
		message['type'] = "LEAVING_NETWORK"
		message['node_id'] = @identifier
		msg = JSON.generate(message)
		for target in @routing_table.routing_table.keys
			target_port = @routing_table.routing_table[target]
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		end
	end

	def handle_client(text)
		message = JSON.parse(text)
		message_type = message['type']
		case message_type
		when 'JOINING_NETWORK'
			joining_network(message['node_id'], message['port'])
		when 'JOINING_NETWORK_RELAY'
			joining_network_relay(message['node_id'], message['gateway_id'], \
				message['port'], text)
		when 'ROUTING_INFO'
			routing_info(message['gateway_id'], message['node_id'], \
				message['route_table'], text)
		when 'LEAVING_NETWORK'
			leaving_network(message['node_id'])
		when 'CHAT'
			chat(message['target_id'], message['sender_id'], message['tag'], \
				message['text'], text)
		when 'ACK_CHAT'
			ack_chat(message['node_id'], message['tag'], text)
		when 'CHAT_RETRIEVE'
			chat_retrieve(message['tag'], message['node_id'], \
				message['sender_id'], text)
		when 'CHAT_RESPONSE'
			chat_response(message['sender_id'], message['response'], text)
		when 'PING'
			ping(message['target_id'], message['sender_id'], message['port'])
		when 'ACK'
			ack(message['node_id'])
		end
	end

	def joining_network(node_id, port)
		routing_message = generate_routing_info(@identifier, node_id, port)
		s = UDPSocket.new()
		s.send(routing_message, 0, '127.0.0.1', port)
		send_joining_relay(node_id, port)
		@routing_table.insertNode(node_id, port)
	end

	def send_joining_relay(node_id, port)
		message = Hash.new()
		message['type'] = 'JOINING_NETWORK_RELAY'
		message['node_id'] = node_id
		message['gateway_id'] = @identifier
		message['port'] = port
		msg = JSON.generate(message)
		target = @routing_table.get_next_from_ls(node_id)
		if target == @identifier
		else
			target_port = @routing_table.getport(target)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		end
	end

	def joining_network_relay(node_id, gateway_id, port, msg)
		routing_message = generate_routing_info(gateway_id, node_id, @selfport)
		target = @routing_table.get_next_from_ls(node_id)
		if target == @identifier
			@routing_table.insertNode(node_id, port)
		else
			target_port = @routing_table.getport(target)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		end
		target_gateway = @routing_table.get_next_from_ls(gateway_id)
		target_gateway_port = @routing_table.getport(target_gateway)
		s = UDPSocket.new()
		s.send(routing_message, 0, '127.0.0.1', target_gateway_port)
	end

	def routing_info(gateway_id, node_id, routing_table, msg)
		if node_id.to_i == @identifier
			@routing_table.merge(routing_table)
			@routing_table.insertNode(gateway_id, @destport)
			return
		end		
		if gateway_id == @identifier
			target = @routing_table.get_next_from_ls(node_id)
			target_port = @routing_table.getport(target)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		else
		############## here may be a bug!!!!!!!
			target = @routing_table.get_next_from_ls(gateway_id)
			target_port = @routing_table.getport(target)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', target_port)
		############## here may be a bug!!!!!!!
		end
	end

	def leaving_network(node_id)
		@routing_table.del(node_id)
	end

	def chat(target_id, sender_id, tag, text, msg)
		next_hop = @routing_table.get_next_from_ls(target_id)
		if next_hop == @identifier
			@chat_record.insertChat(tag, text, sender_id)
			# p @chat_record.retrieveChat(tag)
			for msg in @chat_record.retrieveChat(tag)
				puts msg['text']
			end
			send_ack_chat(sender_id, tag)
			send_chat_response(tag, sender_id)
		else
			next_hop_port = @routing_table.getport(next_hop)
			s = UDPSocket.new()
			s.send(msg, 0, '127.0.0.1', next_hop_port)
		end
	end

	def send_ack_chat(sender_id, tag)
		message = Hash.new()
		message['type'] = 'ACK_CHAT'
		message['node_id'] = sender_id
		message['tag'] = tag
		msg = JSON.generate(message)
		target = @routing_table.get_next_from_ls(sender_id)
		target_port = @routing_table.getport(target)
		s = UDPSocket.new()
		s.send(msg, 0, '127.0.0.1', target_port)
	end

	def send_chat_response(tag, sender_id)
		message = Hash.new()
		message['type'] = "CHAT_RESPONSE"
		message['tag'] = tag
		message['node_id'] = @identifier
		message['sender_id'] = sender_id
		message['response'] = @chat_record.retrieveChat(tag)
		msg = JSON.generate(message)
		target = @routing_table.get_next_from_ls(sender_id)
		target_port = @routing_table.getport(target)
		s = UDPSocket.new()
		s.send(msg, 0, '127.0.0.1', target_port)
	end

	def ack_chat(node_id, tag, text)
		if node_id == @identifier
			@time_out.stop_monitor(tag)
		else
			target_id = @routing_table.get_next_from_ls(node_id)
			target_port = @routing_table.getport(target_id)
			s = UDPSocket.new()
			s.send(text, 0, '127.0.0.1', target_port)
		end
	end

	def chat_retrieve(tag, node_id, sender_id, text)
		target_id = @routing_table.get_next_from_ls(node_id)
		if target_id == @identifier
			send_chat_response(tag, sender_id)
		else
			target_port = @routing_table.getport(target_id)
			s = UDPSocket.new()
			s.send(text, 0, '127.0.0.1', target_port)
		end
	end

	def chat_response(sender_id, response, text)
		if sender_id == @identifier
			for msg in response
				puts msg['text']
			end
		else
			target_id = @routing_table.get_next_from_ls(sender_id)
			target_port = @routing_table.getport(target_id)
			s = UDPSocket.new()
			s.send(text, 0, '127.0.0.1', target_port)
		end
	end

	def ping(target_id, sender_id, port)
		send_ack(target_id, port)
		target_node_id = @routing_table.get_next_from_ls(target_id)
		if target_node_id == @identifier
		else
			send_ping(target_id)
		end
	end

	def send_ack(target_id, port)
		message = Hash.new()
		message['type'] = 'ACK'
		message['node_id'] = target_id
		message['port'] = @selfport
		msg = JSON.generate(message)
		s = UDPSocket.new()
		s.send(msg, 0, '127.0.0.1', port)
	end

	def ack(node_id)
		@time_out.stop_monitor(node_id)
	end

	def hashcode(s)
		hash = 0
		for i in 0..(s.length-1)
			hash = hash * 31 + s[i].ord
		end
		return hash
	end

	def generate_routing_info(gateway_id, node_id, port_number)
		routing_info = Hash.new()
		routing_info['type'] = 'ROUTING_INFO'
		routing_info['gateway_id'] = gateway_id
		routing_info['node_id'] = node_id
		routing_info['port_number'] = port_number
		routing_info['route_table'] = Array.new()
		for node_id in @routing_table.routing_table.keys
			temp = Hash.new
			temp['node_id'] = node_id
			temp['port'] = @routing_table.getport(node_id)
			routing_info['route_table'] << temp
		end
		msg = JSON.generate(routing_info)
		return msg
	end

	def getTag(text)
		flag = text.index('#')
		flag_end = text.index(' ', flag)
		if flag_end == nil
			flag_end = text.index('.', flag)
			if flag_end == nil
				flag_end = text.index(',', flag)
			end
		end
		if flag_end == nil
			flag_end = 0
		end
		tag = text[(flag + 1)..(flag_end - 1)]
		return tag
	end


end