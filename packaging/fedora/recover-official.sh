#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
dnf_log_dir="$work_dir/dnf-log"
features_backup="$work_dir/recovery-features-before.txt"
packages=()

mkdir -p "$dnf_log_dir"
gsettings get org.gnome.mutter experimental-features >"$features_backup"
mapfile -t packages < <(
    rpm -qa --qf '%{NAME}\n' 'mutter*' 'gnome-shell*' | sort -u
)
if [[ ${#packages[@]} -eq 0 ]]; then
    printf 'No installed Mutter or GNOME Shell packages were found.\n' >&2
    exit 1
fi

sudo dnf5 --refresh --setopt="logdir=$dnf_log_dir" distro-sync \
    "${packages[@]}"

current_features=$(gsettings get org.gnome.mutter experimental-features)
if [[ "$current_features" == *"'window-appearance'"* ]]; then
    official_features=$(sed -E \
        "s/'window-appearance',[[:space:]]*//; s/,[[:space:]]*'window-appearance'//; s/'window-appearance'//" \
        <<<"$current_features")
    if [[ "$official_features" == '[]' ]]; then
        official_features='@as []'
    fi
    gsettings set org.gnome.mutter experimental-features "$official_features"
fi

if rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' 'mutter*' |
   rg -q '\.gwa[[:alnum:]]*\.'; then
    printf 'A local patched Mutter package remains after distro-sync.\n' >&2
    exit 1
fi

printf 'Synchronized installed GNOME Shell and Mutter packages to Fedora repositories.\n'
printf 'Previous feature list: %s\n' "$features_backup"
printf 'Reboot before starting another graphical session, then rebuild the patch.\n'
