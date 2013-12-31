class AddBotIdToKarmastats < ActiveRecord::Migration
  def change
    add_column :karmastats, :bot_id, :integer
  end
end
