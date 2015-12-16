# P2PChat

THIS IS A NEAT RELEASE VERSION OF P2PCHAT WITHOUT DISPLAYING DEBUGING AND ROUTING INFORMATION. THE ORIGINAL VERSION CAN BE FOUND IN https://github.com/DaHuO/P2PChat .

This is a simple peer to peer chat program. There is no central control in the network, therefore it is a pure peer to peer network. The communication between nodes is UDP instead of TCP. It allows graceful shutdown, also it can detect node failure and tolerant few nodes failure.
Due to experiment machine constraint, in this version of code, different nodes are run on one single machine, which means each node share the same localhost '127.0.0.1', but they use different port number.

To start the program. If it is the first node, it should run in the command line as:
	"ruby start_server.rb --boot [Integer Identifier] [port]"
If it is joining a known node in the network, it should run in the command line as:
	"ruby start_server.rb ----bootstrap [port] --id [Integer Identifier] [port]' for join"

After the program starts, it will show "ARE you ready to start the chat? Y/N". If you wanna start the program input Y, else you input N to terminate the program.

Each chat message should contains a tag, for example: "I like #apple", then all the chat message about this tag will show up. If just want to get the chat message on some paticular tag, just input the tag, for example: "#apple", then the related messages will show up.


Filelist:

start_server.rb 	To handle the command line input parameter and to start the program.

server.rb 			This is the main server class. It processes all the related request and standerd input.

ThreadPool.rb 		The class of thread pool.

RoutingTable.rb 	The routing table class. It stores all the routing information and controls the routing.

ChatRecord.rb 		The chat record class. It stores all the chat messages and generate chat information.

TimeOut.rb 			The timeout class. It controls the timeout after sending a chat message and after sending a ping message.