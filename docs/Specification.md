# **BizLaw Master アプリケーション仕様書**

## **1\. システム概要**

本システムは、学習支援アプリケーション「BizLaw Master」である。Google Apps Script (GAS) をバックエンド、HTML/JavaScript (SPA) をフロントエンドとするサーバーレスアーキテクチャを採用している。

**アーキテクチャの特徴:**

* **バックエンド**: Googleスプレッドシートをデータベースとして利用し、GASがAPIエンドポイントとして機能する。  
* **フロントエンド**: Google Apps Scriptの HtmlService によって配信されるSingle Page Application (SPA)。  
* **通信**: google.script.run を介した非同期通信により、データの取得と更新を行う。

## **2\. バックエンド仕様 (WebApp.js)**

**バージョン**: 30.0 (Data Fetch Optimization)

### **2.1 データソース定義 (Googleスプレッドシート)**

各シートは定数 SHEET\_KEYS によって管理される。

| キー名 | シート論理名 | 内容 | 主要カラム |
| :---- | :---- | :---- | :---- |
| EXAMS | exams | 試験マスタ | exam\_id, exam\_name, exam\_grade |
| INSTANCES | exam\_instances | 試験実施回マスタ | instance\_id, exam\_id (FK), exam\_edition, exam\_type |
| QUESTIONS | questions | 問題データ | question\_id, text, category\_1, correct\_answer, explanation, question\_image |
| HISTORY | history | 学習履歴 | user\_id, question\_id, is\_correct, timestamp |
| FLAGS | review\_flags | 復習フラグ | user\_id, question\_id |
| USER\_SETTINGS | user\_settings | ユーザー設定 | user\_id, settings\_json (JSON文字列), last\_updated |

### **2.2 主要APIインターフェース**

#### **初期化・データ取得**

* **getInitialData(providedId)**  
  * アプリ起動時に呼び出される単一のエントリーポイント。  
  * **目的**: 初回レンダリングに必要な最小限のデータ（マスタ、設定）を高速に返却し、フロントエンドのフリーズを防ぐ。  
  * **戻り値**:  
    * status: 処理結果 ('SUCCESS' または 'ERROR')。  
    * masterData: getExamMasterData() で生成された階層型マスタデータ。  
    * userSettings: user\_settings シートおよび PropertiesService からマージされた設定情報。  
    * savedInstanceId: ユーザーが最後に選択していた実施回ID（PropertiesService の LAST\_INSTANCE\_ID）。  
  * **変更点 (v30.0)**: 重い処理（全問題のメタデータ生成）を廃止し、マスタ取得と設定取得に特化。Date型データの文字列化（サニタイズ）を強制。  
* **getExamMasterData()**  
  * **機能**: exams シートと exam\_instances シートの全データを取得し、exam\_id をキーに結合する。  
  * **構造**: 試験オブジェクトの配列。各オブジェクトは instances 配列をネストして保持する。  
    \[  
      {  
        "exam\_id": 1,  
        "name": "試験名",  
        "grade": "等級",  
        "instances": \[  
          { "instance\_id": 101, "edition": "第1回", "type": "区分" },  
          ...  
        \]  
      },  
      ...  
    \]

  * **サニタイズ**: 取得したデータ内の Date オブジェクトはすべて toISOString() 等で文字列に変換される。

#### **学習・分析**

* **getQuestionsByIds(providedId, questionIds)**: 指定IDリストの問題詳細を取得。choices (選択肢) や scenarios (問題文) を結合して返却する。  
* **getSmartQuestions(providedId, count, filters)**: 忘却曲線や正答率に基づき、優先すべき問題をアルゴリズムで抽出する。  
* **getUserStats(providedId, filters)**: 学習履歴を集計し、正答率、学習時間、週間アクティビティ（GitHub風ヒートマップ用データ）を算出する。

#### **データ更新**

* **saveUserSettings(providedId, settingsJson)**:  
  * ユーザー設定を保存する。  
  * **ハイブリッド保存**: 高速な読み込みのために PropertiesService (UserProperties) を使用しつつ、データの永続性と可搬性のためにスプレッドシート (user\_settings) にもJSON形式でバックアップする。  
  * 排他制御 (LockService) を使用。  
* **saveHistory(providedId, questionId, answer, isCorrect)**: 学習履歴を追記保存。  
* **resetUserHistory(providedId, target)**: 指定条件（全削除または特定試験のみ）の履歴を物理削除する。

## **3\. フロントエンド仕様 (index.html)**

**バージョン**: 2.3

### **3.1 アプリケーション構造 (SPA)**

画面遷移を行わず、DOM要素のクラス操作（hidden クラスの着脱）によってページ遷移を実現する。

* **ページ構成**:  
  * \#home-page: ダッシュボード。スマート学習開始ボタン、フラグ問題へのアクセス、レジューム（続きから再開）カード。  
  * \#question-list-page: 問題一覧。フィルタリング、検索、個別出題機能。  
  * \#quiz-page: クイズ実行画面。問題文、選択肢、解説、進捗バー、中断機能。  
  * \#stats-page: 学習分析。統計サマリ、カテゴリ別正答率グラフ、アクティビティヒートマップ。  
  * \#settings-page: アプリ設定。アカウント情報、表示設定（ダークモード等）、データ管理。  
  * \#result-page: セッション結果発表。スコア表示、再挑戦ボタン。

### **3.2 状態管理 (quizState)**

グローバル変数 quizState および MASTER\_DATA によりアプリの状態を一元管理する。

* **MASTER\_DATA**: バックエンドから取得した試験・実施回の階層データ（読み取り専用）。  
* **quizState**:  
  * userId: ユーザー識別子。  
  * activeFilters: 現在選択されている学習対象 (examId, currentInstanceId, grade)。  
  * settings: ユーザー設定（ダークモード、文字サイズ、前回フィルタ情報等）。  
  * currentSet: 現在出題中の問題セット。  
  * history: セッション内での回答履歴。

### **3.3 初期化フローと強制選択ポリシー (変更点詳細)**

「学習対象（試験・回）が未選択のままアプリが利用される」バグを防止するため、以下の厳格な初期化フローを実装している。

1. **起動 (DOMContentLoaded)**:  
   * 画面ロードと同時に getInitialData を呼び出す。  
   * 通信中は画面全体を覆うローディングオーバーレイを表示する。  
2. **データ検証と分岐 (initApp)**:  
   * レスポンスの status を確認し、エラーがあればアラートを表示して停止する。  
   * **ケースA（復元成功）**:  
     * サーバーから返却された savedInstanceId（または userSettings.lastInstanceId）が存在し、かつ MASTER\_DATA 内に有効なデータとして存在する場合。  
     * 自動的にその試験・回を選択状態 (quizState.activeFilters) に設定し、ホーム画面を表示する。モーダルは開かない。  
   * **ケースB（復元失敗・初回起動）**:  
     * 保存データがない、または無効な場合。  
     * openSelectionModal(true) を呼び出し、強制モードでモーダルを開く。  
3. **強制モーダル仕様 (selectionModal)**:  
   * **強制モード (isForced=true)**:  
     * モーダルの背景クリックによる「閉じる」動作を無効化。  
     * 閉じるボタンやキャンセルボタンを非表示化。  
     * ユーザーは有効な試験・回を選択し、「確定」ボタンを押さない限り、モーダルを閉じることができず、アプリ操作がブロックされる。

### **3.4 主要機能ロジック**

#### **モーダル制御 (renderSelectionModal)**

* グローバル変数 MASTER\_DATA を使用してプルダウンを動的に生成する。  
* **第1階層（試験選択）**: 試験名＋等級を表示。変更時に change イベントが発火し、第2階層をリセット・再生成する。  
* **第2階層（実施回選択）**: 選択された試験IDに紐づく instances 配列を展開して表示。  
* **確定ボタン**: 第2階層まで選択された状態でのみ有効化 (disabled \= false) される。  
* **確定処理 (applySelection)**:  
  * 選択された instanceId を quizState に反映。  
  * saveUserSettings を呼び出し、選択状態を永続化（次回起動時の復元用）。  
  * ヘッダーのコンテキスト表示を更新し、各ページのデータをリフレッシュする。

#### **クイズ実行 (renderQuestion, handleAnswer)**

* **数式レンダリング**: KaTeXライブラリを使用し、問題文や解説中のLaTeX形式の数式 ($, $$) をレンダリングする。  
* **文章解析**: BudouXを使用し、日本語の改行位置を最適化して可読性を向上させる。  
* **解答モード**:  
  * **即時判定**: 選択肢タップと同時に正誤判定を行い、解説を表示する。  
  * **消去法対応**: 設定により有効化。選択肢右側のボタンで取り消し線を表示し、選択肢を絞り込む補助機能を提供する。

#### **分析機能 (loadStatsData)**

* 外部ライブラリ（Chart.js等）への依存を排除し、CSSとDOM操作のみで軽量なグラフ描画を実現。  
* **積み上げ棒グラフ**: 正答・不正答・未回答の割合をCSS width で表現。  
* **アクティビティヒートマップ**: 過去2ヶ月間の学習頻度を、日付ごとのセル色変化（ヒートマップ）としてカレンダー形式で描画する。

## **4\. データフロー概要**

1. **起動時**:  
   * フロントエンド \-\> バックエンド: getInitialData リクエスト。  
   * バックエンド \-\> フロントエンド: 結合済みマスタデータ (exams \+ instances) とユーザー設定を返却。  
2. **学習対象選択**:  
   * ユーザー操作: モーダルで試験・回を選択して確定。  
   * フロントエンド: quizState 更新、ヘッダー表示更新、saveUserSettings で選択IDを保存。  
3. **出題リクエスト**:  
   * **スマート学習**: getSmartQuestions をコール。バックエンドはアルゴリズムに基づき問題を抽出。  
   * **リスト出題**: getQuestionsByIds をコール。選択されたIDリストの詳細データを取得。  
4. **回答と履歴保存**:  
   * ユーザー操作: 回答を選択。  
   * フロントエンド: 即時に正誤判定と解説表示（楽観的UI）。バックグラウンドで saveHistory を非同期送信。