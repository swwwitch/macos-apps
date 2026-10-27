#!/bin/zsh
# Latest Builds の .app を /Applications へ入れる・更新する
# - 未インストール、または Latest Builds の方が新しいものだけ対象（version → build の順で比較）
# - /Applications 側は Bundle ID で探す（改名前の名前で入っていても置き換える）
# - 起動中のアプリは終了して入れ替え、起動し直す
# - 対象一覧を表示して自動実行する
# - 最後に /Applications/swApps に /Applications の自作アプリへのシンボリックリンクを作り直す

emulate -L zsh
setopt null_glob

SRC_DIR="${0:A:h}"
DEST_DIR="/Applications"
LINK_DIR="/Applications/swApps"
PB=/usr/libexec/PlistBuddy

plist_value() { $PB -c "Print $2" "$1/Contents/Info.plist" 2>/dev/null }

# a > b なら 0 を返す（ドット区切りの数値比較）
version_gt() {
  local -a a b
  a=("${(@s:.:)1}"); b=("${(@s:.:)2}")
  local i n=$(( ${#a} > ${#b} ? ${#a} : ${#b} ))
  for (( i = 1; i <= n; i++ )); do
    local x=${a[i]:-0} y=${b[i]:-0}
    x=${x//[^0-9]/}; y=${y//[^0-9]/}
    (( ${x:-0} > ${y:-0} )) && return 0
    (( ${x:-0} < ${y:-0} )) && return 1
  done
  return 1
}

# version → build の順で比較して src の方が新しければ 0
is_newer() {
  version_gt "$1" "$3" && return 0
  version_gt "$3" "$1" && return 1
  version_gt "$2" "$4"
}

# /Applications 直下で Bundle ID が一致する .app を探す
find_installed() {
  local bid=$1 app
  for app in "$DEST_DIR"/*.app; do
    [[ "$(plist_value "$app" CFBundleIdentifier)" == "$bid" ]] && { print -r -- "$app"; return 0 }
  done
  return 1
}

running_pids() { pgrep -f "^$1/Contents/MacOS/" }

# ⌘Q と同じ通常の終了を依頼する（未保存の書類を失わないよう強制終了はしない）
# 10秒以内に終わらなければ 1 を返す
quit_app() {
  local app=$1 i bid
  running_pids "$app" >/dev/null || return 0
  bid=$(plist_value "$app" CFBundleIdentifier)
  osascript -l JavaScript -e "ObjC.import('AppKit');
    var a = \$.NSRunningApplication.runningApplicationsWithBundleIdentifier('$bid');
    for (var i = 0; i < a.count; i++) a.objectAtIndex(i).terminate;" >/dev/null 2>&1
  for (( i = 0; i < 100; i++ )); do
    running_pids "$app" >/dev/null || { sleep 0.3; return 0 }
    sleep 0.1
  done
  return 1
}

# LINK_DIR のシンボリックリンクを作り直す（リンク以外のファイルには触れない）
refresh_links() {
  local src bid app link
  mkdir -p "$LINK_DIR" || return 1
  for link in "$LINK_DIR"/*; do
    [[ -L "$link" ]] && rm "$link"
  done
  for src in "$SRC_DIR"/*.app; do
    bid=$(plist_value "$src" CFBundleIdentifier)
    [[ -n "$bid" ]] || continue
    app=$(find_installed "$bid") || continue
    ln -s "$app" "$LINK_DIR/${app:t}"
  done
  print "リンクを更新: $LINK_DIR（$(ls "$LINK_DIR" | wc -l | tr -d ' ') 本）"
}

# このスクリプトを実行中のウインドウを閉じ、他にウインドウが無ければターミナルを終了する
# （シェルの終了後に閉じるので「プロセスを終了しますか？」は出ない）
close_terminal() {
  local my_tty=$(tty) win_id
  win_id=$(osascript -e "tell application \"Terminal\"
    repeat with w in windows
      repeat with t in tabs of w
        if tty of t is \"$my_tty\" then return id of w
      end repeat
    end repeat
  end tell" 2>/dev/null)
  [[ -n "$win_id" ]] || return
  nohup osascript -e "delay 0.5
    tell application \"Terminal\"
      close (every window whose id is $win_id)
      if (count windows) is 0 then quit
    end tell" >/dev/null 2>&1 &!
}

finish() {
  print
  refresh_links
  close_terminal
  exit 0
}

print "Latest Builds: $SRC_DIR"
print "インストール先: $DEST_DIR"
print

typeset -a plan_src plan_old plan_label
typeset -a skipped

for src in "$SRC_DIR"/*.app; do
  name=${src:t}
  bid=$(plist_value "$src" CFBundleIdentifier)
  ver=$(plist_value "$src" CFBundleShortVersionString)
  bld=$(plist_value "$src" CFBundleVersion)
  if [[ -z "$bid" ]]; then
    skipped+=("$name（Info.plist を読めない。Dropbox のダウンロード待ちかも）")
    continue
  fi

  old=$(find_installed "$bid")
  if [[ -z "$old" ]]; then
    plan_src+=("$src"); plan_old+=(""); plan_label+=("新規  $name  $ver ($bld)")
    continue
  fi

  over=$(plist_value "$old" CFBundleShortVersionString)
  obld=$(plist_value "$old" CFBundleVersion)
  if is_newer "$ver" "$bld" "$over" "$obld"; then
    label="更新  $name  $over ($obld) → $ver ($bld)"
    [[ "${old:t}" != "$name" ]] && label+="  ※ ${old:t} を置き換え"
    plan_src+=("$src"); plan_old+=("$old"); plan_label+=("$label")
  elif is_newer "$over" "$obld" "$ver" "$bld"; then
    skipped+=("$name（/Applications の方が新しい: $over ($obld)）")
  fi
done

if (( ${#skipped} )); then
  print "スキップ:"
  for s in $skipped; do print "  $s"; done
  print
fi

if (( ${#plan_src} == 0 )); then
  print "すべて最新です。"
  finish
fi

print "次の ${#plan_src} 本を入れます:"
for l in $plan_label; do print "  $l"; done
print
print "更新を自動実行します（起動中のアプリは終了して入れ替え、起動し直します）。"
print; print

typeset -i ok=0 ng=0
for (( i = 1; i <= ${#plan_src}; i++ )); do
  src=${plan_src[i]}; old=${plan_old[i]}
  name=${src:t}; dest="$DEST_DIR/$name"
  tmp="$DEST_DIR/.$name.installing"
  print -n "$name … "

  # Dropbox のオンラインのみのファイルを実体化させる
  if ! find "$src" -type f -exec cat {} + >/dev/null 2>&1; then
    print "失敗（読み込めないファイルがある）"; (( ng++ )); continue
  fi

  rm -rf "$tmp"
  if ! ditto "$src" "$tmp"; then
    rm -rf "$tmp"; print "失敗（コピー）"; (( ng++ )); continue
  fi
  xattr -dr com.apple.quarantine "$tmp" 2>/dev/null

  # コピー中に起動したアプリも含め、置換直前に終了させる
  was_running=0
  for target in "$old" "$dest"; do
    [[ -n "$target" && -d "$target" ]] || continue
    running_pids "$target" >/dev/null || continue
    was_running=1
    if ! quit_app "$target"; then
      rm -rf "$tmp"; print "スキップ（終了しなかった。未保存の書類などを確認）"; (( ng++ )); continue 2
    fi
  done

  [[ -n "$old" && "$old" != "$dest" ]] && rm -rf "$old"
  rm -rf "$dest"
  if ! mv "$tmp" "$dest"; then
    rm -rf "$tmp"; print "失敗（配置）"; (( ng++ )); continue
  fi

  if (( was_running )); then
    open "$dest" && print "完了（起動し直しました）" || print "完了（起動し直せませんでした）"
  else
    print "完了"
  fi
  (( ok++ ))
done

print
print "完了 $ok 本"
(( ng )) && print "失敗 $ng 本"
finish
