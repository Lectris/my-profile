# ==============================================================================
# プロジェクト コード抽出スクリプト for AI Context (v2.0 Improved)
# ==============================================================================
# 機能:
# 1. 指定ディレクトリ以下のファイル構造と内容を連結して出力
# 2. **AIにとってノイズとなる「古い仕様書」や「アーカイブ」を強力に除外**
# 3. 開発環境設定（.vscode等）は維持
# ==============================================================================

# --- 設定項目 ---

# 対象のプロジェクトルートディレクトリ
$TargetProjectDir = "C:\projects\my-profile\src"
# ※docsも含めるために親ディレクトリを指定する場合は適宜変更してください
# 例: $TargetProjectDir = "Y:\projects\bizlaw-integrated"

# 出力先ディレクトリ
$OutputSaveDir = "C:\projects\my-profile\scripts"

# 出力ファイル名
$OutputFileName = "project_context_for_gemini.txt"

# [除外設定 1] フォルダ名（完全一致）
$ExcludeFolders = @(
    "node_modules",
    ".git",
    "dist",
    "build",
    "coverage",
    ".idea",
    ".history",
    "tmp",
    "temp",
    # --- 追加: 古いドキュメント置き場 ---
    "archive",
    "old",
    "backup",
    "logs"
)

# [除外設定 2] ファイル拡張子
$ExcludeExtensions = @(
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg",
    ".pdf", ".exe", ".dll", ".zip", ".tar", ".gz",
    ".7z", ".rar",
    ".lock", ".log", ".sqlite", ".db"
)

# [除外設定 3] 特定のファイル名
$ExcludeFiles = @(
    "package-lock.json",
    "yarn.lock",
    ".DS_Store",
    ".env",
    ".env.local",
    $OutputFileName # 自分自身
)

# [除外設定 4] ファイル名のパターン（正規表現）★ここが重要
# AIに読ませたくない「古いバージョン」のパターンを指定します
$ExcludePatterns = @(
    "Ver\.[0-7]",       # Ver.0.x ～ Ver.7.x を除外 (Ver.8系のみ残す)
    "MigrationPrompt",  # 移行用プロンプトなども除外
    "指示書",            # 古い指示書を除外する場合
    "Copy of"           # コピーファイルなどを除外
)

# --- 初期化処理 ---

$OutputPath = Join-Path $OutputSaveDir $OutputFileName

if (-not (Test-Path $OutputSaveDir)) {
    New-Item -ItemType Directory -Force -Path $OutputSaveDir | Out-Null
}

$null | Set-Content -Path $OutputPath -Encoding UTF8

# --- 関数定義 ---

function Test-IsExcluded {
    param (
        [string]$FullPath,
        [bool]$IsDirectory
    )

    $Name = Split-Path $FullPath -Leaf
    $Extension = [System.IO.Path]::GetExtension($FullPath)

    # 1. フォルダ除外
    if ($IsDirectory) {
        if ($ExcludeFolders -contains $Name) { return $true }
    }

    # 2. 親パスチェック
    foreach ($folder in $ExcludeFolders) {
        if ($FullPath -match "[\\/]$folder[\\/]") { return $true }
    }

    if (-not $IsDirectory) {
        # 3. 拡張子除外
        if ($ExcludeExtensions -contains $Extension) { return $true }
        
        # 4. 特定ファイル名除外
        if ($ExcludeFiles -contains $Name) { return $true }

        # 5. ★パターン除外チェック (古い仕様書を弾く)
        foreach ($pattern in $ExcludePatterns) {
            if ($Name -match $pattern) { return $true }
        }
    }

    return $false
}

# --- 実行処理 ---

Write-Host "処理を開始します..." -ForegroundColor Cyan

# 1. 構造図
Add-Content -Path $OutputPath -Value "# Project Directory Structure" -Encoding UTF8
Add-Content -Path $OutputPath -Value "================================================================================" -Encoding UTF8

function Show-Tree {
    param ([string]$Path, [string]$Indent = "")
    $Items = Get-ChildItem -Path $Path | Sort-Object { $_.PSIsContainer } -Descending

    foreach ($Item in $Items) {
        if (Test-IsExcluded -FullPath $Item.FullName -IsDirectory $Item.PSIsContainer) { continue }
        Add-Content -Path $OutputPath -Value "$Indent- $($Item.Name)" -Encoding UTF8
        if ($Item.PSIsContainer) { Show-Tree -Path $Item.FullName -Indent "$Indent  " }
    }
}
Show-Tree -Path $TargetProjectDir
Add-Content -Path $OutputPath -Value "`n`n" -Encoding UTF8

# 2. ファイル内容
Add-Content -Path $OutputPath -Value "# File Contents (Latest Version Only)" -Encoding UTF8
Add-Content -Path $OutputPath -Value "================================================================================" -Encoding UTF8
Add-Content -Path $OutputPath -Value "`n" -Encoding UTF8

$AllFiles = Get-ChildItem -Path $TargetProjectDir -Recurse -File

foreach ($File in $AllFiles) {
    if (Test-IsExcluded -FullPath $File.FullName -IsDirectory $false) { continue }

    $RelativePath = $File.FullName.Substring($TargetProjectDir.Length + 1)
    Write-Host "Adding: $RelativePath" -ForegroundColor Green

    Add-Content -Path $OutputPath -Value "--------------------------------------------------------------------------------" -Encoding UTF8
    Add-Content -Path $OutputPath -Value "File Path: $RelativePath" -Encoding UTF8
    Add-Content -Path $OutputPath -Value "--------------------------------------------------------------------------------" -Encoding UTF8
    
    try {
        $Content = Get-Content -Path $File.FullName -Raw -ErrorAction Stop
        Add-Content -Path $OutputPath -Value $Content -Encoding UTF8
    }
    catch {
        Add-Content -Path $OutputPath -Value "[Error reading file]" -Encoding UTF8
    }
    Add-Content -Path $OutputPath -Value "`n`n" -Encoding UTF8
}

Write-Host "完了。出力先: $OutputPath" -ForegroundColor Yellow