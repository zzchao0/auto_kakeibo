class SonyBankWalletParser
  def self.parse(mail_text)
    date_match = mail_text.match(/カード利用日：(?<year>\d+)年(?<month>\d+)月(?<day>\d+)日/)
    if date_match
      year = date_match[:year].to_i
      month = date_match[:month].to_i
      day = date_match[:day].to_i
      if Date.valid_date?(year, month, day)
        used_on = Date.new(year, month, day)
      else
        error_msg = "カード利用日が不正でした"
        return failed_result(error_msg)
      end
    else
      error_msg = "カード利用日が抽出できませんでした"
      return failed_result(error_msg)
    end

    amount_match = mail_text.match(/ご利用金額：(?<amount>-?\d{1,3}(,\d{3})+|-?\d+)円/)
    if amount_match
      amount = amount_match[:amount].delete(",").to_i
      if amount <= 0
        error_msg = "金額が0以下でした"
        return failed_result(error_msg)
      end
    else
      error_msg = "金額が抽出できませんでした"
      return failed_result(error_msg)
    end

    merchant_name_match = mail_text.match(/ご利用加盟店：(?<merchant_name>.+$)/)
    if merchant_name_match
      merchant_name = merchant_name_match[:merchant_name]
    else
      error_msg = "利用先が抽出できませんでした"
      return failed_result(error_msg)
    end

    Result.new(true, used_on, amount, merchant_name, nil)
  end

  def self.failed_result(error_msg)
    Result.new(false, nil, nil, nil, error_msg)
  end

  private_class_method :failed_result

  class Result
    attr_accessor :success, :used_on, :amount, :merchant_name, :error_msg

    def initialize(success, used_on, amount, merchant_name, error_msg)
      @success = success
      @used_on = used_on
      @amount = amount
      @merchant_name = merchant_name
      @error_msg = error_msg
    end

    def success?
      @success
    end
  end
end
