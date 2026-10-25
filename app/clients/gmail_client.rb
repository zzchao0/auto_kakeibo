require "googleauth"
require "google/apis/gmail_v1"

class GmailClient
  GMAIL_SCOPE = "https://www.googleapis.com/auth/gmail.readonly".freeze

  def self.fetch_gmail_text
    gmail_service = self.get_gmail_service
    user_id = "me"
    query = 'subject:"［ソニー銀行］Sony Bank WALLET ご利用のお知らせ"'

    response = gmail_service.list_user_messages(user_id, q: query, max_results: 1)
    if response.messages.blank?
      return nil
    end
    message_id = response.messages.first.id

    message = gmail_service.get_user_message(user_id, message_id, format: "full")
    mime_type = message.payload.mime_type
    if mime_type == "text/plain"
      gmail_text = message.payload.body.data
    elsif mime_type.start_with?("multipart/")
      plain_part = message.payload.parts&.find { |part| part.mime_type == "text/plain" }
      unless plain_part
        return nil
      end
      gmail_text = plain_part.body.data
    end
    gmail_text&.force_encoding("UTF-8")
  end

  def self.get_gmail_service
    google = Rails.application.credentials.fetch(:google)
    client_id = google.fetch(:client_id)
    client_secret = google.fetch(:client_secret)

    gmail_credential = GmailCredential.first
    unless gmail_credential&.refresh_token.present?
      raise Google::Auth::CredentialsError, "Gmailに接続してください。"
    end
    refresh_token = gmail_credential.refresh_token

    gmail_oauth = Google::Auth::UserRefreshCredentials.new(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token,
      scope: GMAIL_SCOPE
    )
    gmail_oauth.fetch_access_token!

    gmail_service = Google::Apis::GmailV1::GmailService.new
    gmail_service.authorization = gmail_oauth
    gmail_service
  end

  private_class_method :get_gmail_service
end
