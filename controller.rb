#!/usr/bin/env ruby

# This class is used as a highest-level class that controls many irc-bots
#

# NEED TO DO:
# Make all methods dynamic
# Add a method to swagbot.rb to join another channel, and have 
#    it differentiate between channels...
#
# STATUS:
# The class is working, but not the reload or stop functionality
# The stop method still needs to be completely re-done.
# We will likely have to implement a hash table that will store all of the threads
# This way, when we want to reload or stop a bot, we can kill/restart the thread
#
# The main listening thread is now the main thread. This is because all bots now
# have their own thread, and the main thread just sits and listens for input
# from the pipe. It is okay that the main thread blocks on the pipe because it
# doesn't need to do anything other than listen.
#
# Queue commands should be: 
# stop <bot>
# reload <bot>
# new <nick> <channel>
#
# bot will be called @bots[nickchannel], refer to line 75

###################################
# GLOBAL VARIABLES - DEFINE THESE #
###################################
# File locations
$root_dir = "/share/Projects/swagbot"
$ircfile = "#{$root_dir}/swagbot.rb"
$pipe = "#{$root_dir}/swagpipe"

# Server Settings
$server = "irc.devel.redhat.com"
$port = "6667"

# Initial bot settings
$botname = "swagbot"
$channel = "#swaggers"
#################################

class Controller

require 'socket'
require 'thread'

def initialize
	load $ircfile
	puts "loading #{$ircfile}"
	@bots = Hash.new
        @queue = Hash.new
	puts "Creating new bot"
	new_bot($botname, $channel)
	wait_alive
end

def new_bot(nick, channel)
	puts "Creating #{nick}#{channel}'s thread"
	running = Thread.new do
		puts "New thread created for #{nick} at #{channel}"
		if channel.match(/^\#.*/) == false
			actual_channel = "##{channel}"
			channel_name = channel
		else
			actual_channel = channel
			channel_name = channel[/^\#(.*)/, 1]
		end
		@queue["#{nick}#{channel_name}"] = Queue.new
		puts "created new queue"
		@bots["#{nick}#{channel_name}"] = Swagbot.new($server, $port, nick, actual_channel, $root_dir)
		puts @bots["#{nick}#{channel_name}"].inspect.split
		@bots["#{nick}#{channel_name}"].connect()
		puts "Connected, begining running loop"
		running_loop(@bots["#{nick}#{channel_name}"], nick, channel_name)
	end
end

def running_loop(bot, nick, channel)
	keep = true
	while keep
		while @queue["#{nick}#{channel}"].empty? do
			i = bot.loop()
	        end
		puts "queue isn't empty D:"
		if @queue["#{nick}#{channel}"].empty? == false		
			case @queue["#{nick}#{channel}"].pop
			when "stop"
				keep = false
				stop("#{nick}#{channel}")
			when "reload"
				keep = false
				reload("#{nick}#{channel}")
			end
		end
	end
end

def stop(bot)
	puts "stoppping"
	@swag.kill()
	@swag = nil
	wait_alive
end

def reload(bot)
        puts "reloading!"
        @queue[bot].clear
	nick = @bots[bot].instance_variable_get(nick)
        channel = @bots[bot].instance_variable_get(channel)
	@bots[bot].kill()
        @bots[bot] = nil
        load $ircfile
        new_bot(nick, channel)
end

def wait_alive
	loop do	
		input = `cat < #{$pipe}`
		if input != ""
			case input
			when /^[a-zA-Z0-9\-\_]+\ [stop][reload]$/
				current_bot = input[/^([a-zA-Z0-9\-\_]+)\ .*$/, 1]
				command = input[/^[a-zA-Z0-9\-\_]+\ (.*)$/, 1]
				if @queue[current_bot].exist? 
					case command
					when "stop" 
						@queue[current_bot] << "stop"
					when "reload"
						@queue[current_bot] << "reload"
					end
				else
					puts "No such bot"
				end
			when /^new\ [a-zA-Z0-9\-\_]+\ [a-zA-Z0-9\-\_\#]+$/
				new_booty = input[/^new\ ([a-zA-Z0-9\-\_]+)\ .*/, 1]
				new_channel = input[/^new\ [a-zA-Z0-9\-\_]+\ ([a-zA-Z0-9\-\_\#]+)$/, 1]
				new_bot(new_booty, new_channel)
			end
		end
	end
end

Controller.new()

end
