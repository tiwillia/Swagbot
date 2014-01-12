class AddSwitchesToBotConfig < ActiveRecord::Migration
  def change
    add_column :bot_configs, :quotes, :boolean, :default => true
    add_column :bot_configs, :definitions, :boolean, :default => true
    add_column :bot_configs, :karma, :boolean, :default => true
    add_column :bot_configs, :youtube, :boolean, :default => true
    add_column :bot_configs, :imgur, :boolean, :default => true
    add_column :bot_configs, :bugzilla, :boolean, :default => true
  end
end
