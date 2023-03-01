class AddFileToUnits < ActiveRecord::Migration[7.0]
  def change
    add_column :units, :file, :binary
  end
end
