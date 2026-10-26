# Playing on a Steam Machine or Steam Deck

Installed and kept up to date by [steam-tools](https://github.com/Teeohbee/steam-tools). `game.conf` tells its launcher which GitHub Releases to fetch, and `art/` is the Steam library art. (`.gdignore` keeps Godot from importing that art into the game.)

## Installing, or refreshing the art

From a Mac with SSH access to the device:

```sh
~/Projects/steam-tools/steam-install steammachine.local ~/Projects/scuttle
```

## Shipping an update

Push a version tag. The `Linux build` workflow exports the game and attaches it to a GitHub Release:

```sh
git tag v0.3.0 && git push origin v0.3.0
```

The next launch on the device picks it up. Offline launches run the last downloaded build.
