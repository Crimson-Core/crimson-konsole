#!/bin/sh
echo -ne '\033c\033]0;Crimson Konsole\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Crimson Konsole.x86_64" "$@"
