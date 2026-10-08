class EmailImportsController < ApplicationController
  def new
  end

  def create
    @mail_text = params[:mail_text]
    result = SonyBankWalletParser.parse(@mail_text)
    if result.success?
      @expense = Expense.new(used_on: result.used_on, merchant_name: result.merchant_name, amount: result.amount, category: "", memo: "メール文取り込み")
      if @expense.save()
        redirect_to expenses_path
      else
        @error_msg = @expense.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      end
    else
      @error_msg = result.error_msg
      render :new, status: :unprocessable_entity
    end
  end
end
