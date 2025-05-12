# PowerShell スクリプト：Portable Git 環境構築（日本語・エラー詳細付き）
$ErrorActionPreference = "Stop"

$gitVersion = "2.44.0"
$arch = "64-bit"
$filename = "PortableGit-$gitVersion-$arch.7z.exe"
$baseUrl = "https://github.com/git-for-windows/git/releases/download/v$gitVersion.windows.1"
$downloadUrl = "$baseUrl/$filename"
$downloadPath = "$env:TEMP\$filename"
$installDir = "$env:USERPROFILE\Tools\PortableGit"
$gitExePath = "$installDir\cmd\git.exe"
$cmdDir = "$env:USERPROFILE\bin"
$cmdPath = "$cmdDir\git.cmd"
$startupScriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\startup-git-restore.bat"
$settingsPath = "$env:APPDATA\Code\User\settings.json"
$profilePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"

# Step 1: Git をダウンロード＆展開（既存チェック）
if (-not (Test-Path $gitExePath)) {
    Write-Host "⬇️ Portable Git をダウンロード中: $downloadUrl"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -ErrorAction Stop
    } catch {
        Write-Host "❌ ダウンロード失敗: $_"
        exit 1
    }

    Write-Host "📦 展開しています..."
    try {
        & $downloadPath -o"$installDir" -y | Out-Null
    } catch {
        Write-Host "❌ 展開時エラー: $_"
        exit 1
    }

    if (-not (Test-Path $gitExePath)) {
        throw "❌ Git の展開後に git.exe が見つかりませんでした: $gitExePath"
    }
    Write-Host "✅ Git を展開しました: $installDir"
} else {
    Write-Host "✅ Git は既に存在します: $gitExePath"
}

# Step 2: git.cmd を作成（CMD用ラッパー）
if (-not (Test-Path $cmdDir)) {
    try {
        New-Item -ItemType Directory -Path $cmdDir | Out-Null
        Write-Host "📁 作成: $cmdDir"
    } catch {
        Write-Host "❌ bin ディレクトリ作成失敗: $_"
        exit 1
    }
}

try {
    "@echo off`r`n""$gitExePath"" %*" | Set-Content -Path $cmdPath -Encoding ascii
    Write-Host "✅ git.cmd を作成しました: $cmdPath"
} catch {
    Write-Host "❌ git.cmd 作成失敗: $_"
}

# Step 3: PowerShell のプロファイルに alias を追加（冪等）
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "📄 PowerShell プロファイルを新規作成: $profilePath"
}
$content = Get-Content $profilePath -Raw
if ($content -notmatch 'Set-Alias git') {
    Add-Content $profilePath "`nSet-Alias git `"$gitExePath`""
    Write-Host "✅ PowerShell エイリアス 'git' を設定しました"
} else {
    Write-Host "⚠️ 既に Set-Alias git が登録されています"
}

# Step 4: VSCode 設定ファイルに git.path を設定（冪等）
if (-not (Test-Path $settingsPath)) {
    '{}' | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Host "📄 VSCode settings.json を新規作成"
}
try {
    $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $json.'git.path' = $gitExePath
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Host "✅ VSCode の git.path を設定しました"
} catch {
    Write-Host "❌ VSCode 設定更新失敗: $_"
}

# Step 5: 起動時に Git 環境を復元するスクリプトを作成
$startupScriptContent = @"
@echo off
set "GIT_EXE=%USERPROFILE%\Tools\PortableGit\cmd\git.exe"
set "CMD_PATH=%USERPROFILE%\bin\git.cmd"
if not exist "%USERPROFILE%\bin" mkdir "%USERPROFILE%\bin"
(
    echo @echo off
    echo "%GIT_EXE%" %%*
) > "%CMD_PATH%"
set "PATH=%USERPROFILE%\bin;%PATH%"
set "PROFILE=%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if not exist "%PROFILE%" (
    mkdir "%USERPROFILE%\Documents\WindowsPowerShell" >nul 2>&1
    type nul > "%PROFILE%"
)
findstr /C:"Set-Alias git" "%PROFILE%" >nul 2>&1
if errorlevel 1 (
    echo Set-Alias git "%GIT_EXE%" >> "%PROFILE%"
)
"@
try {
    $startupScriptContent | Set-Content -Path $startupScriptPath -Encoding ASCII
    Write-Host "✅ スタートアップスクリプトを作成しました: $startupScriptPath"
} catch {
    Write-Host "❌ スタートアップスクリプト作成に失敗しました: $_"
}
# Step 6: Git インストール確認
Write-Host "`n🔍 Git のインストールを確認しています..."
try {
    $versionOutput = & "$gitExePath" --version
    Write-Host "✅ Git のバージョン: $versionOutput"
} catch {
    Write-Host "❌ Git の実行に失敗しました。git.exe のパスまたは展開に問題がある可能性があります。詳細: $_"
}

# Step 7: Git ユーザー情報を設定
$gitUserName = "Your Name Here"         # 必要に応じて修正
$gitUserEmail = "your.email@example.com" # 必要に応じて修正

Write-Host "`n👤 Git のユーザー名とメールアドレスを設定中..."
try {
    & "$gitExePath" config --global user.name "$gitUserName"
    & "$gitExePath" config --global user.email "$gitUserEmail"
    $configuredName = & "$gitExePath" config --global user.name
    $configuredEmail = & "$gitExePath" config --global user.email
    Write-Host "✅ user.name 設定済み: $configuredName"
    Write-Host "✅ user.email 設定済み: $configuredEmail"
} catch {
    Write-Host "❌ Git ユーザー情報の設定に失敗しました: $_"
}

# Step 8: .gitconfig を直接編集（冪等・おすすめ設定を追加）
$gitconfigPath = "$env:USERPROFILE\.gitconfig"
Write-Host "`n⚙️ .gitconfig におすすめの設定を反映します..."

if (-not (Test-Path $gitconfigPath)) {
    Write-Host "📄 .gitconfig が存在しないため、新規作成します。"
    @"
[user]
    name = $gitUserName
    email = $gitUserEmail

[core]
    autocrlf = true
    editor = code --wait

[init]
    defaultBranch = main

[color]
    ui = auto

[credential]
    helper = manager-core
"@ | Set-Content -Path $gitconfigPath -Encoding UTF8
    Write-Host "✅ .gitconfig を新規作成しました: $gitconfigPath"
} else {
    Write-Host "📄 .gitconfig を更新中（冪等）..."
    try {
        $configText = Get-Content $gitconfigPath -Raw
        $replacements = @{
            'name\s*=.*' = "name = $gitUserName"
            'email\s*=.*' = "email = $gitUserEmail"
            'autocrlf\s*=.*' = "autocrlf = true"
            'editor\s*=.*' = "editor = code --wait"
            'defaultBranch\s*=.*' = "defaultBranch = main"
            'ui\s*=.*' = "ui = auto"
            'helper\s*=.*' = "helper = manager-core"
        }

        foreach ($pattern in $replacements.Keys) {
            $replacement = $replacements[$pattern]
            if ($configText -match $pattern) {
                $configText = [regex]::Replace($configText, $pattern, $replacement)
            }
        }

        $configText | Set-Content -Path $gitconfigPath -Encoding UTF8
        Write-Host "✅ .gitconfig を更新しました（冪等処理）"
    } catch {
        Write-Host "❌ .gitconfig の編集に失敗しました: $_"
    }
}

# Step 9: VSCode の PATH を追加（code.exe 利用のため）
$codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
Write-Host "`n📎 VSCode の code コマンドが PATH にあるか確認しています..."
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($userPath -split ";" | Where-Object { $_ -eq $codePath })) {
        setx PATH "$userPath;$codePath" > $null
        Write-Host "✅ PATH に VSCode (code.exe) を追加しました → $codePath"
    } else {
        Write-Host "✅ code.exe はすでに PATH に含まれています"
    }
} catch {
    Write-Host "❌ PATH への追加に失敗しました: $_"
}

# Step 10: SSH鍵の作成（ed25519）
$sshDir = "$env:USERPROFILE\.ssh"
$privateKeyPath = "$sshDir\id_ed25519"
$publicKeyPath = "$privateKeyPath.pub"
$sshExe = "$installDir\usr\bin\ssh-keygen.exe"

Write-Host "`n🔐 SSH 鍵 (ed25519) を確認しています..."
if (-not (Test-Path $privateKeyPath)) {
    try {
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir | Out-Null
        }
        & "$sshExe" -t ed25519 -f "$privateKeyPath" -N "" -q
        Write-Host "✅ SSH鍵を生成しました → $privateKeyPath"
    } catch {
        Write-Host "❌ SSH鍵の生成に失敗しました: $_"
    }
} else {
    Write-Host "✅ 既にSSH鍵が存在します → $privateKeyPath"
}

# Step 11: SSH config の作成（GitLab）
$sshConfigPath = "$sshDir\config"
$sshConfigBlock = @"
Host gitlab
  HostName gitlab.lifecorp-app.com
  User git
  IdentityFile $privateKeyPath
"@

if (-not (Test-Path $sshConfigPath)) {
    $sshConfigBlock | Set-Content -Path $sshConfigPath -Encoding UTF8
    Write-Host "✅ SSH config ファイルを新規作成 → $sshConfigPath"
} else {
    $configText = Get-Content $sshConfigPath -Raw
    if ($configText -notmatch "Host gitlab") {
        Add-Content -Path $sshConfigPath -Value "`r`n$sshConfigBlock"
        Write-Host "✅ SSH config に GitLab の設定を追加しました"
    } else {
        Write-Host "⚠️ SSH config には既に GitLab の設定があります"
    }
}

# Step 12: 公開鍵をクリップボードにコピーして GitLab に案内
if (Test-Path $publicKeyPath) {
    try {
        Get-Content $publicKeyPath | Set-Clipboard
        Write-Host "`n📋 公開鍵をクリップボードにコピーしました。以下の手順で GitLab に登録してください："
        Write-Host "1. ブラウザで https://gitlab.lifecorp-app.com を開く"
        Write-Host "2. プロフィール → Settings → SSH Keys を開く"
        Write-Host "3. 『New SSH Key』に貼り付けて登録"
    } catch {
        Write-Host "❌ 公開鍵のクリップボードコピーに失敗しました: $_"
    }
} else {
    Write-Host "❌ 公開鍵が存在しません → $publicKeyPath"
}
