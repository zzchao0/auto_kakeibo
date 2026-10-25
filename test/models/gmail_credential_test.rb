require "test_helper"

class GmailCredentialTest < ActiveSupport::TestCase
  test "refresh token is required" do
    [ nil, "", "   " ].each do |refresh_token|
      credential = GmailCredential.new(refresh_token: refresh_token)

      refute credential.valid?
      assert credential.errors.added?(:refresh_token, :blank)
    end
  end

  test "refresh token is encrypted in the database and can be read after reload" do
    refresh_token = "dummy-refresh-token-for-testing"
    # 実際のCredentialsの鍵を使わず、テスト専用のダミー鍵で確認する。
    key = ActiveRecord::Encryption::Key.new("a" * 32)
    key_provider = ActiveRecord::Encryption::KeyProvider.new(key)

    ActiveRecord::Encryption.with_encryption_context(key_provider: key_provider) do
      credential = GmailCredential.create!(refresh_token: refresh_token)
      stored_value = GmailCredential.connection.select_value(
        "SELECT refresh_token FROM gmail_credentials WHERE id = #{credential.id}"
      )

      refute_equal refresh_token, stored_value
      refute_includes stored_value, refresh_token
      assert_equal refresh_token, credential.reload.refresh_token
    end
  end
end
