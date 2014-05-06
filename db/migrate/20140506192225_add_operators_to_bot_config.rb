class AddOperatorsToBotConfig < ActiveRecord::Migration

  def change
    add_column :bot_configs, :operator_control, :boolean, :default => true
    add_column :bot_configs, :operator_any_user, :boolean, :default => true
    add_column :bot_configs, :operators, :text
  end

end
