require "googleauth"

class GmailAuthController < ApplicationController
  GMAIL_SCOPE = "https://www.googleapis.com/auth/gmail.readonly".freeze
  CALLBACK_URI = "http://localhost:3000/gmail_auth/callback".freeze

  def create
    state = SecureRandom.hex(32)
    session[:gmail_oauth_state] = state
    authorization_url = google_authorizer.get_authorization_url(state: state)

    redirect_to authorization_url, allow_other_host: true, status: :see_other
  end

  def callback
    expected_state = session.delete(:gmail_oauth_state)
    unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(expected_state, params[:state].to_s)
      return redirect_to expenses_path, alert: "認証情報を確認できませんでした。接続をやり直してください。"
    end

    if params[:error].present?
      return redirect_to expenses_path, alert: "Googleの認可に失敗しました。"
    end

    code = params[:code]
    unless code.is_a?(String) && code.present?
      return redirect_to expenses_path, alert: "認可コードを取得できませんでした。"
    end

    oauth_credentials = google_authorizer.get_credentials_from_code(code: code)
    unless oauth_credentials.includes_scope?(GMAIL_SCOPE)
      return redirect_to expenses_path, alert: "Gmailの読み取り権限がありません。"
    end
    if oauth_credentials.refresh_token.blank?
      return redirect_to expenses_path, alert: "refresh tokenを取得できませんでした。"
    end

    gmail_credential = GmailCredential.first_or_initialize
    if gmail_credential.update(refresh_token: oauth_credentials.refresh_token)
      redirect_to expenses_path, notice: "Gmailと接続しました。"
    else
      redirect_to expenses_path, alert: gmail_credential.errors.full_messages.join(", ")
    end
  rescue Google::Auth::AuthorizationError,
         Google::Auth::ParseError,
         Google::Auth::CredentialsError
    redirect_to expenses_path, alert: "Googleとの認証通信に失敗しました。"
  end

  private
  def google_authorizer
    google = Rails.application.credentials.fetch(:google)
    client_id = Google::Auth::ClientId.new(
      google.fetch(:client_id),
      google.fetch(:client_secret)
    )
    Google::Auth::UserAuthorizer.new(
      client_id,
      GMAIL_SCOPE,
      nil,
      callback_uri: CALLBACK_URI
    )
  end
end
