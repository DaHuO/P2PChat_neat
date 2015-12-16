# so far, the node number is small, so I put all the known nodes to the 
# leaf set, and a altered way of routing table, so that all the known 
# nodes will be in the routing table.

class RoutingTable
	def initialize(identifier)
		@routing_table = Hash.new
		@rt = Hash.new # the routing table used for prefix routing
		@ls_l = Array.new # the half leaf set whose nodeid is smaller
		@ls_r = Array.new # the half leaf set whose nodeid is larger
		@selfId = identifier
		@selfIdHex = @selfId.to_s(16)
		if @selfIdHex.length != 32
			@selfIdHex = '0' * (32 - @selfIdHex.length) + @selfIdHex
		end
	end

	attr_reader :routing_table

	def insertNode(node_id, port_number)
		node_id = node_id.to_i
		if @routing_table.has_key?node_id
			return
		else
			@routing_table[node_id] = port_number
			node_id_hex = node_id.to_i.to_s(16)
			if node_id_hex.length != 32
				node_id_hex = '0' * (32 - node_id_hex.length) + node_id_hex
			end
			prefix = string_compare(@selfIdHex, node_id_hex)
			if @rt[prefix] == nil
				@rt[prefix] = Array.new
			end
			@rt[prefix] << node_id
			if node_id == @selfId
				return
			end
			push_to_ls(node_id.to_i)
		end
	end

	def del(node_id)
		node_id = node_id.to_i
		@routing_table.delete(node_id)
		@ls_l.delete(node_id)
		@ls_r.delete(node_id)
		node_id_hex = node_id.to_i.to_s(16)
		if node_id_hex.length != 32
			node_id_hex = '0' * (32 - node_id_hex.length) + node_id_hex
		end
		prefix = string_compare(@selfIdHex, node_id_hex)
		@rt[prefix].delete(node_id)
	end

	def getport(node_id)
		node_id = node_id.to_i
		return @routing_table[node_id]
	end

	def merge(rt)	# for merge routing information
		if rt == nil
			return
		end
		for info in rt
			if @routing_table.has_key?(info['node_id'])
			else
				# @routing_table[info['node_id']] = info['port']
				insertNode(info['node_id'], info['port'])
			end
		end
	end

	def push_to_ls(node_id)
		node_id = node_id.to_i
		if(node_id < @selfId.to_i)
			insert_to_ls(@ls_l, node_id)
		else
			insert_to_ls(@ls_r, node_id)
		end
	end

	def string_compare(s1, s2)
		for i in 0..(s1.length - 1)
			if s1[i]!= s2[i]
				return i
			end
		end
		return s1.length
	end

	def insert_to_ls(ls, node_id)
		node_id = node_id.to_i
		if ls.include? node_id
			return
		end
		if ls.length == 0
			ls << node_id
		else
			for i in 0..(ls.length - 1)
				if ls[i] > node_id
					ls.insert(i, node_id)
					return
				end
			end
			ls << node_id
		end
	end

	def get_next_from_ls(node_id)
		node_id = node_id.to_i
		if node_id.class != 'Fixnum'
			node_id = node_id.to_i
		end
		if @routing_table.has_key?node_id
			return node_id
		end
		if node_id < @selfId
			if @ls_l.length == 0
				return @selfId
			end
			temp = @ls_l
			unless temp.include?(@selfId)
				temp << @selfId
			end
			bigger = @selfId
			smaller = @ls_l[0]
			for i in 1..(temp.length - 1)
				if temp[temp.length - i - 1] > node_id
					bigger = temp[temp.length - i - 1]
				elsif temp[temp.length - i - 1] < node_id
					smaller = temp[temp.length - i -1]
					break
				else
					return node_id
				end
			end
			if smaller == bigger
				return smaller
			end
			if (node_id - smaller) < (bigger - node_id)
				return smaller
			else
				return bigger
			end
		else
			if @ls_r.length == 0
				return @selfId
			end
			temp = @ls_r
			unless temp.include?(@selfId)
				temp.insert(0, @selfId)
			end
			smaller = @selfId
			bigger = @ls_r[-1]
			for i in 1..(temp.length - 1)
				if temp[i] < node_id
					smaller = temp[i]
				elsif temp[i] > node_id
					bigger = temp[i]
					break
				else
					return node_id
				end
			end
			if smaller == bigger
				return smaller
			end
			if (node_id - smaller) < (bigger - node_id)
				return smaller
			else
				return bigger
			end
		end
	end


end