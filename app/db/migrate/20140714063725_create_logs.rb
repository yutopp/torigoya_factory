class CreateLogs < ActiveRecord::Migration
  def change
    create_table :logs do |t|
      t.string  :title
      t.text    :content
      t.integer :status
      t.timestamps
    end
  end
end
