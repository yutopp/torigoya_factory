class CreateWebhooks < ActiveRecord::Migration
  def change
    create_table :webhooks do |t|
      t.string  :target
      t.string  :secret
      t.string  :script
      t.timestamps
    end
  end
end
