class GmailCredential < ApplicationRecord
  encrypts :refresh_token
  validates :refresh_token, presence: true
end
