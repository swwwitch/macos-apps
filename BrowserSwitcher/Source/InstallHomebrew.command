#!/bin/bash
# Official Homebrew installer, run interactively in Terminal.
printf '%s\n' 'Homebrewをインストールします。確認とパスワード入力はこのターミナルで行ってください。'
installer=$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
result=$?
if [ "$result" -eq 0 ]; then
    /bin/bash -c "$installer"
    result=$?
fi
if [ "$result" -eq 0 ]; then
    printf '\n%s\n' '完了しました。ブラウザー切り換えの環境設定で「再確認」を押してください。'
else
    printf '\n%s\n' "インストールは完了していません（終了コード：$result）。上のメッセージを確認してください。"
fi
printf '\n%s' 'Returnキーで終了します。'
read -r
exit "$result"
