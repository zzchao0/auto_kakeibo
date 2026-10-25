require "test_helper"
require "minitest/mock"

class GmailAuthControllerTest < ActionDispatch::IntegrationTest
  AUTHORIZATION_CODE = "dummy-authorization-code".freeze

  setup do
    # 生成時のfixtureに依存せず、認証情報がない状態から始める。
    GmailCredential.delete_all

    @app_credentials = ActiveSupport::OrderedOptions.new
    @app_credentials.google = {
      client_id: "dummy-client-id",
      client_secret: "dummy-client-secret"
    }

    client_id = Google::Auth::ClientId.new("dummy-client-id", "dummy-client-secret")
    @authorizer = Google::Auth::UserAuthorizer.new(
      client_id,
      GmailAuthController::GMAIL_SCOPE,
      nil,
      callback_uri: GmailAuthController::CALLBACK_URI
    )

    key = ActiveRecord::Encryption::Key.new("a" * 32)
    @key_provider = ActiveRecord::Encryption::KeyProvider.new(key)
  end

  test "create redirects to Google with readonly scope offline access and session state" do
    with_google_authorizer do
      assert_no_difference("GmailCredential.count") do
        post gmail_auth_index_path
      end

      assert_response :see_other
      uri = URI(response.location)
      parameters = URI.decode_www_form(uri.query).to_h

      assert_equal "https", uri.scheme
      assert_equal "accounts.google.com", uri.host
      assert_equal "dummy-client-id", parameters.fetch("client_id")
      assert_equal GmailAuthController::GMAIL_SCOPE, parameters.fetch("scope")
      assert_equal GmailAuthController::CALLBACK_URI, parameters.fetch("redirect_uri")
      assert_equal "code", parameters.fetch("response_type")
      assert_equal "offline", parameters.fetch("access_type")
      assert_match(/\A[0-9a-f]{64}\z/, parameters.fetch("state"))
      assert_equal parameters.fetch("state"), request.session[:gmail_oauth_state]
      refute parameters.key?("client_secret")
      assert_empty @code_exchanges
    end
  end

  test "callback saves the refresh token and redirects to the expense list" do
    with_google_authorizer do
      state = start_authorization

      assert_difference("GmailCredential.count", 1) do
        get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      end

      assert_redirected_to expenses_path
      assert_equal "Gmailと接続しました。", flash[:notice]
      assert_equal "dummy-refresh-token", GmailCredential.first.refresh_token
      assert_equal [ { code: AUTHORIZATION_CODE } ], @code_exchanges
      assert_nil request.session[:gmail_oauth_state]
    end
  end

  test "callback updates an existing credential without adding another record" do
    with_google_authorizer do
      gmail_credential = GmailCredential.create!(refresh_token: "old-dummy-refresh-token")
      state = start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      end

      assert_redirected_to expenses_path
      assert_equal "Gmailと接続しました。", flash[:notice]
      assert_equal "dummy-refresh-token", gmail_credential.reload.refresh_token
    end
  end

  test "callback rejects a mismatched state before exchanging the code" do
    with_google_authorizer do
      start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: "wrong-state", code: AUTHORIZATION_CODE }
      end

      assert_state_error
      assert_empty @code_exchanges
    end
  end

  test "callback rejects a missing state before exchanging the code" do
    with_google_authorizer do
      start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { code: AUTHORIZATION_CODE }
      end

      assert_state_error
      assert_empty @code_exchanges
    end
  end

  test "callback rejects a request without an authorization session" do
    with_google_authorizer do
      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: "unsolicited-state", code: AUTHORIZATION_CODE }
      end

      assert_state_error
      assert_empty @code_exchanges
    end
  end

  test "callback cannot reuse an already consumed state" do
    with_google_authorizer do
      state = start_authorization
      get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      assert_equal "Gmailと接続しました。", flash[:notice]

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      end

      assert_state_error
      assert_equal [ { code: AUTHORIZATION_CODE } ], @code_exchanges
    end
  end

  test "callback handles denied authorization without exchanging the code" do
    with_google_authorizer do
      state = start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: state, error: "access_denied" }
      end

      assert_redirected_to expenses_path
      assert_equal "Googleの認可に失敗しました。", flash[:alert]
      assert_empty @code_exchanges
    end
  end

  test "callback rejects missing blank or malformed authorization codes" do
    [ nil, "", { unexpected: "value" } ].each do |code|
      with_google_authorizer do
        state = start_authorization

        assert_no_difference("GmailCredential.count") do
          get gmail_auth_callback_path, params: { state: state, code: code }
        end

        assert_redirected_to expenses_path
        assert_equal "認可コードを取得できませんでした。", flash[:alert]
        assert_empty @code_exchanges
      end
    end
  end

  test "callback handles token exchange errors without saving credentials" do
    [ Google::Auth::AuthorizationError, Google::Auth::ParseError, Google::Auth::CredentialsError ].each do |error_class|
      with_google_authorizer(exchange_error: error_class.new("dummy token exchange failure")) do
        state = start_authorization

        assert_no_difference("GmailCredential.count") do
          get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
        end

        assert_redirected_to expenses_path
        assert_equal "Googleとの認証通信に失敗しました。", flash[:alert]
        assert_equal [ { code: AUTHORIZATION_CODE } ], @code_exchanges
      end
    end
  end

  test "callback rejects credentials without the Gmail readonly scope" do
    token_response = oauth_credentials(scope: "https://www.googleapis.com/auth/userinfo.email")

    with_google_authorizer(token_response: token_response) do
      state = start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      end

      assert_redirected_to expenses_path
      assert_equal "Gmailの読み取り権限がありません。", flash[:alert]
    end
  end

  test "callback preserves the existing token when no refresh token is returned" do
    with_google_authorizer(token_response: oauth_credentials(refresh_token: nil)) do
      gmail_credential = GmailCredential.create!(refresh_token: "old-dummy-refresh-token")
      state = start_authorization

      assert_no_difference("GmailCredential.count") do
        get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
      end

      assert_redirected_to expenses_path
      assert_equal "refresh tokenを取得できませんでした。", flash[:alert]
      assert_equal "old-dummy-refresh-token", gmail_credential.reload.refresh_token
    end
  end

  test "callback displays model errors when saving fails" do
    with_google_authorizer do
      state = start_authorization
      gmail_credential = GmailCredential.new
      gmail_credential.errors.add(:base, "保存できませんでした。")

      GmailCredential.stub(:first_or_initialize, gmail_credential) do
        gmail_credential.stub(:update, false) do
          assert_no_difference("GmailCredential.count") do
            get gmail_auth_callback_path, params: { state: state, code: AUTHORIZATION_CODE }
          end
        end
      end

      assert_redirected_to expenses_path
      assert_equal "保存できませんでした。", flash[:alert]
      assert_nil flash[:notice]
    end
  end

  private

  def start_authorization
    post gmail_auth_index_path
    assert_response :see_other
    URI.decode_www_form(URI(response.location).query).to_h.fetch("state")
  end

  def assert_state_error
    assert_redirected_to expenses_path
    assert_equal "認証情報を確認できませんでした。接続をやり直してください。", flash[:alert]
  end

  def oauth_credentials(refresh_token: "dummy-refresh-token", scope: GmailAuthController::GMAIL_SCOPE)
    Google::Auth::UserRefreshCredentials.new(
      client_id: "dummy-client-id",
      client_secret: "dummy-client-secret",
      access_token: "dummy-access-token",
      refresh_token: refresh_token,
      scope: scope
    )
  end

  def with_google_authorizer(token_response: oauth_credentials, exchange_error: nil)
    @code_exchanges = []
    token_exchange = lambda do |**options|
      @code_exchanges << options
      raise exchange_error if exchange_error
      token_response
    end

    # 認可URLは実際のgemで生成し、通信が発生するcode交換だけをスタブする。
    # アプリの認証情報とDB暗号化鍵には、いずれもテスト専用の値を使う。
    Rails.application.stub(:credentials, -> { @app_credentials }) do
      Google::Auth::UserAuthorizer.stub(:new, @authorizer) do
        @authorizer.stub(:get_credentials_from_code, token_exchange) do
          ActiveRecord::Encryption.with_encryption_context(key_provider: @key_provider) do
            yield
          end
        end
      end
    end
  end
end
