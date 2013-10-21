class BotsController < ApplicationController

# Simple index
# This should list all bots and
def index
  @bot = Bot.all
  redirect_to(:action => "new") and return if @bot.empty?
  if @bot.many?
    @bot.destroy_all
    redirect_to(:action => "new")
  end
  @bot = Bot.first
  if !defined?(@@queue)
    p "Not Defined "
    create(@bot.id)
  end
end

# Create a new bot
def create(*p)
  if p.empty?
    @bot = Bot.new(bot_params)
    @bot.save
  else
    @bot = Bot.find(p[0])
  end
  @@queue = Queue.new
  @@queue << "start"
  puts "Loading new bot"
#  bot_thread = Thread.new {
    bot = Swagbot.new("irc.devel.redhat.com", 6667, @bot.nick, @bot.channel)
    puts bot.inspect.split
    loop {
    popit = @@queue.pop(true) rescue nil
    if popit
      case popit
      when "start"
        bot.connect()
        sleep(2)
      when "stop"
        bot.kill()
#        Thread.exit
      end
    else
      bot.loop()
    end
    }
#   }
  sleep(2)
  redirect_to bots_path
end

def stop
  @queue << "stop"
  redirect_to bots_path
end

def edit
end

def delete
  stop
  @bot = Bot.all
  @bot.destroy_all
  redirect_to(:action => "new")
end

def new
  @bot = Bot.new
end

private
def bot_params
  params.require(:bot).permit(:nick, :channel, :irc_file)
end

end
