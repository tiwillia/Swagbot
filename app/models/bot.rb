class Bot < ActiveRecord::Base
  # These associations are necessary, or all bots will use the same karama/quotes/etc tables
  has_one :bot_config
  has_many :karma_entries
  has_many :definitions
  has_many :quotes
  has_many :karmastats
  has_many :users

  # Not sure how many of these are necessary, but we will find out.
  require 'socket'
  require 'open-uri'
  require 'json/ext'
  require 'nokogiri'
  
  after_initialize :set_instance_vars

  def set_instance_vars
    @timers = Hash.new
    @userposting = "nil"
    @host = self.server
    @port = self.port
    @nick = self.nick
    @chan = self.channel
    @server_password = self.server_password
    @nickserv_password = self.nickserv_password
    @bot = self 
  end

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
    send_server "JOIN #{@chan}"
  end

  def kill
    @socket.send(":source QUIT :SWAG\n", 0)
    @socket.close
  end

  # This should return the karmastat and user objects
  # of the top 5 karma recipients or a single recipient
  def get_rank(*who)
    
    rank_array = Array.new

    # Calculate rank
    counter = 1
    @bot.karmastats.where('total is distinct from ?', '0').order('total DESC').each do |x|
      x.rank = counter
      x.save
      counter += 1
    end

    # If we are getting all ranks, not just a single user
    if who.empty?
      @bot.karmastats.where('total is distinct from ?', '0').order('rank ASC').limit(5).each do |stat|
        user = @bot.users.find(stat.user_id)
        rank_hash = Hash[ "user" => user, "stat" => stat ]
        rank_array << rank_hash
      end
    else
      user = getuser(who)

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
    line = @socket.gets
    line = line.strip
    puts line 

    # Grab the nick of the @userposting
    @userposting = line[/^:([\|\.\-0-9a-zA-Z]*)!/, 1]
    if line.match(/^:.*\ PRIVMSG\ #{@nick}\ \:.*/)
      @chan = @userposting
    else
      @chan = line[/\ (#[\|\.\-0-9a-zA-Z]*)\ :/, 1]
    end
    
    # Ignore unifiedbot
    if @userposting.eql?("unifiedbot")
      return
    end

    # Add the user to the users table if they do not exist
    if not @userposting.blank?
      if @bot.users.where(user: @userposting).blank?
        new_user = @bot.users.create(user: @userposting)
        new_user.save
      end 
    end

    if line.match(/.*\:#{@nick}[\,\:\ ]+.*/) then
      params = line[/.*\:#{@nick}[\,\:\ ]+(.*)/, 1]
      case
      when params.match(/^join\ \#[\-\_\.\'0-9a-zA-Z]+/)
        channel_to_join = params[/^join\ (\#[\-\_\.\'0-9a-zA-Z]+)/, 1]
        join_chan(channel_to_join)
      when params.match(/^leave/)
        if @chan == @userposting
          sendchn("Say it in the channel you want me to leave.")
        else
            leave_chan(@chan)
        end
      when params.match(/^[\-\_\.\'\.0-9a-zA-Z]*\ is\ .*/)
        word_to_define = params[/([\-\_\.\'0-9a-zA-Z]*)\ is/, 1]
        definition = params[/[\-\_\ \.\'0-9a-zA-Z]*\ is\ (.*)/, 1]
        add_definition(word_to_define, definition, @userposting)
      when params.match(/^[\-\_\.0-9a-zA-Z]*\?/)
        if not @bot.definitions.count.zero?
          word_to_echo_def = params[/([\-\_\.0-9a-zA-Z]*)?/, 1]
          echo_definition_by_word(word_to_echo_def)
        end
      when params.match(/^forget\ [\-\_\ 0-9a-zA-Z]*/)
        word_to_forget = params[/forget\ ([\-\_\ 0-9a-zA-Z]*)/, 1]
        forget_definition(word_to_forget)
      when params.match(/^addquote.*/)
        user_to_quote = line[/addquote\ ([0-9a-zA-Z\-\_\.\|]+)\ .*/, 1]
        new_quote = line[/addquote\ [0-9a-zA-Z\-\_\.\|]+\ (.*)/, 1]
        addquote(@userposting, user_to_quote, new_quote)  
      when params.match(/^quote.*/)
        if params.match(/quote\ [0-9]+$/)
          echo_quote_by_id(params[/quote\ (.*)/, 1])
        elsif params.match(/quote\ [a-zA-Z0-9\.\_\-\|]+/)
          echo_quote_by_user(params[/quote\ (.*)/, 1])
        else
          echo_random_quote(@chan) 
        end
      when params.match(/^rank.*/)
        if params.eql?("rank")
          rank
        elsif params.match("rank\ [a-zA-Z0-9\.\-\_\|]+")
          user_to_rank = params[/rank\ (.*)/, 1]
          rank(user_to_rank)
        end
      when params.eql?("time")
        time = Time.new
        timenow = time.inspect
        sendchn("The current time is #{timenow}")
      when params.eql?("weather")
        # Yahoo Weather Variables
        yahoo_url = 'http://query.yahooapis.com/v1/public/yql?format=json&q='
        query = "SELECT * FROM weather.forecast WHERE location = 27606"
        url = URI.encode(yahoo_url + query)
        # Pull and parse data
        weather_data = JSON.parse(open(url).read)
        weather_results = weather_data["query"]["results"]["channel"]
        sendchn("------------------Weather For 27606---------------")
        sendchn("Current conditions: #{weather_results["wind"]["chill"]} degrees and #{weather_results["item"]["forecast"][0]["text"]}")
        sendchn("Windspeed: #{weather_results["wind"]["speed"]}mph")
        sendchn("High: #{weather_results["item"]["forecast"][0]["high"]} degrees")
        sendchn("Low: #{weather_results["item"]["forecast"][0]["low"]} degrees")
        sendchn("-----------------------------------------------------------")
        
        when params.match(/^help.*/)
          case 
          when  params.eql?("help")
            sendchn("#{@nick}: help [command]")
            sendchn("#{@nick}: <noun> is <definition>")
            sendchn("#{@nick}: <noun>?")
            sendchn("#{@nick}: addquote <name> <quote WITHOUT \"\">")
            sendchn("#{@nick}: quote [name]")
            sendchn("<name>++")
            sendchn("<name>--")
            sendchn("#{@nick} rank")
            sendchn("#{@nick} rank <name>")
            sendchn("#{@nick}: time")
            sendchn("#{@nick}: weather")
            sendchn("#{@nick}: leave")
            sendchn("#{@nick}: join <#channel>")                                        
          when params.eql?("help addquote")
            sendchn("Usage: #{@nick}: addquote <name> <quote WITHOUT \"\">")
            sendchn("Adds a quote to the quote database")
            sendchn("Quotes can be recalled with #{@nick}: quote [name]")                                    when params.eql?("help quote")
            sendchn("Usage: #{@nick}: quote [name]")
            sendchn("Returns a quote from the quote database")
            sendchn("If no name is supplied, a random quote will be returned")                               when params.eql?("help time")
            sendchn("I don't know why you want help with this one #{@userposting}...")
            sendchn("It was more of a way to test getting the time")
            sendchn("Eventually, the time will be used for other commands")                                  when params.eql?("help weather")
            sendchn("PLACEHOLDER")                               
          end
        end
      else
        puts line
        case
        # This one is super important
        # It makes sure swagbot doesn't get disconnected
        when line.match(/^PING :(.*)$/)
          send_server "PONG #{$~[1]}"

        # Accept invites to channels
        when line.match(/\ INVITE #{@nick}\ \:\#.*/)
          invited_channel = line[/#{@nick}\ \:(\#.*)/, 1]
          join_chan(invited_channel)
          sendchn("I was invited here by #{@userposting}. If I am not welcome type \"#{@nick} leave\"")
        
        # Karma assignments
        when line.match(/^.*[\_\-\.\'\.\|0-9a-zA-Z]+[\+\-]{2}.*/)
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
        when line.match(/.*\:[\_\-\.\'\.\|0-9a-zA-Z]+\?$/)
          word_to_echo_def = line[/([\-\_\.0-9a-zA-Z]*)\?/, 1]
          echo_definition_by_word(word_to_echo_def)

        when line.match(/.*#{@nick}\ \:\!op$/)
            send("MODE #{@chan} +o #{@userposting}")        
        
        when line.match(/.*http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+[\ ]*/)
          url = line[/.*(http[s]*:\/\/[w\.]*bugzilla\.redhat\.com\/show_bug.cgi\?id=[a-zA-Z0-9]+)[\ ]*/, 1]
          bugzilla(url)

        when line.match(/.*http[s]*:\/\/[w\.]*youtube.com\/watch.*/)
          url = line[/.*(http[s]*:\/\/[w\.]*youtube.com\/watch\?v=[a-zA-Z0-9\-\_]+)[\ ]*/, 1]
          youtube(url)
        
        when line.match(/.*http[s]*:\/\/[i\.]*imgur.com\/gallery\/.*/)
          url = line[/.*(http[s]*:\/\/[i\.]*imgur.com\/gallery\/[a-zA-Z0-9\-\_]+).*/, 1]
          imgur(url)

        when line.match(/.*http[s]*:\/\/[i\.]*imgur.com\/.*/)
          url = line[/.*(http[s]*:\/\/[i\.]*imgur.com\/[a-zA-Z0-9\-\_]+).*/, 1]
          imgur(url)
        when line.match(/.*\!http\ [1-5]{1}[0-9]{2}/)
          url = line[/.*\!http\ ([1-5]{1}[0-9]{2})/, 1]
          sendchn("http://httpstatusdogs.com/" + url)
        end
    end
    return nil
  end

private
 
#### UTILITIES ####
 
  # Small function to easily send messages to @chan
  def sendchn(msg)
    @socket.send ":source PRIVMSG #{@chan} :#{msg}\n" , 0
  end

  def send_server(msg)
    @socket.send "#{msg}\n", 0
  end

  def join_chan(chan)
    send_server ":source JOIN #{chan}"
  end
  
  def leave_chan(chan)
    send_server ":source PART #{chan}"
  end

  def rdnum(seq)
    today = DateTime.now
    seed = today.strftime(format='%3N').to_i
    prng = Random.new(seed)
    prng.rand(1..seq)
  end

  def getuser(user)
    if @bot.users.where(:user => user).present?
      @bot.users.find_by_user(user)
    else
      new_user = @bot.users.new(user: user)
      new_user.save
      new_user
    end
  end

  def getuser_by_id(id)
    if @bot.users.where(:id => id).present?
      @bot.users.find(id)
    else
      nil
    end
  end

#### KARMA ####

  def editkarma(giver, receiver, type)
    #Here we need to parse the db for name, get the number, add one to the number
    #Syntax of the db will be user:number\n
    recipient = getuser(receiver)
    grantor = @bot.users.find_by_user(giver)

    # Add timer
    # check for the timer before we set the timer, obviously.
    time = @timers.fetch(receiver, nil)
    if time.to_i != 0
      if time.to_i > (Time.now.to_i - @bot.bot_config(true).karma_timeout)
        send(":source PRIVMSG #{@userposting} :You must wait #{time.to_i - (Time.new.to_i - @bot.bot_config(true).karma_timeout)} more seconds before changing #{receiver}'s karma.\n")
        return
      elsif time.to_i < (Time.now.to_i - @bot.bot_config(true).karma_timeout)
        @timers = { receiver => Time.new.to_i }
      end
    else
      @timers = { receiver => Time.new.to_i }
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

    sendchn("#{receiver} now has #{stat.total} karma.")
  end

  def rank(*who)
    if who.empty? 
      ranks = get_rank
    else
      who = who[0]
      ranks = get_rank(who)
    end
 
    if ranks
      if ranks.count == 5
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
    quote_obj = @bot.quotes.new(recorder_id: recorder.id, quotee_id: quotee.id, quote: quote)
    quote_obj.save
    sendchn("Quote for #{quotee.user} added with id: #{quote_obj.id}")
  end

  # Reads a quote
  def echo_quote_by_user(who)
    if @bot.quotes.count.zero?
      sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.")
      return
    end
    quotee = getuser(who)
    if @bot.quotes.where(quotee_id: quotee.id).present?
      quote = @bot.quotes.where(quotee_id: quotee.id).first(:offset => rand(Quotes.where(quotee_id: quotee.id).count))
      sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}")
    else
      sendchn("#{quotee.user} has never been quoted")
    end
  end

  def echo_random_quote(chan)
    sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.") and return if @bot.quotes.all.empty?
    quote_ar = Array.new
    @bot.quotes.all.each { |q| quote_ar << q.id }
    id = quote_ar[rdnum(@bot.quotes.count) - 1]
    quote = @bot.quotes.find(id.to_i)
    quotee = @bot.users.find(quote.quotee_id)
    sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}")
  end

  def echo_quote_by_id(id)
    sendchn("No quotes have ever been added, use \"#{@nick}, addquote user quote\" to add one.") and return if @bot.quotes.all.empty?
    if @bot.quotes.where(id: id).present?
      quote = @bot.quotes.find(id)
      quotee = getuser_by_id(quote.quotee_id)
      sendchn("\"#{quote.quote}\" - #{quotee.user} \| id:#{quote.id}")
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

  def echo_definition_by_id(id)
    @bot.definitions.where(id: id).each do |d|
        sendchn("#{d.word} is #{d.definition}")
    end
  end

  def echo_definition_by_user(who)
    @bot.definitions.where(recorder: who).each do |d|
        sendchn("#{d.word} is #{d.definition}")
    end
  end

#### WEB_PARSING ####

  # This will grab the title and possibly description of a bugzilla link and display it
  def bugzilla(url)
    doc = Nokogiri::HTML(open(url))
    number = url.split("=").last
    title = doc.xpath('//span[@id="short_desc_nonedit_display"]/text()')
    status = doc.xpath('//span[@id="static_bug_status"]/text()')
    sendchn("Bugzilla: ##{number} \"#{title}\" : #{status}")
  end

  # This will grab the title of a youtube link and display it
  def youtube(url)
    doc = Nokogiri::HTML(open(url))
    title = doc.xpath('//span[@id="eow-title"]/@title')
    views = doc.css('span.watch-view-count').first.content.strip
    sendchn("Youtube: \"#{title}\" : #{views} views")
  end

  # This will grab the title of an imgur link and display it
  def imgur(url)
    doc = Nokogiri::HTML(open(url)) rescue nil
    img_id = url.split("/").last
    title = doc.xpath('//h2[@id="image-title"]/text()')
    time = doc.xpath('//span[@id="nicetime"]/text()')
    if time.empty?
      time = doc.xpath('//div[@id="stats-submit-date"]/text()')
      time = time.text.strip.gsub(/\ (\ +)/,"").gsub("\n", " ")
    else
      time = "Submitted #{time}"
    end
    sendchn("Imgur: \"#{title}\" #{time}")
  end

end
