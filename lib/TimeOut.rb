class TimeOut
	def initialize
		@time_out = Hash.new
	end

	def start(tag)
		@time_out[tag] = [Time.now().to_i, true]
	end

	def monitor(tag, tim)
		while(1)
			if @time_out[tag][1] == false
				return true
			end
			if (Time.now().to_i - @time_out[tag][0]) > tim
				@time_out.delete(tag)
				return false
			end
		end
	end

	def stop_monitor(tag)
		@time_out[tag][1] = false
	end


end