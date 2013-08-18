#!/usr/bin/env ruby

#SWAGBOT
#
# Maintained by Timothy Williams <tiwillia@redhat.com>

# Todo:
# I implemented  the sendchn method in a way that requires an argument
# to be passed that can really be an instance variable. Need to fix that.

class Swagbot

require 'socket'
require 'open-uri'
require 'json/ext'
require 'rubygems'
require 'active_record'
require 'yaml'
require 'pg'
require 'nokogiri'

# Initialize variables
def initialize(host, port, nick, chan, dir)
	puts "initializing"
	@host = host
	@port = port
	@nick = nick
	@chan = chan
	@root_dir = dir
  @files_dir = "#{@root_dir}/#{@nick}-files"
	@simpsons = "#{@files_dir}/simpsons.txt"
	@anchorman = "#{@files_dir}/anchorman.txt"
	@blowmymind = "#{@files_dir}/blowmymind.txt"
  Dir.glob(@root_dir + "/app/models/*.rb").each{|f| require f}
  dbconfig = YAML::load(File.open('config/database.yml'))
  ActiveRecord::Base.establish_connection(dbconfig)
  check_files
end

def check_files
	if Dir.exist?(@files_dir) == false
		Dir.mkdir(@files_dir, 0775)
		Dir.chdir(@files_dir)
	else
		Dir.chdir(@files_dir)
		case
		when File.exist?("simpsons.txt") == false
                        `cp #{@root_dir}/swagbot-files/simpsons.txt .`
		when File.exist?("anchorman.txt") == false
                        `cp #{@root_dir}/swagbot-files/anchorman.txt .`
		when File.exist?("blowmymind.txt") == false
                        `cp #{@root_dir}/swagbot-files/blowmymind.txt .`
		end			
	end
end

# Small function to easily send commands
def send(msg)
	@socket.send "#{msg}\n", 0
end

# Small function to easily send messages to @chan
def sendchn(msg, chan)
	@socket.send ":source PRIVMSG #{chan} :#{msg}\n" , 0
end

def join_chan(chan)
	send ":source JOIN #{chan}"
end

def leave_chan(chan)
	send ":source PART #{chan}"
end

# This must be run fist
# It opens up the socket connection
# Logs in with the specified @nick
# And joins the @chan
def connect()
	puts "entered connect thread"
	@socket = TCPSocket.open(@host, @port)
	send "USER #{@nick} 0 * #{@nick}"
	send "NICK #{@nick}"
	send ":source PRIVMSG userserv :login #{@nick} swagswag"
	send "JOIN #{@chan}"
	`logger "#{@nick} connected to #{@host}"`
end

# Closes the socket connection
def kill()
	@socket.send(":source QUIT :SWAG\n", 0)
	@socket.close
	`logger "#{@nick} quit from #{@host}"`
end

# Create a user and id if it doesn't exist
# Return the corresponding User ActiveRecord::Relation object
def getuser(user)
  if Users.where(:user => user).present?
    Users.find_by(user: user)
  else
    new_user = Users.new(user: user)
    new_user.save
    new_user
  end
end

# Random number generator, excludes 0
def rdnum(seq)
  today = DateTime.now
  seed = today.strftime(format='%3N').to_i
  prng = Random.new(seed)
  prng.rand(1..seq)
end

def editkarma(giver, receiver, type, chan)
	#Here we need to parse the db for name, get the number, add one to the number
	#Syntax of the db will be user:number\n
  recipient = getuser(receiver)
  grantor = Users.find_by(user: giver) 

  case
	when type.eql?("add")
		karma_amount = 1 
	when type.eql?("subtract")
		karma_amount = -1
	else
		karma_amount = 0
	end
    
  Karma.new do |k|
    k.grantor_id = grantor.id
    k.recipient_id = recipient.id
    k.amount = karma_amount
  end
  
  if KarmaStats.where(:user_id => recipient.id).present?
    stat = KarmaStats.find_by(user_id: recipient.id)
    stat.total = stat.total + karma_amount
    stat.save
  else
    stat = KarmaStats.new(user_id: recipient.id, total: karma_amount)
    stat.save
  end  
  
  counter = 1
  KarmaStats.where.not(total: 0).order('total DESC').each do |x|
    x.rank = counter
    x.save
    counter += 1
  end  
  
  if stat.rank.present?
    rank_msg = " (rank #{stat.rank})"
  else
    rank_msg = ""
  end

	sendchn("#{receiver} now has #{stat.total} karma.#{rank_msg}",chan)
end

def rank(who, chan)
	#Here we are going to create a rank command
	#If no who is specified, list the top 5
	#if a who is specified, display their rank.
	#Might also use this as a way to add on the to editkarma command
  counter = 1
  KarmaStats.where.not(total: 0).order('total DESC').each do |x|
    x.rank = counter
    counter += 1
  end

  if who == "all"
		KarmaStats.where.not(total: 0).order('rank ASC').limit(5).each do |x|
      user_obj = Users.find(x.user_id)
			sendchn("#{x.rank}: #{user_obj.user} with #{x.total} points of karma",chan)
		end
	else
		user = getuser(who)

    if KarmaStats.where(user_id: user.id).present?
      stat = KarmaStats.find_by(user_id: user.id)
      rank = stat.rank
      case
      when rank.to_s.match(/^1.$/)
        suffix = "th"
      when rank.to_s.match(/.*[4-9,0]$/)
        suffix = "th"
      when rank.to_s.match(/.*3$/)
        suffix = "rd"
      when rank.to_s.match(/.*2$/)
        suffix = "nd"
      when rank.to_s.match(/.*1$/)
        suffix = "st"
      end
      sendchn("#{user.user} is #{rank}#{suffix} with #{stat.total} points of karma",chan)
    else
      sendchn("#{user.user} has never had karma added or subtracted.",chan)
    end
	end
end

# Adds a quote to the file swagbot-files/quotedb
def addquote(recorder, quotee, quote, chan)
  recorder = getuser(recorder)
  quotee = getuser(quotee)
  quote_obj = Quotes.new(recorder_id: recorder.id, quotee_id: quotee.id, quote: quote)
	quote_obj.save
  sendchn("Quote for #{quotee.user} added with id: #{quote_obj.id}",chan)
end

# Reads a quote from the file swagbot-files/quotedb
def echo_quote_by_user(who, chan)
  quotee = getuser(who)
  quote = Quotes.where(quotee_id: quotee.id).first(:offset => rand(Quotes.where(quotee_id: quotee.id).count))
  quotee = Users.find(quote.quotee_id)
  sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}",chan)
end

def echo_random_quote(chan)
  id = rdnum(Quotes.count)
  quote = Quotes.find(id)
  quotee = Users.find(quote.quotee_id)
  sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}",chan)
end

def echo_quote_by_id(id, chan)
  quote = Quotes.find(id)
  quotee = Users.find(quote.quotee_id)
  sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}",chan)
end

# This will grab the title and possibly description of a bugzilla link and display it
def bugzilla(url, chan)
  doc = Nokogiri::HTML(open(url))
  number = url.split("=").last
  title = doc.xpath('//span[@id="short_desc_nonedit_display"]/text()')
  status = doc.xpath('//span[@id="static_bug_status"]/text()')
  sendchn("Bugzilla: ##{number} \"#{title}\" : #{status}", chan)
end

# This will grab the title of a youtube link and display it
def youtube(url, chan)
  doc = Nokogiri::HTML(open(url))
  title = doc.xpath('//span[@id="eow-title"]/@title')
  views = doc.css('span.watch-view-count').first.content.strip
  sendchn("Youtube: \"#{title}\" : #{views} views", chan)
end

# This will grab the title of an imgur link and display it
def imgur(url, chan)
  doc = Nokogiri::HTML(open(url))
  img_id = url.split("/").last
  title = doc.xpath("//h2").last.content
  timestamp = doc.xpath('//div[@id="stats-submit-date"]/@title').to_s.gsub(/\ at.*/, "")
  points = doc.css("span.points-#{img_id}").first.content
  sendchn("Imgur: \"#{title}\" #{points} points, Posted on #{timestamp}", chan)
end

# Definitions can be accessed with the echo_definition method
def add_definition(word, definition, recorder, chan)
	recorder = getuser(recorder)
  definition = Definitions.create(recorder_id: recorder.id, word: word, definition: definition)
  definition.save
  sendchn("Ok, I'll remember #{word}", chan)
end

def forget_definition(word, chan)
	definition = Definitions.where(word: word).order('id ASC')
  if definition.present?
    definition.last.destroy
    sendchn("Deleted #{word}'s latest definition.", chan)
	else
		sendchn("How can I forget what I do not know?", chan)
	end
end

# Sends the definition added with add_definition
def echo_definition_by_word(word, chan)
	Definitions.where(word: word).each do |d|
      sendchn("#{d.word} is #{d.definition}", chan)
  end
end

def echo_definition_by_id(id, chan)
  Definitions.where(id: id).each do |d|
      sendchn("#{d.word} is #{d.definition}", chan)
  end 
end

def echo_definition_by_user(who, chan)
  Definitions.where(recorder: who).each do |d|
      sendchn("#{d.word} is #{d.definition}", chan)
  end
end

# Returns a random line from the file specified
# File must be in the same directory
# Or a full path (i.e. /home/you/Documents/file.txt)
def pick_random_line(file)
	chosen_line = nil
	if not File.exists?(file)
                File.new(file, "a")
        end
	File.foreach(file).each_with_index do |line, number|
	chosen_line = line if rand < 1.0/(number+1)
	end
	return chosen_line
end

# This is the main loop that keeps swagbot running
# This is also where we evaluate what is said in the channel
# If you would like to add a commad (swagbot: command) do it in the first case statement
# Otherwise, use the second one.
def loop()
		line = @socket.gets
    line = line.strip
		
    # Grab the nick of the userposting
    userposting = line[/^:([\|\.\-0-9a-zA-Z]*)!/, 1]
		if line.match(/^:.*\ PRIVMSG\ #{@nick}\ \:.*/)
                        channel = userposting
		else
			channel = line[/\ (#[\|\.\-0-9a-zA-Z]*)\ :/, 1]
		end
		
    # Ignore kbenson
    if userposting.eql?("kbenson")
			return
		end

    # Add the user to the users table if they do not exist
    if !Users.find_by(user: userposting)
      new_user = Users.create(user: userposting)
      tions.where(id: id).each do |d|
      sendchn("#{d.word} is #{d.definition}", chan)
  end
sendchn("New user #{userposting} added to the db with id: #{new_user.id}", channel)
    end	

		if line.match(/.*\:#{@nick}[\,\:\ ]+.*/) then
			params = line[/.*\:#{@nick}[\,\:\ ]+(.*)/, 1]
			case
			when params.match(/^join\ \#[\-\_\.\'0-9a-zA-Z]+/)
				channel_to_join = params[/^join\ (\#[\-\_\.\'0-9a-zA-Z]+)/, 1]
				join_chan(channel_to_join)
			when params.match(/^leave/)
				if channel == userposting
					sendchn("Say it in the channel you want me to leave.", channel)
				else
					leave_chan(channel)
				end
			when params.match(/^[\-\_\.\'\.0-9a-zA-Z]*\ is\ .*/)
				word_to_define = params[/([\-\_\.\'0-9a-zA-Z]*)\ is/, 1]
				definition = params[/[\-\_\ \.\'0-9a-zA-Z]*\ is\ (.*)/, 1]
				add_definition(word_to_define, definition, userposting, channel)
			when params.match(/^[\-\_\.0-9a-zA-Z]*\?/)
				word_to_echo_def = params[/([\-\_\.0-9a-zA-Z]*)?/, 1]
				echo_definition_by_word(word_to_echo_def, channel)
			when params.match(/^forget\ [\-\_\ 0-9a-zA-Z]*/)
				word_to_forget = params[/forget\ ([\-\_\ 0-9a-zA-Z]*)/, 1]
				forget_definition(word_to_forget, channel)
			when params.match(/^addquote.*/)
				user_to_quote = line[/addquote\ ([0-9a-zA-Z\-\_\.\|]+)\ .*/, 1]
				new_quote = line[/addquote\ [0-9a-zA-Z\-\_\.\|]+\ (.*)/, 1]
        p new_quote
				addquote(userposting, user_to_quote, new_quote, channel)				
			when params.match(/^quote.*/)
				if params.match(/quote\ [0-9]+$/)
					echo_quote_by_id(params[/quote\ (.*)/, 1], channel)
        elsif params.match(/quote\ [a-zA-Z0-9\.\_\-\|]+/)
          echo_quote_by_user(params[/quote\ (.*)/, 1], channel)
        else
          echo_random_quote(channel) 
				end
			when params.match(/^rank.*/)
				if params.eql?("rank")
					rank("all", channel)
				else
					user_to_rank = params[/rank\ (.*)/, 1]
					rank(user_to_rank, channel)
				end
			when params.eql?("time")
				time = Time.new
				timenow = time.inspect
				sendchn("The current time is #{timenow}", channel)
			when params.eql?("weather")
				# Yahoo Weather Variables
                                yahoo_url = 'http://query.yahooapis.com/v1/public/yql?format=json&q='
                                query = "SELECT * FROM weather.forecast WHERE location = 27606"
                                url = URI.encode(yahoo_url + query)
                                # Pull and parse data
                                weather_data = JSON.parse(open(url).read)
                                weather_results = weather_data["query"]["results"]["channel"]
                                sendchn("------------------Weather For 27606---------------", channel)
				sendchn("Current conditions: #{weather_results["wind"]["chill"]} degrees and #{weather_results["item"]["forecast"][0]["text"]}", channel)
                                sendchn("Windspeed: #{weather_results["wind"]["speed"]}mph", channel)
                                sendchn("High: #{weather_results["item"]["forecast"][0]["high"]} degrees", channel)
                                sendchn("Low: #{weather_results["item"]["forecast"][0]["low"]} degrees", channel)
                                sendchn("-----------------------------------------------------------", channel)
			
			when params.eql?("simpsons")
				quote = pick_random_line(@simpsons)
                                sendchn("#{quote}", channel)
			when params.eql?("anchorman")
				quote = pick_random_line(@anchorman)
                                sendchn("#{quote}", channel)
			when params.eql?("blowmymind")
                                quote = pick_random_line(@blowmymind)
                                sendchn("#{quote}", channel)
			when params.match(/^help.*/)
                                case 
                                when  params.eql?("help")
                                        sendchn("#{@nick}: help [command]", channel)
					sendchn("#{@nick}: <noun> is <definition>", channel)
					sendchn("#{@nick}: <noun>?", channel)
                                        sendchn("#{@nick}: addquote <name> <quote WITHOUT \"\">", channel)
                                        sendchn("#{@nick}: quote [name]", channel)
                                        sendchn("<name>++", channel)
                                        sendchn("<name>--", channel)
					sendchn("#{@nick} rank", channel)
					sendchn("#{@nick} rank <name>", channel)
                                        sendchn("#{@nick}: time", channel)
                                        sendchn("#{@nick}: weather", channel)
                                        sendchn("#{@nick}: simpsons", channel)
                                        sendchn("#{@nick}: anchorman", channel)
					sendchn("#{@nick}: blowmymind", channel)
					sendchn("#{@nick}: leave", channel)
					sendchn("#{@nick}: join <#channel>", channel)                                        
                                when params.eql?("help addquote")
                                        sendchn("Usage: #{@nick}: addquote <name> <quote WITHOUT \"\">", channel)
                                        sendchn("Adds a quote to the quote database", channel)
                                        sendchn("Quotes can be recalled with #{@nick}: quote [name]", channel)
                                         
                                when params.eql?("help quote")
                                        sendchn("Usage: #{@nick}: quote [name]", channel)
                                        sendchn("Returns a quote from the quote database", channel)
                                        sendchn("If no name is supplied, a random quote will be returned", channel)
                                         
                                when params.eql?("help time")
                                        sendchn("I don't know why you want help with this one #{userposting}...", channel)
                                        sendchn("It was more of a way to test getting the time", channel)
                                        sendchn("Eventually, the time will be used for other commands", channel)
                                         
                                when params.eql?("help weather")
                                        sendchn("PLACEHOLDER", channel)
                                         
                                when params.eql?("help simpsons")
                                        sendchn("Returns a random quote from The Simpsons", channel)
                                         
                                when params.eql?("help anchorman")
                                        sendchn("Returns a random quote from Anchorman", channel)
                                         
				when params.eql?("help blowmymind")
                                        sendchn("I will blow your mind", channel)
                                         
                                end
			end
		else
			case
			# This one is super important
			# It makes sure swagbot doesn't get disconnected
			when line.match(/^PING :(.*)$/)
				send "PONG #{$~[1]}"

			# Accept invites to channels
			when line.match(/\ INVITE #{@nick}\ \:\#.*/)
				invited_channel = line[/#{@nick}\ \:(\#.*)/, 1]
				join_chan(invited_channel)
				sendchn("I was invited here by #{userposting}. If I am not welcome type \"#{@nick} leave\"", invited_channel)
			
			# Karma assignments
			when line.match(/^.*[\-\.\'\.\|0-9a-zA-Z]+[\+\-]{2}.*/)
				if channel != userposting
					line.split.each do |x| 
						if x.match(/[\-\.\'\.\|0-9a-zA-Z]+\+\+/)
							user = x[/([\-\.\'\.\|0-9a-zA-Z]*)\+\+/, 1]
							if user == userposting
								sendchn("Lol, yeah right.", channel)
							else
								editkarma(userposting, user, "add", channel)
							end
						end
						if x.match(/[\-\.\'\.\|0-9a-zA-Z]+\-\-/)
							user = x[/([\-\.\'\.\|0-9a-zA-Z]*)\-\-/, 1]
							if user == userposting
								sendchn("#{userposting}, you okay? I'm not going to let you subtract karma from yourself.", channel)
							else
								editkarma(userposting, user, "subtract", channel)
							end
						end
					end
				else
					sendchn("Karma can only be assigned in a channel", channel)
				end

      when line.match(/.*http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+[\ ]*/)
        url = line[/.*(http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+)[\ ]*/, 1]
        bugzilla(url, channel)

      when line.match(/.*http[s]*:\/\/[w\.]*youtube.com\/watch.*/)
        url = line[/.*(http[s]*:\/\/[w\.]*youtube.com\/watch\?v=[a-zA-Z0-9]+)[\ ]*/, 1]
        youtube(url, channel)

      when line.match(/.*http[s]*:\/\/i.imgur.com\/.*/)
        url = line[/.*(http[s]*:\/\/i.imgur.com\/[a-zA-Z0-9]+)\..*/, 1]
        imgur(url, channel)
			end
	end
	return nil
end

# Anything after this will be ignored
end
