# Playing on Steam Machine

`launch.sh` checks GitHub for a newer release each time the game starts,
downloads it if there is one, then runs the game. After the one-off setup
below, updates arrive in Game Mode without touching Desktop Mode.

## One-off setup (Desktop Mode)

1. Open Konsole and run:

   ```sh
   mkdir -p ~/Games/Scuttle && cd ~/Games/Scuttle
   curl -fsSLO https://raw.githubusercontent.com/Teeohbee/scuttle/main/steam-machine/launch.sh
   chmod +x launch.sh
   ```

2. In Steam: Games > Add a Non-Steam Game to My Library > Browse. Set the
   file filter to "All Files", pick `~/Games/Scuttle/launch.sh`, then
   rename the shortcut to "Scuttle".
3. Return to Game Mode and launch it. The first launch needs internet to
   fetch the game.

## Shipping an update

Push a version tag. The `Linux build` workflow exports the game and attaches
it to a GitHub Release:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

The next launch on the Steam Machine picks it up. Offline launches run the last
downloaded build.
