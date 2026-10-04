require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  test "expense is valid with required attributes" do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      merchant_name: "test",
      amount: 1
    )

    assert expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "without used_on" do
    expense = Expense.new(
      merchant_name: "without used_on",
      amount: 1
    )

    refute expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "without merchant_name" do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      amount: 1
    )
    refute expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "without amount" do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      merchant_name: "without amount"
    )
    refute expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "amount is 0" do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      merchant_name: "amount is 0",
      amount: 0
    )
    refute expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "amount is minus" do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      merchant_name: "amount is minus",
      amount: -1
    )
    refute expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "amount is decimal"  do
    expense = Expense.new(
      used_on: Date.new(2026, 10, 3),
      merchant_name: "amount is decimal",
      amount: 1.5
    )
    refute expense.valid?, expense.errors.full_messages.join(", ")
  end
end
