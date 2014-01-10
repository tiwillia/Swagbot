class AddQuitMessageToBotConfig < ActiveRecord::Migration
  def change
    add_column :bot_configs, :quit_message, :string, :default => "Leaving..."
  end
end
