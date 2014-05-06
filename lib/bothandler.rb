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
        stop_bot(bot)
        Rails.logger.info "BOTHANDLER: Stopped bot #{bot.nick}"
      rescue => e
        Rails.logger.error "BOTHANDLER: ERROR could not stop bot #{e.inspect}"
      end

    when "restart"
      Rails.logger.info "BOTHANDLER: Restarting bot #{bot.nick}"
      begin
        if @bot_states[bot.id] == "Running"
          stop_bot(bot)
        end
        start_bot(bot)
        Rails.logger.info "BOTHANDLER: Restarted bot #{bot.nick}"
      rescue => e
        Rails.logger.error "BOTHANDLER: ERROR could not restart bot #{e.inspect}"
      end
      

    end
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
  def stop_bot(bot)
    if @bot_states[bot.id] != "Stopped"
      @bot_queues[bot.id] << "stop"
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
            case bot.loop()
            when "reconnect"
              Rails.logger.info "BOTHANDLER: Got reconnect request from bot #{bot.nick}, restarting..."
              enqueue({:bot_id => bot.id, :action => "restart"})
            when "connection lost"
              Rails.logger.error "BOTHANDLER: Lost connection... waiting 30 seconds and retrying."
              sleep 30
              enqueue({:bot_id => bot.id, :action => "restart"})
            end
          rescue => exception
            Rails.logger.error "BOTHANDLER: ERROR: Bot #{bot.nick} with id #{bot.id} FAILed in loop with: "
            Rails.logger.error "BOTHANDLER: ERROR: " + exception.message
            Rails.logger.error "BOTHANDLER: ERROR: " + exception.backtrace
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

