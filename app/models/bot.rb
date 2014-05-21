class Bot < ActiveRecord::Base
  # These associations are necessary, or all bots will use the same karama/quotes/etc tables
  has_one :bot_config
  has_many :karma_entries
  has_many :definitions
  has_many :quotes
  has_many :karmastats
  has_many :users

  # Socket to create connections
  require 'socket'

  # Open-uri and JSONfor API interactions
  require 'open-uri'
  require 'json/ext'
  
  # After the bot is initialized, create instance variables
  # This is similar to overwriting the initialize method
  after_initialize :set_instance_vars

  # Initialize
  def set_instance_vars
    # Set initial timeout values
    @timers = Hash.new
    @timers[:karma] = Hash.new
    @timers[:ping] = Time.now.to_i
    @timers[:ncq_watcher] = Time.now
    @timers[:mentioned_cases] = Hash.new

    # initialize userposting - must be defined
    @userposting = "nil"

    # Define server connection settings
    @host = self.server
    @port = self.port
    @nick = self.nick
    @chan = self.channel
    @server_password = self.server_password
    @nickserv_password = self.nickserv_password
    @socket_timeout = 15

    # Unnecessary, but prettier than running 'self.xxxx' all over the place.
    @bot = self

    # Created mentioned cases array  
    @mentioned_cases = [] 
  end

  # Create a tcp socket to the specified server and join the irc channels
  def connect
    @socket = TCPSocket.open(@host, @port)
    if not @server_password == ""
      send_server "PASS #{@server_password}"
    end
    send_server "USER #{@nick} 0 * #{@nick}"
    send_server "NICK #{@nick}"
    if not @nickserv_password == ""
      send_server ":source PRIVMSG userserv :login #{@nick} #{@nickserv_password}"
    end
    join_chan @bot.channel
    @bot.bot_config(true).channels.each do |chan|
      join_chan chan
    end
  end

  # Kill the connection
  # Wait 2 seconds for slow servers
  def kill
    send_server(":source QUIT :#{@bot.bot_config(true).quit_message}")
    @socket.close
    sleep 2
  end

  ##### CONFIGURATIONS
  
  def definitions?
    @bot.bot_config(true).definitions
  end

  def quotes?
    @bot.bot_config(true).quotes
  end

  def karma?
    @bot.bot_config(true).karma
  end

  def youtube?
    @bot.bot_config(true).youtube
  end

  def imgur?
    @bot.bot_config(true).imgur
  end

  def bugzilla?
    @bot.bot_config(true).bugzilla
  end

  def weather?
    @bot.bot_config(true).weather
  end

  def operator_control?
    @bot.bot_config(true).operator_control
  end

  def operator_list?
    !@bot.bot_config(true).operator_any_user
  end

  def ncq_watcher?
    @bot.bot_config(true).ncq_watcher
  end

  def ncq_watch_details?
    @bot.bot_config(true).ncq_watch_details
  end

  ##### END CONFIGURATIONS

  # This should return the karmastat and user objects
  # of the top 5 karma recipients or a single recipient
  def get_rank(*who)
    
    rank_array = Array.new
    num_of_ranks = @bot.bot_config(true).num_of_karma_ranks

    # Calculate rank
    counter = 1
   

    # If we are getting all ranks, not just a single user
    if who.empty?
  
        # Calculate only the top X ranks
        @bot.karmastats.where('total is distinct from ?', '0').order('total DESC').limit(num_of_ranks).each do |x|
          if x.rank != counter
            x.update_attributes(:rank => counter)
          end
          counter += 1
        end
  
        @bot.karmastats.where('total is distinct from ?', '0').order('rank ASC').limit(num_of_ranks).each do |stat|
        user = @bot.users.find(stat.user_id)
        rank_hash = Hash[ "user" => user, "stat" => stat ]
        rank_array << rank_hash
      end
    else
      user = getuser(who)

      # Calculate all the ranks
      # TODO this is an extremely hefty operation
      @bot.karmastats.where('total is distinct from ?', '0').order('total DESC').each do |x|
        if x.rank != counter
          x.update_attributes(:rank => counter)
        end
        counter += 1
      end

      if @bot.karmastats.where(user_id: user.id).present?
        stat = @bot.karmastats.find_by_user_id(user.id)
        rank_hash = Hash[ "user" => user, "stat" => stat ]
        rank_array << rank_hash
      else
        return nil
      end
    end
    rank_array
  end

  # This is the main loop that uses all the private methods below it.
  def loop()
  
    # Get line from socket with a timeout
    within_timeout = IO.select([@socket], nil, nil, @socket_timeout)
    if within_timeout
      line = @socket.gets
    else
      Rails.logger.debug "No activity in channel for #{@socket_timeout} seconds"
      line = "TIMEOUT"
    end

    if line == nil
      return "connection lost"
    end

    # Strip the line of 
    line = line.strip

    # Grab the nick of the @userposting
    @userposting = line[/^:([\|\.\-0-9a-zA-Z]*)!/, 1]
    if line.match(/^:.*\ PRIVMSG\ #{@nick}\ \:.*/)
      @chan = @userposting
    else
      @chan = line[/\ (#[\|\.\-0-9a-zA-Z]*)\ :/, 1]
    end

    Rails.logger.debug "######### MESSAGE ###########"
    Rails.logger.debug line
    Rails.logger.debug "User Posting: #{@userposting}"
    Rails.logger.debug "Channel: #{@chan}"
    
    ## NCQ WATCHER AUTO CHECKER
    # Check NCQ Timer to do NCQ things
    if ncq_watcher?
      old_time = @timers[:ncq_watcher]
      seconds_past = Time.now - old_time
      if seconds_past > @bot.bot_config(true).ncq_watch_interval
        Rails.logger.debug "Checking NCQ for plates: #{@bot.bot_config(true).ncq_watch_plates.inspect}"
        @bot.bot_config(true).ncq_watch_plates.each do |plate|
          check_ncq(plate)
          @timers[:ncq_watcher] = Time.now
        end
      end
    end

    # When the socket times out, we need to wait until after the ncq_watcher to exit.
    if line == "TIMEOUT"
      Rails.logger.debug "######### END MESSAGE ###########"
      return nil
    end

    # Ignore unifiedbot
    # This should be removed when the configuration to add an ignore list is implemented

    # Add the user to the users table if they do not exist
    if not @userposting.blank?

      if @bot.bot_config(true).ignored_users.include? @userposting
        Rails.logger.debug "Message from ignored user #{@userposting}, ignoring message"
        Rails.logger.debug "######### END MESSAGE ###########"
        return
      end

      if @bot.users.where(user: @userposting).blank?
        Rails.logger.debug "Added user to database"
        new_user = @bot.users.create(user: @userposting)
        new_user.save
      end 

    end

    if line.match(/.*\:#{@nick}[\,\:\ ]+.*/i) then
      params = line[/.*\:#{@nick}[\,\:\ ]+(.*)/i, 1]
      Rails.logger.debug "Parameter included: #{params}"
      case

      # Join a channel
      when params.match(/^join\ \#[\-\_\.\'0-9a-zA-Z]+/)
        channel_to_join = params[/^join\ (\#[\-\_\.\'0-9a-zA-Z]+)/, 1]
        Rails.logger.debug "Joining channel #{channel_to_join}"
        join_chan(channel_to_join)

      # Leave current channel
      when params.match(/^leave/)
        if @chan == @userposting
          Rails.logger.debug "Private leave message, this is incorrect"
          sendchn("Say it in the channel you want me to leave.")
        else
          Rails.logger.debug "Instructed to leave #{@chan}, leaving..."
          leave_chan(@chan)
        end
      
      # Add channel to the auto-join list
      when params.match(/^add-channel/)
        channel_to_add = params[/^add-channel (.*)/, 1]
        Rails.logger.debug "Adding channel #{channel_to_add} to the auto-join list"
        add_auto_join_chan(channel_to_add)

      # Remove channel to the auto-join list
      when params.match(/^remove-channel/)
        channel_to_remove = params[/^remove-channel (.*)/, 1]
        Rails.logger.debug "Removing channel #{channel_to_remove} from the auto-join list"
        remove_auto_join_chan(channel_to_remove)

      ##### DEFINITONS
      
      # Add a definition
      when params.match(/^[\-\_\.\'\.0-9a-zA-Z]*\ is\ .*/) && definitions?
        word_to_define = params[/([\-\_\.\'0-9a-zA-Z]*)\ is/, 1]
        definition = params[/[\-\_\ \.\'0-9a-zA-Z]*\ is\ (.*)/, 1]
        add_definition(word_to_define, definition, @userposting)

      # Echo definition by word
      when params.match(/^[\-\_\.0-9a-zA-Z]*\?/) && definitions?
        if not @bot.definitions.count.zero?
          word_to_echo_def = params[/([\-\_\.0-9a-zA-Z]*)?/, 1]
          echo_definition_by_word(word_to_echo_def)
        end

      # Forget a definition
      when params.match(/^forget\ [\-\_\ 0-9a-zA-Z]*/) && definitions?
        word_to_forget = params[/forget\ ([\-\_\ 0-9a-zA-Z]*)/, 1]
        forget_definition(word_to_forget)

      ##### QUOTES

      # Add a quote
      when params.match(/^addquote.*/) && quotes?
        user_to_quote = line[/addquote\ ([0-9a-zA-Z\-\_\.\|]+)\ .*/, 1]
        new_quote = line[/addquote\ [0-9a-zA-Z\-\_\.\|]+\ (.*)/, 1]
        addquote(@userposting, user_to_quote, new_quote)  
  
      # Echo a quote
      when params.match(/^quote.*/) && quotes?
        Rails.logger.debug "Echoing quote, looking for type..."
        if params.match(/quote\ [0-9]+$/)
          quote_id = params[/quote\ (.*)/, 1]
          Rails.logger.debug "Echoing quote by id: #{quote_id}"
          echo_quote_by_id(quote_id)
        elsif params.match(/quote\ [a-zA-Z0-9\.\_\-\|]+/)
          echo_quote_by_user(params[/quote\ (.*)/, 1])
        else
          echo_random_quote(@chan) 
        end

      ##### KARMA RANKS
      
      # Echo karma ranks
      when params.match(/^rank.*/) && karma?
        if params.eql?("rank")
          rank
        elsif params.match("rank\ [a-zA-Z0-9\.\-\_\|]+")
          user_to_rank = params[/rank\ (.*)/, 1]
          rank(user_to_rank)
        end 

      ##### DIAGNOSTIC - FORCE CRASH
      when params.match(/^bust\-a\-nut.*/)
        raise "BOT MANUALLY CRASHED BY #{@userposting} at #{Time.now.to_s}."

      ##### NCQ Check
      when params.match(/check.*/)
        if params.eql?("check")
          sendchn("No sbr specified, checking defaults. Use #{@nick}, check <plate>.")
          plate = @bot.bot_config(true).ncq_watch_plates.first
        else
          plate = params[/check\ ([a-zA-Z0-9\ \&\-\_]+)/, 1]
        end
        plate = "Cloud Prods & Envs" unless plate != "cloud"
        check_ncq(plate, @userposting)
      
      # Weather reporting
      when params.match(/^weather.*/) && weather?
        if params.eql?("weather")
          zip = @bot.bot_config(true).default_weather_zip.to_s
        else
          zip = params[/weather\ (.*)/, 1]
        end
        
        if zip.length != 5 || zip.match(/[a-zA-Z]+/)
          sendchn("Invalid zip code")
        else
          yahoo_url = 'http://query.yahooapis.com/v1/public/yql?format=json&q='
          query = "SELECT * FROM weather.forecast WHERE location = #{zip}"
          url = URI.encode(yahoo_url + query)
          weather_data = JSON.parse(open(url).read)
          weather_results = weather_data["query"]["results"]["channel"]
          sendchn("-=[-------------- Weather For #{zip} --------------]=-")
          sendchn("   Conditions:  #{weather_results["wind"]["chill"]} degrees and #{weather_results["item"]["forecast"][0]["text"]}")
          sendchn("   Windspeed:   #{weather_results["wind"]["speed"]}mph")
          sendchn("   High:        #{weather_results["item"]["forecast"][0]["high"]} degrees")
          sendchn("   Low:         #{weather_results["item"]["forecast"][0]["low"]} degrees")
          sendchn("-=[------------------------------------------------]=-")
        end
        
        # Help section
        # This desperately needs to be re-worked
        when params.match(/^help.*/)
          case 
          when  params.eql?("help")
            sendchn("#{@nick}: help [command]")
            sendchn("#{@nick}: <noun> is <definition>") unless !definitions?
            sendchn("#{@nick}: <noun>?") unless !definitions?
            sendchn("#{@nick}: addquote <name> <quote WITHOUT \"\">") unless !quotes?
            sendchn("#{@nick}: quote [name]") unless !quotes?
            sendchn("<name>++") unless !karma?
            sendchn("<name>--") unless !karma?
            sendchn("#{@nick} rank") unless !karma?
            sendchn("#{@nick} rank <name>") unless !karma?
            sendchn("#{@nick}: time")
            sendchn("#{@nick}: weather")
            sendchn("#{@nick}: leave")
            sendchn("#{@nick}: join <#channel>")                                        
          when params.eql?("help addquote")
            sendchn("Usage: #{@nick}: addquote <name> <quote WITHOUT \"\">")
            sendchn("Adds a quote to the quote database")
            sendchn("Quotes can be recalled with #{@nick}: quote [name]")                                    
          when params.eql?("help quote")
            sendchn("Usage: #{@nick}: quote [name]")
            sendchn("Returns a quote from the quote database")
            sendchn("If no name is supplied, a random quote will be returned")                               
          when params.eql?("help time")
            sendchn("I don't know why you want help with this one #{@userposting}...")
          when params.eql?("help weather")
            sendchn("Weather is hardcoded to a zip code. Get used to it or kick me, IDGAF.")                               
          end
        end
      else
        Rails.logger.debug "Does not include a param, treating as non-command"
        case
        # This one is super important
        # It makes sure swagbot doesn't get disconnected
        when line.match(/^PING :(.*)$/)
          send_server "PONG #{$~[1]}"
          @timers[:ping] = Time.now.to_i 

        # Accept invites to channels
        when line.match(/\ INVITE #{@nick}\ \:\#.*/)
          invited_channel = line[/#{@nick}\ \:(\#.*)/, 1]
          join_chan(invited_channel)
          sendchn("I was invited here by #{@userposting}. If I am not welcome type \"#{@nick} leave\"")
        
        # Karma assignments
        when line.match(/^.*[\_\-\.\'\.\|0-9a-zA-Z]+[\+\-]{2}.*/) && karma?
          if @chan != @userposting
            line.split.each do |x| 
              if x.match(/[\_\-\.\'\.\|0-9a-zA-Z]+\+\+/)
                user = x[/([\_\-\.\'\.\|0-9a-zA-Z]*)\+\+/, 1]
                if user == @userposting
                  sendchn("Lol, yeah right.")
                else
                  editkarma(@userposting, user, "add")
                end
              end
              if x.match(/[\_\-\.\'\.\|0-9a-zA-Z]+\-\-/)
                user = x[/([\_\-\.\'\.\|0-9a-zA-Z]*)\-\-/, 1]
                editkarma(@userposting, user, "subtract")
              end
            end
          else
            sendchn("Karma can only be assigned in a channel")
          end

        # Echo definition without calling bot's nick
        when line.match(/.*\:[\_\-\.\'\.\|0-9a-zA-Z]+\?$/) && definitions?
          word_to_echo_def = line[/([\-\_\.0-9a-zA-Z]*)\?/, 1]
          echo_definition_by_word(word_to_echo_def)

        # This should set the user posting as operator, if possible.
        when line.match(/.*\:\!op$/)
          if operator_control?
            if operator_list? 
              if @bot.bot_config(true).operators.include?(@userposting) 
                send_server("MODE #{@chan} +o #{@userposting}")        
              end
            else
              send_server("MODE #{@chan} +o #{@userposting}")
            end
          end
        
        # Bugzilla link parsing
        when line.match(/.*http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+[\ ]*/) && bugzilla?
          url = line[/.*(http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+)[\ ]*/, 1]
          bugzilla(url)

        # Youtube link parsing
        when line.match(/.*http[s]*:\/\/[w\.]*youtube.com\/watch.*/) && youtube?
          url = line[/.*(http[s]*:\/\/[w\.]*youtube.com\/watch\?v=[a-zA-Z0-9\-\_]+)[\ ]*/, 1]
          youtube(url)
        
        # Imgur link parsing
        when line.match(/.*http[s]*:\/\/[i\.]*imgur.com\/gallery\/.*/) && imgur?
          url = line[/.*(http[s]*:\/\/[i\.]*imgur.com\/gallery\/[a-zA-Z0-9\-\_]+).*/, 1]
          imgur(url)
        when line.match(/.*http[s]*:\/\/[i\.]*imgur.com\/.*/) && imgur?
          url = line[/.*(http[s]*:\/\/[i\.]*imgur.com\/[a-zA-Z0-9\-\_]+).*/, 1]
          imgur(url)

        # http status dogs
        # This should be a configuration option too
        when line.match(/.*\!http\ [1-5]{1}[0-9]{2}/)
          url = line[/.*\!http\ ([1-5]{1}[0-9]{2})/, 1]
          sendchn("http://httpstatusdogs.com/" + url)
        end
    end

    Rails.logger.debug "######### END MESSAGE ###########"

    # If the last ping was greater than 20 minutes ago
    if (Time.now.to_i - @timers[:ping]) > 1200
      puts "Last ping was more than 20 minutes ago"
      @timers[:ping] = (Time.now.to_i - 600)
      return "reconnect"
    end
    return nil
  end

#private
 
#### UTILITIES ####
 
  # Small function to easily send messages to @chan
  def sendchn(msg)
    @chan = self.channel if @chan.nil?
    @socket.send ":source PRIVMSG #{@chan} :#{msg}\n" , 0
  end

  # Send non-formatted messages to the server
  # This is best for diagnostic and manual commands
  def send_server(msg)
    @socket.send "#{msg}\n", 0
  end

  # Join a channel
  def join_chan(chan)
    send_server ":source JOIN #{chan}"
  end
 
  # Add a channel to the auto-join list
  def add_auto_join_chan(chan)
    if not chan.match(/^\#/)
      chan = "#" + chan
    end
    if @bot.bot_config(true).channels.include? chan
      sendchn "#{chan} is already set to be auto-joined."
    else
      new_channels = @bot.bot_config(true).channels.push(chan)
      @bot.bot_config.update_attribute(:channels, new_channels)
      sendchn "#{chan} will be auto-joined the next time #{@nick} is started."
      sendchn "Use '#{@nick}, join #{chan}' to join #{chan} now."
    end
  end

  # Remove a channel to the auto-join list
  def remove_auto_join_chan(chan)
    if not chan.match(/^\#/)
      chan = "#" + chan
    end
    if @bot.bot_config(true).channels.include? chan
      new_channels = @bot.bot_config(true).channels.select {|c|
        !c.match(/#{chan}/)
      }
      @bot.bot_config.update_attribute(:channels, new_channels)
      sendchn "#{chan} will no longer be auto-joined."
    else
      sendchn "#{chan} is not in the auto-join list."
    end
  end
 
  # Leave a channel
  def leave_chan(chan)
    send_server ":source PART #{chan}"
  end

  # Generate random number seq characters long
  def rdnum(seq)
    today = DateTime.now
    seed = today.strftime(format='%3N').to_i
    prng = Random.new(seed)
    prng.rand(1..seq)
  end

  # Return a user object from a username string
  def getuser(user)
    if @bot.users.where(:user => user).present?
      @bot.users.find_by_user(user)
    else
      new_user = @bot.users.new(user: user)
      new_user.save
      new_user
    end
  end

  # Return a user object from an id integer or string
  def getuser_by_id(id)
    if @bot.users.where(:id => id).present?
      @bot.users.find(id)
    else
      nil
    end
  end

#### KARMA ####

  # Add or remove karma, depending on type
  def editkarma(giver, receiver, type)
    #Here we need to parse the db for name, get the number, add one to the number
    #Syntax of the db will be user:number\n
    if receiver.nil? || giver.nil?
      return false
    end
    receiver_orig = receiver.dup
    receiver.downcase!
    giver.downcase!
    recipient = getuser(receiver)
    grantor = getuser(giver)

    # Add timer
    # check for the timer before we set the timer, obviously.
    karma_timer = @timers[:karma].fetch(receiver, nil)
    if karma_timer
      time = @timers[:karma][receiver].fetch(grantor.user, nil)
      puts grantor.user
      puts @timers[:karma][receiver]
      puts @timers[:karma][receiver][grantor.user]
    else
      @timers[:karma][receiver] = Hash.new
      time = nil
    end
    if time.to_i != 0
      if time.to_i > (Time.now.to_i - @bot.bot_config(true).karma_timeout)
        send_server(":source PRIVMSG #{@userposting} :You must wait #{time.to_i - (Time.new.to_i - @bot.bot_config(true).karma_timeout)} more seconds before changing #{receiver}'s karma.\n")
        return
      elsif time.to_i < (Time.now.to_i - @bot.bot_config(true).karma_timeout)
        @timers[:karma][receiver][grantor.user] = Time.new.to_i 
      end
    else
      @timers[:karma][receiver][grantor.user] = Time.new.to_i 
    end

    # Set the Karma Amount
    case
    when type.eql?("add")
      karma_amount = 1
    when type.eql?("subtract")
      karma_amount = -1
    else
      karma_amount = 0
    end

    # Create the new karma row
    new_karma_entry = @bot.karma_entries.create(grantor_id: grantor.id, recipient_id: recipient.id, amount: karma_amount)
    new_karma_entry.save

    # Update the user's karma running total in karmastats
    if @bot.karmastats.where(user_id: recipient.id).present?
      stat = @bot.karmastats.find_by_user_id(recipient.id)
      stat.total = stat.total + karma_amount
      stat.save
    else
      stat = @bot.karmastats.new(user_id: recipient.id, total: karma_amount)
      stat.save
    end

    sendchn("#{receiver_orig} now has #{stat.total} karma.")
  end

  # Get ranks and send them to the channel, as necessary.
  def rank(who = nil)
    if who.nil? 
      ranks = get_rank
    else
      ranks = get_rank(who)
    end
 
    if ranks
      if ranks.count > 1
        ranks.each do |r|
          sendchn("#{r["stat"].rank}: #{r["user"].user} with #{r["stat"].total} points of karma")
        end
      else
        rank = ranks[0]
        user = rank["user"]

        stat = rank["stat"]
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
        sendchn("#{user.user} is #{rank}#{suffix} with #{stat.total} points of karma")
      end
    else
      sendchn("#{who} has never had karma added or subtracted.")
    end
  end

#### QUOTES ####

  # Adds a quote
  def addquote(recorder, quotee, quote)
    recorder = getuser(recorder)
    quotee = getuser(quotee)
    bot_specific_quote_id = @bot.quotes.count + 1
    quote_obj = @bot.quotes.new(recorder_id: recorder.id, quotee_id: quotee.id, quote: quote, bot_specific_quote_id: bot_specific_quote_id)
    quote_obj.save
    sendchn("Quote for #{quotee.user} added with id: #{quote_obj.bot_specific_quote_id}")
  end

  # Sends a random quote for a specific user to the channel
  def echo_quote_by_user(who)
    if @bot.quotes.count.zero?
      sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.")
      return
    end
    quotee = getuser(who)
    if @bot.quotes.where(quotee_id: quotee.id).present?
      quote = @bot.quotes.where(quotee_id: quotee.id).first(:offset => rand(@bot.quotes.where(quotee_id: quotee.id).count))
      sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.bot_specific_quote_id}")
    else
      sendchn("#{quotee.user} has never been quoted")
    end
  end

  # Sends a random quote to the channel
  def echo_random_quote(chan)
    sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.") and return if @bot.quotes.all.empty?
    quote_ar = Array.new
    @bot.quotes.all.each { |q| quote_ar << q.id }
    id = quote_ar[rdnum(@bot.quotes.count) - 1]
    quote = @bot.quotes.find(id.to_i)
    quotee = @bot.users.find(quote.quotee_id)
    sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.bot_specific_quote_id}")
  end

  # Sends a quote of a specific id to the channel
  def echo_quote_by_id(id)
    sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.") and return if @bot.quotes.all.empty?
    if @bot.quotes.where(bot_specific_quote_id: id).present?
      quote = @bot.quotes.find_by_bot_specific_quote_id(id)
      quotee = getuser_by_id(quote.quotee_id)
      sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.bot_specific_quote_id}")
    else
       sendchn("No quote with id: #{id} exists.")
    end
  end

#### DEFINTIONS ####

  # Definitions can be accessed with the echo_definition method
  def add_definition(word, definition, recorder)
    recorder = getuser(recorder)
    word = word.downcase
    definition = @bot.definitions.create(recorder_id: recorder.id, word: word, definition: definition)
    definition.save
    sendchn("Ok, I'll remember #{word}")
  end

  # Forget the latest definition for a specific word
  def forget_definition(word)
    word = word.downcase
    definition = @bot.definitions.where(word: word).order('id ASC')
    if definition.present?
      definition.last.destroy
      sendchn("Deleted #{word}'s latest definition.")
    else
      sendchn("How can I forget what I do not know?")
    end
  end

  # Sends the definition added with add_definition
  def echo_definition_by_word(word)
    word = word.downcase
    if not @bot.definitions.where(word: word).blank?
      if @bot.bot_config(true).echo_all_definitions == true
        @bot.definitions.where(word: word).each do |d|
          sendchn("#{d.word} is #{d.definition}")
        end
      else
        d = @bot.definitions.where(word: word).sample
        sendchn("#{d.word} is #{d.definition}")
      end
    end
  end

  # Send a definition to the channel by its id
  def echo_definition_by_id(id)
    @bot.definitions.where(id: id).each do |d|
        sendchn("#{d.word} is #{d.definition}")
    end
  end

  # Send definitions made by a specific user to the channel
  def echo_definition_by_user(who)
    @bot.definitions.where(recorder: who).each do |d|
        sendchn("#{d.word} is #{d.definition}")
    end
  end

#### WEB_PARSING ####

  # This should go out to 'url' and just run a get request, returning the response.
  # parameters:
  #   :url (string, required), :username (string), :password (string), :headers (hash)
  def get_request(args)
    if args[:url].nil?
      return false
    else
      url = args[:url]
    end
    encoded_url = URI.encode(url)
    uri = URI.parse(encoded_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    if !args[:username].nil? && !args[:password].nil?
      request.basic_auth(args[:username], args[:password])
    end
    request.initialize_http_header(args[:headers]) unless args[:headers].nil?
    response = http.request(request)
    response
  end

  # This go through a plate and pulls only the unassigned cases.
  def check_ncq(plate_name, user_to_ping = nil)
    Rails.logger.debug "DIAG: plate parameter passed: #{plate_name}"
    plate = Array.new

    if CONFIG[:ncq_plates].include? plate_name
      # Create plate from actual plate
      all_plate_cases = unified_cmd("show plate #{plate_name}")["cases"]
      all_plate_cases.each do |ca|
        plate << ca if ca["internal_status"] == "Unassigned"
      end 
    else
      # Create plate from a product
      unassigned_cases = unified_cmd("show unassigned rhel")["cases"]
      unassigned_cases.each do |ca|
        next if ca["product"].nil?
        plate << ca if ca["product"].downcase.include? plate_name.downcase
      end
    end

    Rails.logger.debug "DIAG: plate case count: #{plate.count}"

    # Ping the user if provided as a parameter
    # otherwise, ping using the ping term    
    if user_to_ping
      ping = user_to_ping
    else
      ping = @bot.bot_config(true).ncq_watch_ping_term
    end

    ncq_cases = []
    ncq_case_nums = []
    plate.each do |ca|
      # Check if a mentioned case should be mentioned again
      if @mentioned_cases.include?(ca["casenumber"])
        old_time = @timers[:mentioned_cases][ca["casenumber"]]
        seconds_past = Time.now - old_time
        if seconds_past > @bot.bot_config.ncq_watcher_mentioned_case_clear_seconds
          @mentioned_cases.delete(ca["casenumber"])
        end
      end
      Rails.logger.debug "DIAG: Checking case #{ca["casenumber"]}"
      if not @mentioned_cases.include?(ca["casenumber"])
        Rails.logger.debug "DIAG: Reporting case #{ca["casenumber"]}"
        ncq_cases << ca
        ncq_case_nums << ca["casenumber"]
      end
    end
 
    # Track cases mentioned only if auto-checked
    if ncq_watcher?
      ncq_case_nums.each do |canum| 
        @mentioned_cases << canum
        @timers[:mentioned_cases][canum] = Time.now
      end
    end

    if ncq_watch_details?
      ncq_cases.each do |ca|
        number = ca["casenumber"]
        subject = ca["subject"]
        strategic = ca["strategic"]
        sbt = ca["sbt"]
        account_name = ca["account_name"]
        product = ca["short_product"]
        sbr = ca["sbr_group"]
        if ca["strategic"] == "false"
          sendchn("#{sbt} | #{sbr} | #{number} #{account_name} | #{product} | #{subject}")
        else
          sendchn("#{sbt} | #{sbr} | #{number} STRAT #{account_name} | #{product} | #{subject}")
        end
        Rails.logger.debug "DIAG: Reported detailed case #{number}"
      end
    else
      sendchn("#{ping}, new cases: " + ncq_case_nums.join(", ")) unless ncq_case_nums.empty?
      Rails.logger.debug "DIAG: Reported case numbers #{ncq_case_nums.join(",")}"
    end
    Rails.logger.debug "DIAG: NCQ case nums: #{ncq_case_nums.inspect}"
  end

  # This will go out to unified and get a plate in JSON form
  # returns Hash of parsed JSON
  def unified_cmd(command)
    url = "https://unified.gsslab.rdu2.redhat.com/ajax/"

    # Encode the url
    encoded_url = URI.encode(url)
    uri = URI.parse(encoded_url)
    uri.scheme = 'https'

    # Set query parameters
    params = { :sso_username => CONFIG[:rhn_username], :command => command, :command_type => "EXTERNAL" }
    uri.query = URI.encode_www_form(params)    

    # create http connection
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    #Generate request
    request = Net::HTTP::Get.new(uri.request_uri)
    request.add_field('Content-Type', 'application/x-www-form-urlencoded')
    response = http.request(request)
    
    Rails.logger.debug "DIAG: Response: #{response.inspect}"
    Rails.logger.debug "DIAG: Response code: #{response.code}"
    Rails.logger.debug "DIAG: Response message: #{response.code}"

    # Parse response
    JSON.parse(response.body)
  end

  # This will grab the title and possibly description of a bugzilla link and display it
  # https://bugzilla.redhat.com/docs/en/html/api/
  def bugzilla(url)
    number = url[/([0-9]{6,8})/, 1]
    response = get_request(:url => 'https://bugzilla.redhat.com/jsonrpc.cgi?method=Bug.get&params=[{"ids":'+number+'}]', :username => CONFIG[:bugzilla_username], :password => CONFIG[:bugzilla_password])
    body = JSON.parse(response.body)
    title = body["result"]["bugs"][0]["summary"]
    status = body["result"]["bugs"][0]["status"]
    product = body["result"]["bugs"][0]["product"]
    sendchn("Bugzilla: ##{number} \"#{title}\" : #{status} : #{product}")
  end

  # This will grab the title of a youtube link and display it
  # https://developers.google.com/youtube/
  def youtube(url)
    video_id = url[/youtube.com\/watch\?v=([a-zA-Z0-9\-\_]+)/, 1]
    google_api_key = CONFIG[:google_api_key]
    response = get_request(:url => "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&key=#{google_api_key}&part=snippet,contentDetails,statistics")
    body = JSON.parse(response.body)
    title = body["items"][0]["snippet"]["title"]
    duration = body["items"][0]["contentDetails"]["duration"]
    views = body["items"][0]["statistics"]["viewCount"]
    minutes = duration[/PT([0-9]+)M([0-9]+)S/, 1]
    seconds = duration[/PT([0-9]+)M([0-9]+)S/, 2]
    duration = "#{minutes}:#{seconds}"
    sendchn("Youtube: \"#{title}\" | #{duration} | #{views} views")
  end

  # This will grab the title of an imgur link and display it
  # https://api.imgur.com/
  def imgur(url)
    image_id = url.split("/").last
    imgur_client_id = CONFIG[:imgur_client_id]
    response = get_request(:url => "https://api.imgur.com/3/image/#{image_id}", :headers => {"Authorization" => "Client-ID "+imgur_client_id})
    body = JSON.parse(response.body)
    Rails.logger.debug "IMGUR RESPONSE: #{response.body.to_s}"
    title = body["data"]["title"]
    views = body["data"]["views"].to_s
    size = body["data"]["width"].to_s + "x" + body["data"]["height"].to_s
    string = "Imgur:"
    string = string+" \"#{title}\" |" unless title.nil?
    string = string + " #{size} | #{views} views"
    string = string + " | NSFW" unless body["data"]["nsfw"] == false
    sendchn(string)
  end

end
