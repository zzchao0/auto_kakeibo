require "test_helper"

class SonyBankWalletParserTest < ActiveSupport::TestCase
  test "success" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    result = SonyBankWalletParser.parse(mail_text)

    assert result.success?
    assert_equal(Date.new(2026, 9, 20), result.used_on)
    assert_equal(1700, result.amount)
    assert_equal("ＡＭＡＺＯＮ　ＣＯ　ＪＰ", result.merchant_name)
    assert_nil result.error_msg
  end

  test "without used_on" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.lines.reject { |line| line.start_with?("カード利用日：") }.join
    result = SonyBankWalletParser.parse(mail_text)

    refute result.success?
    assert_nil result.used_on
    assert_nil result.amount
    assert_nil result.merchant_name
    assert_equal("カード利用日が抽出できませんでした", result.error_msg)
  end

  test "without amount" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.lines.reject { |line| line.start_with?("ご利用金額：") }.join
    result = SonyBankWalletParser.parse(mail_text)

    refute result.success?
    assert_nil result.used_on
    assert_nil result.amount
    assert_nil result.merchant_name
    assert_equal("金額が抽出できませんでした", result.error_msg)
  end

  test "without merchant_name" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.lines.reject { |line| line.start_with?("ご利用加盟店：") }.join
    result = SonyBankWalletParser.parse(mail_text)

    refute result.success?
    assert_nil result.used_on
    assert_nil result.amount
    assert_nil result.merchant_name
    assert_equal("利用先が抽出できませんでした", result.error_msg)
  end

  test "amount is negative" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.sub("ご利用金額：1,700円", "ご利用金額：-1,700円")
    result = SonyBankWalletParser.parse(mail_text)

    refute result.success?
    assert_nil result.used_on
    assert_nil result.amount
    assert_nil result.merchant_name
    assert_equal("金額が0以下でした", result.error_msg)
  end

  test "used_on is invalid" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.sub("カード利用日：2026年9月20日", "カード利用日：2026年2月30日")
    result = SonyBankWalletParser.parse(mail_text)

    refute result.success?
    assert_nil result.used_on
    assert_nil result.amount
    assert_nil result.merchant_name
    assert_equal("カード利用日が不正でした", result.error_msg)
  end
end
