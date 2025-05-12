
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM =====================================
REM Portable Git セットアップ BAT ファイル（ps1代替）
REM =====================================

SET GIT_VERSION=2.44.0
SET ARCH=64-bit
SET FILENAME=PortableGit-%GIT_VERSION%-%ARCH%.7z.exe
SET BASE_URL=https://github.com/git-for-windows/git/releases/download/v%GIT_VERSION%.windows.1
SET DOWNLOAD_URL=%BASE_URL%/%FILENAME%
SET DOWNLOAD_PATH=%TEMP%\%FILENAME%
SET INSTALL_DIR=%USERPROFILE%\Tools\PortableGit
SET GIT_EXE=%INSTALL_DIR%\cmd\git.exe
SET CMD_DIR=%USERPROFILE%\bin
SET CMD_PATH=%CMD_DIR%\git.cmd

echo 🔍 Gitの存在を確認中...
IF EXIST "%GIT_EXE%" (
    echo ✅ 既にGitが存在します: %GIT_EXE%
) ELSE (
    echo ⬇️ Gitをダウンロードしています...
    powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%DOWNLOAD_PATH%'" || (
        echo ❌ ダウンロードに失敗しました。
        EXIT /B 1
    )

    echo 📦 Gitを展開しています...
    "%DOWNLOAD_PATH%" -o"%INSTALL_DIR%" -y >nul
    IF EXIST "%GIT_EXE%" (
        echo ✅ Gitを展開しました: %INSTALL_DIR%
    ) ELSE (
        echo ❌ 展開に失敗しました。Gitの実行ファイルが見つかりません。
        EXIT /B 1
    )
)

echo 🛠️ git.cmd を作成中...
IF NOT EXIST "%CMD_DIR%" (
    mkdir "%CMD_DIR%"
)
(
    echo @echo off
    echo "%GIT_EXE%" %%*
) > "%CMD_PATH%"
echo ✅ git.cmd を作成しました: %CMD_PATH%

echo 🔧 PATH に %CMD_DIR% を追加中（ユーザー環境変数）...
FOR /F "tokens=2*" %%A IN ('reg query "HKCU\Environment" /v PATH 2^>nul') DO (
    SET "OLD_PATH=%%B"
)
echo !OLD_PATH! | find /I "%CMD_DIR%" >nul
IF ERRORLEVEL 1 (
    setx PATH "!OLD_PATH!;%CMD_DIR%" >nul
    echo ✅ PATH を追加しました。
) ELSE (
    echo ✅ 既に PATH に含まれています。
)

echo.
echo 🎉 セットアップ完了しました。
echo - git --version を確認するには、ターミナルを再起動してください。
echo - VSCode のターミナルや PowerShell から git が使えるようになります。

PAUSE
