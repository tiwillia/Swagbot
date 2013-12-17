class Bot < ActiveRecord::Base
  # These associations are necessary, or all bots will use the same karama/quotes/etc tables
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

  def loop()
    line = @socket.gets
    line = line.strip
    puts line 
  end

private
  
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

  def send_server(msg)
    @socket.send "#{msg}\n", 0
  end

end
