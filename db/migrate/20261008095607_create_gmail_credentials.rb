class CreateGmailCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :gmail_credentials do |t|
      t.text :refresh_token

      t.timestamps
    end
  end
end
