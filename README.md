# auto_kakeibo

- アプリ概要：カード利用通知メールから支出を自動登録する個人用家計簿。現在は開発環境の構築まで完了。

- 技術構成：Ruby 4.0.7、Rails 8.1.4、Hotwire、SQLite、Docker。

- 起動方法：プロジェクト直下でdocker compose up --buildを実行し、http://localhost:3000へアクセス。停止はControl＋C。

- 選定理由：Dockerは開発環境の再現性のため。SQLiteは個人利用の規模に十分で、構成をシンプルに保つため。
