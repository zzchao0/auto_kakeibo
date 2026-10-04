class ExpensesController < ApplicationController
  def index
    @expenses = Expense.order(used_on: :desc, created_at: :desc)
  end

  def new
    @expense = Expense.new(used_on: Date.current)
  end

  def create
    @expense = Expense.new(expense_params)
    if @expense.save
      redirect_to expenses_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @expense = Expense.find(params[:id])
  end

  def update
    @expense = Expense.find(params[:id])
    if @expense.update(expense_params)
      redirect_to expenses_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense = Expense.find(params[:id])
    @expense.destroy()
    redirect_to expenses_path, notice: "削除しました", status: :see_other
  end

  def show
    @expense = Expense.find(params[:id])
  end

  private
  def expense_params
    params.require(:expense).permit(:used_on, :merchant_name, :amount, :category, :memo)
  end
end
