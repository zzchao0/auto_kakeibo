require "test_helper"
require "minitest/mock"
require "google/apis/gmail_v1"

class GmailClientTest < ActiveSupport::TestCase
  test "取得した本文をUTF-8の文字列として返す" do
    expected_text = File.read(Rails.root.join("test/fixtures/SonyBankWALLETメール文サンプル"), encoding: "UTF-8")
    message_id = "dummy-message-id"
    gmail_service = Google::Apis::GmailV1::GmailService.new
    search_response = Google::Apis::GmailV1::ListMessagesResponse.new(
      messages: [ Google::Apis::GmailV1::Message.new(id: message_id) ]
    )
    message_response = Google::Apis::GmailV1::Message.new(
      payload: Google::Apis::GmailV1::MessagePart.new(
        mime_type: "text/plain",
        # 実メール取得時と同じく、内容はUTF-8でもRuby上はBINARYの状態を再現する。
        body: Google::Apis::GmailV1::MessagePartBody.new(data: expected_text.b)
      )
    )

    # 認証処理とGoogleへの通信を置き換え、本文取得の動作だけを確認する。
    GmailClient.stub(:get_gmail_service, gmail_service) do
      gmail_service.stub(:list_user_messages, search_response) do
        gmail_service.stub(:get_user_message, message_response) do
          text = GmailClient.fetch_gmail_text

          assert_equal Encoding::UTF_8, text.encoding
          assert text.valid_encoding?
          assert_equal expected_text, text
        end
      end
    end
  end

  test "検索結果が0件なら詳細取得せずnilを返す" do
    gmail_service = Google::Apis::GmailV1::GmailService.new
    # messagesが省略され、nilになっている検索結果を用意する。
    search_response = Google::Apis::GmailV1::ListMessagesResponse.new
    unexpected_detail_call = ->(*) { flunk "検索結果が0件なら、メール詳細の取得は呼ばない" }

    GmailClient.stub(:get_gmail_service, gmail_service) do
      gmail_service.stub(:list_user_messages, search_response) do
        gmail_service.stub(:get_user_message, unexpected_detail_call) do
          assert_nil GmailClient.fetch_gmail_text
        end
      end
    end
  end
end
