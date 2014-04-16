class WelcomeController < ApplicationController
  def index
    User.all.each do |user|
  if user.user.nil? || user.user.downcase == user.user
    next
  end
  if User.where(:user => user.user.downcase)
    if KarmaStats.where(:user_id => user.id)
      Rails.logger.info "#{user.user} exists and conflicts"
    end
  end
end

  end
end
