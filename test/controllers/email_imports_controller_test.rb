require "test_helper"

class EmailImportsControllerTest < ActionDispatch::IntegrationTest
  test "success" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")

    assert_difference("Expense.count", 1) do
      post email_imports_path, params: { mail_text: mail_text }
    end

    assert_redirected_to expenses_path
    expense = Expense.last
    assert_equal(Date.new(2026, 9, 20), expense.used_on)
    assert_equal(1700, expense.amount)
    assert_equal("ＡＭＡＺＯＮ　ＣＯ　ＪＰ", expense.merchant_name)
  end

  test "parse failure" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.lines.reject { |line| line.start_with?("カード利用日：") }.join

    assert_no_difference("Expense.count") do
      post email_imports_path, params: { mail_text: mail_text }
    end

    assert_response :unprocessable_entity
    assert_select "li", text: "カード利用日が抽出できませんでした"
    assert_select "textarea[name='mail_text']", count: 1 do |elements|
      assert_equal mail_text, elements.first.text
    end
  end

  test "save failure" do
    mail_text = File.read("test/fixtures/SonyBankWALLETメール文サンプル")
    mail_text = mail_text.sub("ご利用加盟店：ＡＭＡＺＯＮ　ＣＯ　ＪＰ", "ご利用加盟店：   ")

    assert_no_difference("Expense.count") do
      post email_imports_path, params: { mail_text: mail_text }
    end

    assert_response :unprocessable_entity
    assert_select "li", text: "利用先を入力してください"
    assert_select "textarea[name='mail_text']", count: 1 do |elements|
      assert_equal mail_text, elements.first.text
    end
  end
end
