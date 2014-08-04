class CreateNodeApiAddresses < ActiveRecord::Migration
  def change
    create_table :node_api_addresses do |t|
      t.string  :address
    end
  end
end
