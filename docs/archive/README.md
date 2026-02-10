# **BizLaw Master (Exam App)**

Google Apps Script (GAS) 上で動作する、高機能な試験対策Webアプリケーションです。

v29.0ではUI/UXを大幅に刷新しました。Tailwind CSSによるモダンなダッシュボードデザイン、BudouXによる読みやすい日本語表示、そして高速なレスポンスを実現しています。

## **🚀 主な機能**

* **🧠 スマート学習（おまかせ）**  
  * 忘却曲線と過去の正答履歴に基づき、AIロジックが「今解くべき問題」を自動選定します。  
  * 苦手な問題や久しぶりの問題を優先的に出題し、効率的な学習をサポートします。  
* **📚 リスト学習（検索・選択）**  
  * 試験回、分野（大・中・小分類）、キーワード、ステータス（不正解・未回答）で問題を絞り込み可能。  
  * **アコーディオンUI**により、大量のカテゴリも快適に選択できます。  
* **📊 詳細なデータ分析**  
  * 学習履歴をヒートマップ（カレンダー）で可視化。  
  * **ドリルダウン分析**: 大分類から中分類へと詳細な正答率を確認できます。  
  * **ドリルスルー**: グラフをクリックすると、その条件でフィルタリングされた問題一覧へ直接ジャンプできます。  
* **⚙️ 高度なカスタマイズ**  
  * **文字サイズ調整**: アプリ全体のUIと、問題文の文字サイズを個別に調整可能。  
  * **ダークモード**: システム設定または手動で切り替え可能。  
  * **学習対象切替**: ヘッダーからいつでも試験種別・級を切り替えられます。  
* **⚡ 高速・堅牢**  
  * ユーザー設定と学習中断データを PropertiesService に移行し、読み込み速度を向上。  
  * BudouX を採用し、問題文の改行位置を最適化。

## **🛠️ 技術スタック**

* **Frontend**:  
  * HTML5, CSS3 (**Tailwind CSS** \- CDN版)  
  * JavaScript (Vanilla ES6+)  
  * **KaTeX** (数式表示)  
  * **BudouX** (日本語自動改行処理)  
* **Backend**:  
  * Google Apps Script (V8 Runtime)  
  * **PropertiesService** (ユーザー設定・中断データ保存)  
* **Database**:  
  * Google Spreadsheets (マスタデータ、学習履歴、フラグ管理)  
* **Deployment**:  
  * Google Clasp (Command Line Apps Script Projects)

## **📂 ディレクトリ構成**

/  
├── src/  
│   ├── index.html       \# フロントエンド全ロジック・UI (SPA)  
│   ├── WebApp.js        \# バックエンドAPI・ビジネスロジック  
│   └── appsscript.json  \# GAS設定ファイル  
├── data\_formatter/      \# データ管理用ツール  
│   ├── DataNormalizer.js  
│   └── appsscript.json  
├── docs/                \# ドキュメント  
│   └── Specification.md  
└── README.md

## **💻 セットアップ手順**

### **1\. 前提条件**

* Google アカウント  
* Node.js & npm (ローカル開発の場合)  
* Google Clasp (npm install \-g @google/clasp)

### **2\. プロジェクトのクローン**

git clone \<repository-url\>  
cd \<repository-folder\>

### **3\. スプレッドシートの準備**

1. 新規Googleスプレッドシートを作成します。  
2. スプレッドシートのID（URLの /d/ と /edit の間の文字列）を控えておきます。  
3. 以下のシートを作成します（data\_formatter を利用してデータ投入可能）。  
   * **マスタデータ**: exams, exam\_instances, scenarios, questions, choices  
   * **ユーザーデータ**: history, review\_flags, reports  
   * **設定**: sort\_master  
   * ※ user\_settings シートは v29.0 以降、PropertiesService への移行に伴い使用されませんが、互換性のために残しても構いません。

### **4\. Webアプリ (src) のデプロイ**

cd src

\# 新規GASプロジェクトを作成する場合  
clasp create \--type webapp \--title "BizLaw Master App"  
\# 既存のプロジェクトに関連付ける場合  
\# clasp setting scriptId "YOUR\_SCRIPT\_ID"

**重要: スプレッドシートIDの設定**

1. clasp open でGASエディタを開きます。  
2. 「プロジェクトの設定」 \> 「スクリプト プロパティ」を開きます。  
3. プロパティ SS\_ID を追加し、手順3で控えたスプレッドシートIDを値として保存します。  
   * ※ コード内の getSpreadsheetId() を直接書き換えることも可能ですが、プロパティでの管理を推奨します。

\# コードのアップロード  
clasp push

\# デプロイ（新しいバージョンを作成して公開）  
clasp deploy \--description "Deploy v29.0"

デプロイ完了後、表示されるURL（Web App URL）にアクセスして動作を確認します。

### **5\. データ管理ツール (data\_formatter) のセットアップ**

データのインポートや正規化を行うためのツールです。Webアプリと同じスプレッドシートに紐付けます。

cd ../data\_formatter

\# 新規GASプロジェクトを作成（Webアプリとは別のプロジェクトとして作成）  
clasp create \--type sheets \--title "BizLaw Data Formatter" \--parentId "YOUR\_SPREADSHEET\_ID"

clasp push

スプレッドシートを開き、メニューに追加された機能からデータをインポート・正規化します。

## **📝 ライセンス**

MIT License