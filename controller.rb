#!/usr/bin/env ruby

###################################
# GLOBAL VARIABLES - DEFINE THESE #
# Eventually will be moved to     #
# an external conf file
###################################
# File locations
$root_dir = "/home/tiwillia/Projects/Swagbot"
$ircfile = "#{$root_dir}/swagbot.rb"

# Server Settings
$server = "irc.devel.redhat.com"
$port = "6667"

# Initial bot settings
$botname = "betabot"
$channel = "#betabot"

#Configurable bot options
$karma_wait = 5
$nickserv_password = "swagswag"
#################################

class Controller

require 'socket'

def initialize
	load $ircfile
	new_bot($botname, $channel)
end

def new_bot(nick, channel)
	bot = Swagbot.new($server, $port, nick, channel, $root_dir)
	puts bot.inspect.split
	bot.connect()
	puts "Connected, begining running loop"
	running_loop(bot)
end

def running_loop(bot)
	loop do
		bot.loop()
	end
end

Controller.new()

end
