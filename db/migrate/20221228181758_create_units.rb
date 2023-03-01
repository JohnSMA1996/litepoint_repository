class CreateUnits < ActiveRecord::Migration[7.0]
  def change
    create_table :units do |t|
      t.integer :serial_number
      t.string :description

      t.timestamps
    end
  end
end
