# **BizLaw Master**

Google Apps Script (GAS) と Googleスプレッドシートを基盤とした、サーバーレス・学習支援Webアプリケーションです。

司法試験やビジネス法務検定などの学習効率を最大化するために設計されており、忘却曲線に基づいたスマート学習機能や、学習履歴の分析機能を備えています。

## **📖 目次**

1. [概要](https://www.google.com/search?q=%23%E6%A6%82%E8%A6%81)  
2. [主な機能](https://www.google.com/search?q=%23%E4%B8%BB%E3%81%AA%E6%A9%9F%E8%83%BD)  
3. [システム要件](https://www.google.com/search?q=%23%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E8%A6%81%E4%BB%B6)  
4. [セットアップ手順](https://www.google.com/search?q=%23%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%E6%89%8B%E9%A0%86)  
   * [1\. スプレッドシートの準備](https://www.google.com/search?q=%231-%E3%82%B9%E3%83%97%E3%83%AC%E3%83%83%E3%83%89%E3%82%B7%E3%83%BC%E3%83%88%E3%81%AE%E6%BA%96%E5%82%99)  
   * [2\. スクリプトの配置](https://www.google.com/search?q=%232-%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%81%AE%E9%85%8D%E7%BD%AE)  
   * [3\. デプロイ](https://www.google.com/search?q=%233-%E3%83%87%E3%83%97%E3%83%AD%E3%82%A4)  
5. [データベース構造](https://www.google.com/search?q=%23%E3%83%87%E3%83%BC%E3%82%BF%E3%83%99%E3%83%BC%E3%82%B9%E6%A7%8B%E9%80%A0)  
6. [技術スタック](https://www.google.com/search?q=%23%E6%8A%80%E8%A1%93%E3%82%B9%E3%82%BF%E3%83%83%E3%82%AF)  
7. [ライセンス](https://www.google.com/search?q=%23%E3%83%A9%E3%82%A4%E3%82%BB%E3%83%B3%E3%82%B9)

## **概要**

BizLaw Master は、専用のサーバーを必要とせず、Googleアカウントがあれば誰でも無料で構築・運用できる学習アプリです。

バックエンドに GAS を使用し、データベースとして Googleスプレッドシートを利用します。フロントエンドは Single Page Application (SPA) として動作し、高速で快適なユーザー体験を提供します。

**バージョン情報**

* **Backend (WebApp.js)**: v30.0 (Data Fetch Optimization)  
* **Frontend (index.html)**: v2.3

## **主な機能**

* **📚 スマート学習モード**: ユーザーの学習履歴（正誤、経過日数）とフラグ状況を分析し、今解くべき問題をアルゴリズムが自動選出します。  
* **🚩 フラグ機能**: 「あとで解く」フラグを付けた問題を重点的に復習できます。  
* **📊 学習分析**: 学習時間、解答数、正答率、週間アクティビティ（ヒートマップ）を可視化します。  
* **📱 レスポンスデザイン**: PC、タブレット、スマートフォンなど、あらゆるデバイスに最適化されたUIを提供します。  
* **⚡ 強制選択ポリシー**: 学習対象（試験・実施回）の未選択による不具合を防ぐため、起動時に選択を強制する堅牢なフローを採用しています。  
* **📝 多機能クイズUI**:  
  * KaTeXによる数式レンダリング  
  * BudouXによる日本語テキストの読みやすい折り返し  
  * 消去法モード（選択肢の取り消し線）

## **システム要件**

* Google アカウント (個人用またはGoogle Workspace)  
* モダンブラウザ (Chrome, Safari, Edge, Firefox 等)

## **セットアップ手順**

### **1\. スプレッドシートの準備**

新規に Googleスプレッドシートを作成し、以下のシートを追加してください。シート名は正確に設定する必要があります。

| シート名 | 用途 | 必須カラム (1行目) |
| :---- | :---- | :---- |
| exams | 試験マスタ | exam\_id, exam\_name, exam\_grade |
| exam\_instances | 実施回マスタ | instance\_id, exam\_id, exam\_edition, exam\_type |
| questions | 問題データ | question\_id, instance\_id, question\_no, text, category\_1, category\_2, category\_3, correct\_answer, explanation, answer\_type, scenario\_id |
| choices | 選択肢 | question\_id, choice\_no, choice\_text |
| scenarios | 問題文(共通) | scenario\_id, scenario\_no, scenario\_text |
| history | 学習履歴 | timestamp, user\_id, question\_id, user\_answer, is\_correct |
| review\_flags | フラグ | timestamp, user\_id, question\_id |
| user\_settings | ユーザー設定 | user\_id, settings\_json, last\_updated |
| sort\_master | ソート順定義 | master\_type, value, sort\_order, parent\_value\_1 |
| reports | 問題報告 | timestamp, user\_id, question\_id, type, comment |

**注意**: history, review\_flags, user\_settings, reports シートは、アプリ利用時に自動的にデータが書き込まれますが、ヘッダー行（1行目）は事前に作成しておくことを推奨します。

### **2\. スクリプトの配置**

1. 作成したスプレッドシートのメニューから **\[拡張機能\]** \> **\[Apps Script\]** を開きます。  
2. コード.gs (デフォルト) の中身を削除し、本プロジェクトの WebApp.js の内容を貼り付けます。  
3. ファイル名を WebApp に変更します（任意）。  
4. **\[ファイル\]** \> **\[HTML を追加\]** を選択し、ファイル名を index とします。  
5. index.html の中身を削除し、本プロジェクトの index.html の内容を貼り付けます。

### **3\. デプロイ**

1. スクリプトエディタの右上の **\[デプロイ\]** \> **\[新しいデプロイ\]** をクリックします。  
2. **\[種類の選択\]** 歯車アイコンから **\[ウェブアプリ\]** を選択します。  
3. 各項目を以下のように設定します。  
   * **説明**: v1.0 (任意)  
   * **次のユーザーとして実行**: **自分** (重要: スプレッドシートへのアクセス権を持つアカウントで実行するため)  
   * **アクセスできるユーザー**: **全員** (またはGoogle Workspace内のユーザー)  
4. **\[デプロイ\]** をクリックします。  
5. 初回のみ「アクセス権の承認」が求められます。許可してください。  
6. 発行された **ウェブアプリ URL** をコピーし、ブラウザで開きます。

## **データベース構造**

各シートの詳細なカラム定義です。

#### **exams (試験マスタ)**

* **exam\_id**: 試験を一意に識別するID (例: 1\)  
* **exam\_name**: 試験名 (例: 司法試験)  
* **exam\_grade**: 等級やレベル (例: 短答式)

#### **exam\_instances (実施回マスタ)**

* **instance\_id**: 実施回ID (例: 101\)  
* **exam\_id**: 親となる試験ID (FK)  
* **exam\_edition**: 実施年度や回数 (例: 令和5年)  
* **exam\_type**: 科目や区分 (例: 民法)

#### **questions (問題データ)**

* **question\_id**: 問題ID (Unique)  
* **instance\_id**: 実施回ID (FK)  
* **question\_no**: 問題番号  
* **text**: 問題文 (HTMLタグ使用可)  
* **correct\_answer**: 正解 (選択肢インデックス 0始まり、またはテキスト)  
* **explanation**: 解説文  
* **answer\_type**: 解答形式 (SCMC:択一, TEXT:記述)

#### **user\_settings (ユーザー設定)**

* **user\_id**: ユーザー識別子  
* **settings\_json**: 設定情報のJSON文字列（ダークモード設定、前回のフィルタ条件など）  
* **last\_updated**: 最終更新日時

## **技術スタック**

本アプリケーションは、外部ライブラリをCDN経由で読み込み、軽量かつモダンな構成で構築されています。

### **バックエンド**

* **Google Apps Script (GAS)**: サーバーサイドロジック  
* **Google Sheets**: データベース  
* **CacheService**: データ取得の高速化（マスタデータのキャッシュ）  
* **LockService**: 排他制御（履歴保存時の競合防止）

### **フロントエンド**

* **HTML5 / JavaScript (ES6+)**: SPAアーキテクチャ  
* **Tailwind CSS**: ユーティリティファーストなスタイリング  
* **BudouX**: 日本語テキストの改行最適化  
* **KaTeX**: 数式の高速レンダリング  
* **Google Fonts**: Inter, Noto Sans JP

## **開発者向け情報**

### **初期化フローについて**

アプリ起動時 (DOMContentLoaded) に getInitialData が呼び出されます。

* **復元成功**: 以前選択していた instance\_id が有効であれば、自動的にホーム画面へ遷移します。  
* **復元失敗/初回**: 強制モーダルが表示され、ユーザーは学習対象を選択するまで他の操作がブロックされます（isForced=true）。

### **IDの取り扱い**

スプレッドシート上では数値として扱われるIDも、アプリ内部では不整合を防ぐため String(id).trim() により文字列として正規化して比較・保存されます。

## **ライセンス**

This project is open source and available under the