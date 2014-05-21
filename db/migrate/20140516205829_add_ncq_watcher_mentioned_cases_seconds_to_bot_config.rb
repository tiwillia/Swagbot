class AddNcqWatcherMentionedCasesSecondsToBotConfig < ActiveRecord::Migration

  def change
    add_column :bot_configs, :ncq_watcher_mentioned_case_clear_seconds, :integer, :default => 1800
  end

end
