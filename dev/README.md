## Testing

A quick test that covers most features (<3 min. runtime).
```bash
./test.sh test_quick
```

Tests run by CI. You should run this before making a Pull Request.
```bash
./test.sh test_ci
```

Test all features.
```bash
./test.sh test_all
```

## Fetching a new Zig release

This updates [`../zig-release.nix`](../zig-release.nix).
```bash
./update.sh
```

Don't make any persistent changes.
```bash
./update.sh --dry-run|-n
```

## Maintaining this repo

1. Get commit rights for https://github.com/erikarvstedt/nix-zig-build and add remote `upstream`:
   ```bash
   git remote add upstream git@github.com:erikarvstedt/nix-zig-build.git
   ```
   Also, always GPG-sign commits:
   ```bash
   git config commit.gpgsign true
   ```

2. Regularly run the update script to update `../zig-release.nix` and push it to upstream:
   ```bash
   ./update.sh --push
   ```
   You can also add a NixOS service to auto run the update daily.\
   Make sure to check and edit all locations marked by `FIXME:`.
   ```nix
   systemd.services.update-nix-zig-build = {
     serviceConfig = {
       User = "<FIXME: The unprivileged system user that should run `update.sh`>";
       ExecStart = ''
         ${pkgs.bash}/bin/bash -c \
           'source ${config.system.build.setEnvironment}; exec <FIXME: Path to the nix-zig-build repo>/dev/update.sh --push'
       '';
     };
     startAt = "*-*-* 16:00:00";
   };
   ```
