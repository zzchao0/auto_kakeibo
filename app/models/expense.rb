class Expense < ApplicationRecord
  validates :used_on, :merchant_name, :amount, presence: true
  validates :amount, numericality: { greater_than: 0, only_integer: true }
end
