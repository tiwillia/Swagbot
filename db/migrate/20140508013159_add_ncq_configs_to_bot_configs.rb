class AddNcqConfigsToBotConfigs < ActiveRecord::Migration

  def change
    add_column :bot_configs, :ncq_watcher, :boolean, :default => false
    add_column :bot_configs, :ncq_watch_interval, :integer, :default => 300
    add_column :bot_configs, :ncq_watch_plates, :text
    add_column :bot_configs, :ncq_watch_ping_term, :string, :default => "all"
    add_column :bot_configs, :ncq_watch_details, :boolean, :default => false
  end

end
