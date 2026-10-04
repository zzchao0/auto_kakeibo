class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.date :used_on
      t.string :merchant_name
      t.integer :amount
      t.string :category
      t.text :memo

      t.timestamps
    end
  end
end
