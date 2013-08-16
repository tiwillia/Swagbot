class CreateUsers < ActiveRecord::Migration
  def up
    create_table :users do |t|
      t.string :user

      t.timestamp
    end
  end
end
