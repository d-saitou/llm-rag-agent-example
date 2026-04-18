<#
.SYNOPSIS
    LLM・RAG エージェント開発環境 初期構築スクリプト
.DESCRIPTION
    以下の開発環境構築処理を実行する：
    1. システム要件チェック（WSL, Docker Desktop, VS Code, VS Code Remote Development）
    2. WSL インスタンス構築
    3. WSL インスタンスプロビジョニング実行 (./infra/provision/provision.sh)
    4. VS Code リモートセッション起動
.NOTES
    - 実行前に プロジェクトルート/.env ファイルを作成し、ユーザー情報等を環境に合わせて変更すること。
#>
$ErrorActionPreference = "Stop"
$ScriptName = $MyInvocation.MyCommand.Name

<#
.SYNOPSIS
    ログメッセージコンソール出力
.PARAMETER Message
    出力メッセージ文字列
.PARAMETER Level
    ログレベル文字列
.DESCRIPTION
    タイムスタンプとログレベルを付与してコンソールに出力する。例: [2026-04-01 12:00:00][INFO] メッセージ
#>
function Write-Log {
  param(
    [string]$Message,
    [string]$Level = "INFO"
  )
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "[$ts][$Level][$ScriptName] $Message"
}

<#
.SYNOPSIS
    ファイルダウンロード
.PARAMETER Url
    ダウンロード URL
.PARAMETER Path
    保存先パス
.DESCRIPTION
    指定URLからファイルをダウンロードし、指定パスに保存する。既にファイルが存在する場合はダウンロードをスキップする。
#>
function Get-File {
  param([string]$Url, [string]$Path)
  if (!(Test-Path $Path)) {
    Write-Log "ファイルダウンロード開始... (${Url})"
    try {
      # Import-Module BitsTransfer
      # Start-BitsTransfer -Source $Url -Destination $Path -Priority Foreground -RetryTimeout 60 -RetryInterval 60 -ErrorAction Stop
      Invoke-WebRequest -Uri $Url -OutFile $Path
    } catch {
      if (Test-Path $Path) {
        Remove-Item $Path -Force
      }
      throw "ダウンロード失敗: $($_.Exception.Message)"
    }
  }
}

<#
.SYNOPSIS
    Windows パス → WSL 内マウントパス変換
.PARAMETER WindowsPath
    Windows パス
.DESCRIPTION
    Windows のパスを WSL 内でアクセス可能なマウントパスに変換する。例: C:\path\to\dir → /mnt/c/path/to/dir
#>
function Convert-ToWslPath {
  param([string]$WindowsPath)
  $path = $WindowsPath -replace "\\", "/"
  if ($path -match "^([A-Za-z]):(?<rest>.*)") {
    $drive = $Matches[1].ToLower()
    $rest = $Matches['rest']
    return "/mnt/$drive$($rest.TrimEnd('/'))"
  }
  return $path
}

<#
.SYNOPSIS
    システム要件チェック（WSL, Docker Desktop, VS Code, VS Code Remote Development）
.DESCRIPTION
    以下のシステム要件が満たされているかチェックする：
    - WSL がインストールされていること
    - Docker Desktop がインストールされており、起動していること
    - VS Code がインストールされていること
    - VS Code Remote Development 拡張がインストールされていること
#>
function Test-SystemRequirements {
  Write-Log "システムチェック..."

  if (!(Get-Command wsl -ErrorAction SilentlyContinue)) {
    throw "WSL が見つかりません"
  }

  if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI が見つかりません"
  }

  docker info > $null 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Docker が起動していません"
  }

  if (!(Get-Command code -ErrorAction SilentlyContinue)) {
    throw "VS Code が見つかりません"
  }

  $isInstalledRemoteExt = code --list-extensions | Select-String "ms-vscode-remote.vscode-remote-extensionpack"
  if (!$isInstalledRemoteExt) {
    throw "VS Code に拡張 (ms-vscode-remote.vscode-remote-extensionpack) がインストールされていません"
  }
}

<#
.SYNOPSIS
    .env 環境変数読み込み
.PARAMETER Path
    .env ファイルパス
.DESCRIPTION
    指定された .env ファイルから環境変数を読み込み、PowerShell の環境変数として設定する。
#>
function Read-Env {
  param($Path = "..\.env")
  Write-Log ".env 環境変数読み込み..."
  if (!(Test-Path $Path)) {
    throw ".env が見つかりません"
  }

  Get-Content $Path | ForEach-Object {
    if ($_ -match "^\s*#") { return }
    if ($_ -match "^\s*$") { return }
    if ($_ -notmatch "=") { return }
    $key, $value = $_ -split "=", 2
    $key = $key.Trim()
    $value = $value.Trim().Trim("'").Trim('"')
    if ($key) {
      [System.Environment]::SetEnvironmentVariable($key, $value)
    }
  }
}

<#
.SYNOPSIS
    WSL インスタンス構築
.DESCRIPTION
    WSL インスタンスが存在しない場合、新しいインスタンスを作成する。
#>
function Import-WSLInstance {
  # $exists = wsl -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $env:WSL_INSTANCE_NAME }
  $wslList = wsl -l -q | Out-String
  $exists = $wslList -replace "`0", "" -split "`r`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and $_ -eq $env:WSL_INSTANCE_NAME }
  if ($exists) {
    return
  }
  if (!(Test-Path $env:WSL_INSTANCE_PATH)) {
    New-Item -ItemType Directory -Path $env:WSL_INSTANCE_PATH | Out-Null
  }
  Get-File $env:DISTRO_IMAGE_URL $env:DISTRO_IMAGE_PATH

  Write-Log "WSL インスタンス作成..."
  wsl --import $env:WSL_INSTANCE_NAME $env:WSL_INSTANCE_PATH $env:DISTRO_IMAGE_PATH
  if ($LASTEXITCODE -ne 0) {
    throw "WSL インスタンス作成失敗"
  }
  wsl --set-default $env:WSL_INSTANCE_NAME
  if ($LASTEXITCODE -ne 0) {
    throw "WSL インスタンス規定設定失敗"
  }
}

<#
.SYNOPSIS
    WSL インスタンスプロビジョニング実行 (./provision/provision.sh)
#>
function Invoke-ProvisionScript {
  Write-Log "WSL インスタンスプロビジョニング実行..."
  $scriptWslPath = Convert-ToWslPath (Join-Path $PSScriptRoot "provision/provision-wsl.sh")
  wsl -d $env:WSL_INSTANCE_NAME -u root -- bash "$scriptWslPath"
  if ($LASTEXITCODE -ne 0) {
    throw "WSL インスタンスプロビジョニング実行失敗"
  }
}

<#
.SYNOPSIS
    WSL インスタンス停止
.DESCRIPTION
    WSL インスタンスを停止する。
    設定変更後にインスタンスの状態をリセットするために使用する。
#>
function Stop-WSLInstance {
  Write-Log "WSL インスタンス停止... ( ${env:WSL_INSTANCE_NAME} )"
  wsl --terminate $env:WSL_INSTANCE_NAME
  if ($LASTEXITCODE -ne 0) {
    Write-Log " WSL インスタンス停止失敗。処理続行..." "WARN"
  }
}

<#
.SYNOPSIS
    VS Code リモートセッション起動
.DESCRIPTION
    VS Code を起動し、WSL インスタンスとのリモートセッションを開始する。
#>
function Start-VSCode {
  Write-Log "VS Code起動..."
  $targetWorkspace = "/home/$($env:WSL_USER_NAME)/$($env:GIT_REPO_NAME)/project.code-workspace"
  code --remote wsl+$($env:WSL_INSTANCE_NAME) $targetWorkspace
}

# メイン処理
try {
  Write-Log "セットアップ開始..."

  Set-Location $PSScriptRoot
  Read-Env
  Test-SystemRequirements
  Import-WSLInstance
  Invoke-ProvisionScript
  Stop-WSLInstance
  Start-VSCode

  Write-Log "セットアップ完了"
} catch {
  Write-Log $_.Exception.Message "ERROR"
  exit 1
}
