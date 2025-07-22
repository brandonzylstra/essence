class AddAwardsTable < ActiveRecord::Migration[8.0]
  def up
    create_table :awards do |t|
    add_index :awards, :tournament_event_id, name: 'INDEX_AWARDS_ON_TOURNAMENT_EVENT_ID'
    execute <<~SQL
      CREATE INDEX `index_awards_on_recipient` ON `awards` (`recipient_id`, `recipient_type`);
    SQL
    add_index :awards, :award_type, name: 'INDEX_AWARDS_ON_AWARD_TYPE'
    add_index :awards, :position, name: 'INDEX_AWARDS_ON_POSITION'
    create_table :awards do |t|
    add_index :awards, :tournament_event_id, name: 'INDEX_AWARDS_ON_TOURNAMENT_EVENT_ID'
    execute <<~SQL
      CREATE INDEX `index_awards_on_recipient` ON `awards` (`recipient_id`, `recipient_type`);
    SQL
    add_index :awards, :award_type, name: 'INDEX_AWARDS_ON_AWARD_TYPE'
    add_index :awards, :position, name: 'INDEX_AWARDS_ON_POSITION'
  end

  def down
    # Atlas handles rollbacks via schema state comparison
    # To rollback, revert your schema.hcl file and run atlas_rails_bridge again
    raise ActiveRecord::IrreversibleMigration
  end
end
