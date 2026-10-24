#!/bin/zsh
# 組み立てたデータ（data/ と site/fonts.json）を非公開リポジトリ swwwitch/fontdb-data に写してコミット・プッシュする。
# macos-apps は公開なので、各社の説明文などを含むデータはこちらには入れない（.gitignore）。
set -euo pipefail
root="${0:A:h:h}"
dest="$HOME/Git/fontdb-data"
if [[ ! -d "$dest/.git" ]]; then
  gh repo clone swwwitch/fontdb-data "$dest"
fi
rsync -a --delete --exclude '.git' --exclude 'README.md' "$root/data/" "$dest/data/"
mkdir -p "$dest/site"
cp "$root/site/fonts.json" "$dest/site/fonts.json"
cd "$dest"
git add -A
if git diff --cached --quiet; then
  echo "変更なし"
  exit 0
fi
git commit -q -m "FontDB のデータを更新（$(date +%Y-%m-%d)）"
git push -q origin HEAD
git log --oneline -1
