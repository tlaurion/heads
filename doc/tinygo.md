# TinyGo u-root Build Integration

Heads can build u-root initramfs binaries with TinyGo instead of the standard Go
compiler, producing significantly smaller binaries (10-30% of Go size).

## Repositories

All patches are committed in-tree on tlaurion forks — no out-of-band patching.

| Fork | Branch | Patches |
|------|--------|--------|
| [tlaurion/u-root](https://github.com/tlaurion/u-root) | `main` | gobusybox `GO111MODULE=auto` for TinyGo, pure-Go stubs (cpuid, memio, UPP, trampoline), `tinygo.enable` build constraints |
| [tlaurion/tinygo](https://github.com/tlaurion/tinygo) | `main` | `os/file_unix_chown.go` (File.Chown), `sync/waitgroup.go` (WaitGroup.Go), `crypto/tls/tls.go` (Conn alias, Listen stub) |
| [tlaurion/net](https://github.com/tlaurion/net) | `main` | net/tcp/udp/tls missing methods, http/transport RoundTrip fix, TLSClientConfig |

The `tools/tinygo_patches/` directory was removed from u-root — those patch files are
superseded by the direct fork commits.

## How it works

The `nix develop` shell provides `tinygo-patched` (built from `tlaurion/tinygo` via
`flake.nix`). When `UROOT_COMPILER=tinygo` is set in the board config, the build:

1. Clones `https://github.com/tlaurion/u-root` (or uses local checkout via `UROOT_LOCAL`)
2. Runs `u-root -build=bb -compiler tinygo ...` which invokes gobusybox
3. gobusybox uses `go list` for package discovery (standard Go), then invokes `tinygo build`
   for actual compilation (confirmed via `GBBDEBUG=1` logs)

```
GBB Go invocation: ... /nix/store/...-tinygo-0.42.0-dev/bin/tinygo []string{"build", ...}
```

## Build Environment

- `nix develop --command make BOARD=qemu-coreboot-fbwhiptail-tpm2-linuxboot`
  builds the full Heads ROM with u-root + Heads initramfs (gui-init.sh as uinit).

- `nix develop --command make BOARD=qemu-coreboot-fbwhiptail-tpm2-linuxboot_u-root_only`
  builds u-root only (no Heads initramfs, `gosh` as default shell, PID 1).

Both boards build all u-root commands: `core/* boot/* exp/* cluster/* contrib/* fwtools/*`
(~188 commands total).

## Interp Timeout

TinyGo's LLVM interp pass evaluates ALL package init code (globals, init functions,
bbmain.Register calls) at compile time by running LLVM IR. This is single-threaded.

With 188 commands in bb mode, this generates ~62k calls exceeding TinyGo's default
3-minute interp timeout. The timeout triggers on whichever command registers last in
bb processing order — it's not a specific command bug, just volume.

Fixed via `-go-extra-args="-interp-timeout=10m"` passed to the u-root command
(see `modules/u-root`). Measured on a 22-core system; adjust for fewer cores or
more commands.

## Version Compatibility

The tlaurion/tinygo fork reports version `0.42.0-dev` (based on upstream dev branch).
The nix package version matches: `0.42.0-dev`. Pinned via `flake.lock`.

## Boot Behavior

- **Full board** (`CONFIG_HEADS=y`): u-root init runs `gui-init.sh` via `UROOT_UINIT`.
- **U-root only** (`CONFIG_HEADS=n`): u-root init falls through to `/bin/defaultsh`
  which is symlinked to `gosh` (Go shell from `cmds/core/gosh`).

## Testing in QEMU

```bash
# Build
nix develop --command make BOARD=qemu-coreboot-fbwhiptail-tpm2-linuxboot_u-root_only

# Run (from inside nix develop or docker)
make BOARD=qemu-coreboot-fbwhiptail-tpm2-linuxboot_u-root_only run
```

## Perl Locale Warnings

Perl locale warnings (`Setting locale failed`) are suppressed by setting
`LANG=C.UTF-8` and `LANGUAGE=C` in the devShell (see `flake.nix`).
