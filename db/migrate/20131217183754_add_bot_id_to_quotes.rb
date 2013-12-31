class AddBotIdToQuotes < ActiveRecord::Migration
  def change
    add_column :quotes, :bot_id, :integer
  end
end
