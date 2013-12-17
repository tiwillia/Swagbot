class RemoveIrcFileFromBots < ActiveRecord::Migration
  def up
    remove_column :bots, :irc_file
  end

  def down
    add_column :bots, :irc_file, :string
  end
end
