#!/bin/zsh
# Ranges game: create /Users/grace/cpp/compete/<YYYY-MM-DD>-<unix-seconds>-ranges with the next
# unsolved C++ ranges/views challenge as main.cpp, open it in nvim in a new tmux session, switch to it.
# In the session: prefix+T = compile & test, prefix+G = Rust iterator hint.

source /Users/grace/cpp/compete/.game/bin/common.sh
name="$(date +%Y-%m-%d)-$(date +%s)-ranges"
dir="$COMPETE/$name"

# Next unsolved challenge, in order. Once all are solved, a random one for review.
all=("$GAME"/challenges/*(/:t))
solved=(${(f)"$(cat "$GAME/solved" 2>/dev/null)"})
todo=(${all:|solved})
if (( ${#todo} )); then challenge=${todo[1]}
else challenge=${all[RANDOM % ${#all} + 1]}; fi

mkdir -p "$dir"
if [[ ! -f "$dir/main.cpp" ]]; then
  cp "$GAME/challenges/$challenge/starter.cpp" "$dir/main.cpp"
  print -r -- "$challenge" > "$dir/.challenge"
  # clangd: C++23 against GCC's libstdc++ (Apple libc++ lacks enumerate/chunk/slide/...).
  {
    print -- "-std=c++23"
    print -- "-nostdinc++"
    print -- "-I$GAME"
    $CXX -std=c++23 -E -x c++ -v /dev/null 2>&1 \
      | sed -n '/#include <...>/,/End of search/p' | grep '^ ' | grep 'c++' \
      | sed 's/^ */-isystem/'
  } > "$dir/compile_flags.txt"
fi

if ! tmux has-session -t "=$name" 2>/dev/null; then
  tmux new-session -d -s "$name" -c "$dir" "nvim main.cpp; exec zsh"
fi
tmux switch-client -t "=$name"
tmux display-message "ranges game: $challenge  (prefix+T test, prefix+G Rust hint)"
