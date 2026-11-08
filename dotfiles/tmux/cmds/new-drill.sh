#!/bin/zsh
# Blitz drill: create /Users/grace/cpp/compete/<YYYY-MM-DD>-<unix-seconds>-drill with one 30s
# muscle-memory drill (concepts from ~/cpp/review/main.cpp), open nvim in insert mode at the answer
# line, and start the countdown. prefix+T = done early; at 0 it saves and grades by itself.
source /Users/grace/cpp/compete/.game/bin/common.sh
IFS=$'\t' read -r drill secs < <("$GAME/bin/drill.py" pick) || exit 1
name="$(date +%Y-%m-%d)-$(date +%s)-drill"
dir="$COMPETE/$name"

mkdir -p "$dir"
cp "$GAME/drills/$drill/starter.cpp" "$dir/main.cpp"
print -r -- "$drill" > "$dir/.drill"
write_compile_flags "$dir"
line=$(( $(grep -n '>>> YOUR CODE' "$dir/main.cpp" | cut -d: -f1) + 1 ))

tmux new-session -d -s "$name" -c "$dir" "nvim '+call cursor($line, 1)' '+startinsert!' main.cpp; exec zsh"
tmux switch-client -t "=$name"
date +%s > "$dir/.start"
nohup "$GAME/bin/drill-timer.sh" "$name" "$dir" "$secs" </dev/null >/dev/null 2>&1 &!
tmux display-message "blitz: $drill  ${secs}s -- go!  (prefix+T = done)"
