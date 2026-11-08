#!/bin/zsh
# Create /Users/grace/cpp/compete/<YYYY-MM-DD>-<unix-seconds>-compete with a main.cpp, open it
# in nvim in a new tmux session, and switch the current client to it.

base=/Users/grace/cpp/compete
name="$(date +%Y-%m-%d)-$(date +%s)-compete"
dir="$base/$name"

mkdir -p "$dir"
if [[ ! -f "$dir/main.cpp" ]]; then
  cat > "$dir/main.cpp" <<'CPP'
int main() {
    return 0;
}
CPP
fi

if ! tmux has-session -t "=$name" 2>/dev/null; then
  tmux new-session -d -s "$name" -c "$dir" "nvim main.cpp; exec zsh"
fi
tmux switch-client -t "=$name"
source /Users/grace/cpp/compete/.game/bin/common.sh
touch "$dir/.compete"
date +%s > "$dir/.start"
nohup "$GAME/bin/compete-timer.sh" "$name" "$dir" "$COMPETE_SECS" </dev/null >/dev/null 2>&1 &!
tmux display-message "compete: ${COMPETE_SECS}s -- go!  (prefix+T = compile & run)"
