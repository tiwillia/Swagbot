class BotHandler

# This is the handler that controls bots and their respective threads.
# 'start' creates a single thread that watches for work
#     work must be in the format {:bot_id => bot.id, :action => "start|stop|restart"}
# That thread then spins up individual threads as bots are created.
 
  def initialize
    @queue = Queue.new
    @bot_threads = Hash.new
    @bot_states = Hash.new
    @bot_queues = Hash.new 
    @bots = Hash.new
 
    Bot.all.each do |bot|
      @bots[bot.id] = bot
      @bot_queues[bot.id] = Queue.new
      @bot_states[bot.id] = "Stopped"
    end

    start

  end

  # Add work to the queue.
  # work should be a hash like: {:bot_id => bot.id, :action => "stop"}
  # action must be either "start", "stop", "restart"
  def enqueue(work)
    Rails.logger.info "BOTHANDLER: Adding work to queue: #{work.inspect}."
    @queue << work
    if not running?
      Rails.logger.info "BOTHANDLER: Starting bot handler thread..."
      start
    end
  end
 
  # Check if the head thread is running 
  def running?
    @thread && @thread.alive?
  end

  # return the state of a bot
  def state(bot_id)
    @bot_states[bot_id]
  end

private
  
  # This is the loop we run through constantly in the background to watch for work.
  def start
    if running?
      Rails.logger.error "BOTHANDLER: ERROR Tried to start running bot handler."
      return false
    end
    @thread = Thread.new do
      loop do
        while @queue.empty? do    
          sleep 3
        end
        work = @queue.pop
        do_work(work)
      end
    end
  end

  # Parse the work and begin the correct action
  def do_work(work)

    bot_id = work[:bot_id]

    # Add a new bot to the bot hash if one was not added when initialized
    # This should only happen if a new bot is created.
    if @bots[bot_id].nil?
      @bots[bot_id] = Bot.find(bot_id)
      @bot_queues[bot_id] = Queue.new
      @bot_states[bot_id] = "Stopped"
    end

    bot = @bots[bot_id]

    case work[:action]

    when "start"
      Rails.logger.info "BOTHANDLER: Starting bot #{bot.nick}"
      begin
        start_bot(bot)
        Rails.logger.info "BOTHANDLER: Started bot #{bot.nick}"
      rescue => e
        Rails.logger.error "BOTHANDLER: ERROR could not start bot #{e.inspect}"
        bot.kill
      end

    when "stop"
      Rails.logger.info "BOTHANDLER: Stopping bot #{bot.nick}"
      begin
        if work[:force]
          stop_bot(bot, true)
        else
          stop_bot(bot, false)
        end
        Rails.logger.info "BOTHANDLER: Stopped bot #{bot.nick}"
      rescue => e
        Rails.logger.error "BOTHANDLER: ERROR could not stop bot #{e.inspect}"
      end

    when "restart"
      Rails.logger.info "BOTHANDLER: Restarting bot #{bot.nick}"
      begin
        # If running, stop then start. Else just start.
        if @bot_states[bot.id] == "Running"
          if work[:force]
            stop_bot(bot, true)
          else
            stop_bot(bot, false)
          end
        end
        start_bot(bot)
        Rails.logger.info "BOTHANDLER: Restarted bot #{bot.nick}"
      rescue => e
        Rails.logger.error "BOTHANDLER: ERROR could not restart bot #{e.inspect}"
      end
      
    when "say"
      Rails.logger.info "BOTHANDLER: Saying message #{work[:message]}"
      say_message(bot, work[:message])

    end
  end

  def say_message(bot, message)
    bot.sendchn(message)
  end

  # Start a bot thread
  # bot should be an object, not an id
  def start_bot(bot) 
    if @bot_states[bot.id] != "Running"
      bot.connect
      sleep 2
      create_thread(bot)
      @bot_states[bot.id] = "Running"
    else
      raise "ERROR tried to start already running bot #{bot.nick}"
    end
  end

  # Stop a bot thread
  # bot should be an object, not an id
  def stop_bot(bot, force=false)
    if force
      Rails.logger.info "BOTHANDLER: Forcefully killing #{bot.nick} with id #{bot.id}."
      begin
        bot.force_stop
      rescue => e
        Rails.logger.error "BOTHANDLER: #{e.message}"
      end
      @bot_threads[bot.id].kill if @bot_threads[bot.id].alive?
      @bot_states[bot.id] = "Stopped"
      return
    end
    if @bot_states[bot.id] != "Stopped"
      @bot_queues[bot.id] << "stop"
      
      # Wait until the bot thread is killed
      # For this to happen, something must be said in one of the channels that
      #   the bot is in. The read operation from the socket is blocking.
      count = 0
      until !@bot_threads[bot.id].alive? do
        if count == 6
          Rails.logger.error "BOTHANDLER: ERROR thread for #{bot.nick} never stopped, forcefully killing it."
          @bot_threads[bot.id].kill
        end
        Rails.logger.info "BOTHANDLER: Waiting for #{bot.nick} to stop..."
        sleep 10
        count += 1
      end

      # Only close the socket after there is no longer a read operation pending from the socket.
      # Otherwise, a 'stream closed' exception is raised.
      bot.kill
      @bot_states[bot.id] = "Stopped"

    else
      raise "ERROR tried to stop already stopped bot #{bot.nick}"
    end
  end

  # Create the bot thread
  # bot should be an actual bot object, not an id
  def create_thread(bot)
    @bot_threads[bot.id] = Thread.new {
      loop {
        command = @bot_queues[bot.id].pop(true) rescue nil
        if command
          case command
          when "stop"
            Thread.kill
          end
        else
          begin
            
            # The bot loop will retrun 'reconnect' or 'connection lost' to indicate
            #  that it is unable to connect to the server
            # These are failovers that allow us to recover when the irc server goes down for some time.
            case bot.loop()
            when "reconnect"
              Rails.logger.info "BOTHANDLER: Got reconnect request from bot #{bot.nick}, restarting..."
              enqueue({:bot_id => bot.id, :action => "restart"})
            when "connection lost"
              Rails.logger.error "BOTHANDLER: Lost connection... waiting 30 seconds and retrying."
              sleep 30
              enqueue({:bot_id => bot.id, :action => "restart"})
            end

          # This should only occur if there is a bug in the bot code
          rescue => exception
            Rails.logger.error "BOTHANDLER: ERROR: Bot #{bot.nick} with id #{bot.id} FAILed in loop with: "
            Rails.logger.error "BOTHANDLER: ERROR: " + exception.message
            exception.backtrace.each do |line|
              Rails.logger.error "BOTHANDLER: ERROR: " + line
            end
 
            # kill, stop, reload, and start the bot. Reload is absolutely necessary or the bot will still
            #   be in a failed state.
            bot.kill
            @bot_states[bot.id] = "Stopped"
            @bots[bot.id] = Bot.find(bot.id)
            enqueue({:bot_id => bot.id, :action => "start"})
            Thread.kill

          end 
        end 
      }
    }
  end
  
end

