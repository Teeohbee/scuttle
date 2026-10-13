#!/usr/bin/env bash
# Steam Machine launcher: grabs the newest GitHub Release if there is one, then
# starts the game. Add this script to Steam as a non-Steam game. Offline or
# if GitHub is unreachable, it just runs whatever build is already here.
set -u

repo="Teeohbee/scuttle"
binary="Scuttle.x86_64"
dir="$(cd "$(dirname "$0")" && pwd)"
cd "$dir"

# /releases/latest redirects to /releases/tag/<tag>, which avoids the API and jq
latest="$(curl -fsS --max-time 5 -o /dev/null -w '%{redirect_url}' \
	"https://github.com/$repo/releases/latest" | sed 's|.*/tag/||')"
current="$(cat version 2>/dev/null)"

if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
	echo "Updating ${current:-nothing} -> $latest"
	if curl -fsSL --max-time 300 -o "$binary.download" \
		"https://github.com/$repo/releases/download/$latest/$binary"; then
		chmod +x "$binary.download"
		mv "$binary.download" "$binary"
		echo "$latest" > version
	else
		echo "Download failed, keeping ${current:-no} build"
		rm -f "$binary.download"
	fi
fi

if [ ! -x "$binary" ]; then
	echo "No build yet - connect to the internet and try again" >&2
	exit 1
fi

exec "./$binary" "$@"
