class DropKarmaTable < ActiveRecord::Migration
  def up
    drop_table :karma
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
