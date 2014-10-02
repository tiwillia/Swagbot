class CreateNcqRules < ActiveRecord::Migration
  def change
    NcqRule.connection.schema_cache.clear!
    NcqRule.reset_column_information
    create_table :ncq_rules do |t|
      t.boolean :use_default_ping_term, :default => true
      t.string :ping_term
      t.string :search_type
      t.string :match_string
      t.integer :bot_id
    end
  end
end
