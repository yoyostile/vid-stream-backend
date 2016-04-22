class AddPublicIdToStreams < ActiveRecord::Migration
  def change
    add_column :streams, :public_id, :string
  end
end
