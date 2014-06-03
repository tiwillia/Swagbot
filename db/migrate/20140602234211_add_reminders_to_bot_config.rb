class AddRemindersToBotConfig < ActiveRecord::Migration

  def change
    add_column :bot_configs, :reminders, :boolean, :default => true
  end

end
