require 'socket'
require 'open-uri'
require 'json/ext'
require 'rubygems'
require 'active_record'
require 'yaml'
require 'pg'

Dir.glob("/var/lib/openshift/5252cda4f44518d75e000033/app-root/repo/app/models/*.rb").each{|f| require f}
dbconfig = YAML::load(File.open("database_force.yml"))
ActiveRecord::Base.establish_connection(dbconfig)

File.foreach("karmadb") {|line| 
  user = line[/^([a-zA-Z0-9\-\_\.\'\"\,\>\<\?\/\`\~\|\(\)\*\&\^\%\$\#\@\!]+):.*/, 1]
  karma_amt = line[/.*\:([\-0-9]+)/, 1]
  if Users.find_by_user(user).blank?
    user_obj = Users.new(user: user)
    user_obj.save
  else
    user_obj = Users.find_by_user(user)
  end
  user_id = user_obj.id
  p "Added #{user} with #{karma_amt} karma and id: #{user_id}"
  new_karma = Karma.new(recipient_id: user_id, amount: karma_amt, grantor_id: "auto")
  new_karma.save
  new_karma_stat = Karmastats.new(user_id: user_id, total: karma_amt)
  new_karma_stat.save
}

# Re-calculate all ranks 
counter = 1
Karmastats.where("total != 0").order('total DESC').each do |x|
  x.rank = counter
  x.save
  counter += 1
end

File.foreach("definitiondb") {|line|
  line = line.strip
  if !line.empty?
    word = line[/^([^:]+):.*/, 1]
    definition = line[/^[^:]+:(.*)/, 1]
    newdef = Definitions.new(word: word, definition: definition)
    newdef.save
    p "Added #{word} defined as #{definition}"
  end
}

File.foreach("quotedb") {|line|
  line = line.strip
  quote = line[/^\"([^"]+)\".*/, 1]
  quotee = line[/^\"[^"]+\"\ -\ (.*)/, 1]

  if Users.find_by_user(quotee).blank?
    user_obj = Users.new(user: quotee)
    user_obj.save
  else
    user_obj = Users.find_by_user(quotee)
  end

  if Users.find_by_user("auto").blank?
    auto_user = Users.new(user: "auto")
    auto_user.save
  else
    auto_user = Users.find_by_user("auto")
  end

  user_id = user_obj.id
  newquote = Quotes.new(quote: quote, quotee_id: user_id, recorder_id: auto_user.id)
  newquote.save
  p "Added quote for #{quotee}: #{quote}"
}
