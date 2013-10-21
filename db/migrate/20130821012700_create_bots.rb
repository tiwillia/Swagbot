class CreateBots < ActiveRecord::Migration
  def change
    create_table :bots do |t|
      t.string :nick
      t.string :channel
      t.string :irc_file

      t.timestamps
    end
  end
end
