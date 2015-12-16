class ChatRecord
	def initialize
		@records = Hash.new()
	end

	def insertChat(tag, msg, sender)
		unless @records.has_key?(tag)
			@records[tag] = Array.new()
		end
		@records[tag] << [msg, sender]
	end

	def retrieveChat(tag)
		response = Array.new()
		if @records.has_key?(tag)
			for msgs in @records[tag]
				message = Hash.new()
				message['text'] = msgs[0]
				response << message
			end
		end
		return response
	end
end