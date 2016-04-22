class CreateStreams < ActiveRecord::Migration
  def change
    create_table :streams do |t|
      t.timestamps
      t.integer :user_id
      t.float :lat
      t.float :lng
      t.boolean :active, default: true
    end
  end
end
