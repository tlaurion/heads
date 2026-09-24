# Heads modules (tools included in the initrd)

Tools available in the Heads initrd are defined by `CONFIG_*` flags in board configs
(`boards/*/*.config`) and compiled by the top-level `Makefile`. Each `bin_modules-$(CONFIG_*) += <name>`
line adds a package to `tools.cpio` (one of six CPIO archives assembled into the initrd).

Not all tools are BusyBox applets — many are standalone binaries compiled as separate packages.

## Module list (from the `bin_modules-$(CONFIG_* )` block in the Makefile)

| Config flag | Package | Type |
|---|---|---|
| `CONFIG_KEXEC` | kexec | Standalone |
| `CONFIG_TPMTOTP` | tpmtotp | Standalone |
| `CONFIG_PCIUTILS` | pciutils | Standalone |
| `CONFIG_FLASHROM` | flashrom | Standalone |
| `CONFIG_FLASHPROG` | flashprog | Standalone |
| `CONFIG_CRYPTSETUP` | cryptsetup | Standalone |
| `CONFIG_CRYPTSETUP2` | cryptsetup2 | Standalone |
| `CONFIG_GPG` | gpg | Standalone |
| `CONFIG_GPG2` | gpg2 | Standalone |
| `CONFIG_PINENTRY` | pinentry | Standalone |
| `CONFIG_LVM2` | lvm2 | Standalone |
| `CONFIG_DROPBEAR` | dropbear | Standalone |
| `CONFIG_FLASHTOOLS` | flashtools | Standalone |
| `CONFIG_NEWT` | newt | Standalone |
| `CONFIG_CAIRO` | cairo | Standalone |
| `CONFIG_FBWHIPTAIL` | fbwhiptail | Standalone |
| `CONFIG_HOTPKEY` | hotp-verification | Standalone |
| `CONFIG_MSRTOOLS` | msrtools | Standalone |
| `CONFIG_NKSTORECLI` | nkstorecli | Standalone |
| `CONFIG_UTIL_LINUX` | util-linux | Standalone |
| `CONFIG_OPENSSL` | openssl | Standalone |
| `CONFIG_TPM2_TOOLS` | tpm2-tools | Standalone |
| `CONFIG_TPM2_TOOLS` | tpm-gpio-reset | Standalone |
| `CONFIG_BASH` | bash | Standalone |
| `CONFIG_POWERPC_UTILS` | powerpc-utils | Standalone |
| `CONFIG_IO386` | io386 | Standalone |
| `CONFIG_IOPORT` | ioport | Standalone |
| `CONFIG_KBD` | kbd | Standalone |
| **`CONFIG_ZSTD`** | **zstd** | **Standalone** |
| `CONFIG_E2FSPROGS` | e2fsprogs | Standalone |
| `CONFIG_EXFATPROGS` | exfatprogs | Standalone |
| `CONFIG_NVMUTIL` | nvmutil | Standalone |

## Hardware compatibility list (HCL)

The canonical hardware compatibility list is maintained in the heads-wiki:

<https://osresearch.net/Hardware-Compatibility/>

Each `boards/*/*.config` carries a short hardware-compatibility summary and
links to its canonical HCL entry (the `unmaintained_boards/*` configs do not);
the full platform, integrated USB3/xHCI and USB4, flash-size, and TPM details
live in the wiki.

## BusyBox applets (always available)

BusyBox v1.36.1 provides the following applets relevant to Heads scripts.
These are always available regardless of board config.

```text
[, [[, arch, arp, ascii, ash, awk, base32, basename, blkid, blockdev,
bunzip2, bzcat, bzip2, cat, chattr, chmod, chroot, clear, cmp, cp,
cpio, crc32, cttyhack, cut, date, dc, dd, devmem, df, diff, dirname,
dmesg, du, echo, env, expr, factor, fallocate, false, fdisk, find,
fold, fsck, fsfreeze, getopt, grep, groups, gunzip, gzip, hd, head,
hexdump, hexedit, hostid, hwclock, i2cdetect, i2cdump, i2cget, i2cset,
id, ifconfig, insmod, install, ip, kill, killall, killall5, less, link,
ln, loadkmap, losetup, ls, lsattr, lsmod, lsof, lsscsi, lsusb, lzcat,
lzma, md5sum, mkdir, mkdosfs, mkfifo, mkfs.vfat, mknod, mktemp,
modinfo, more, mount, mv, nc, nl, nproc, nslookup, ntpd, partprobe,
paste, patch, pgrep, pidof, ping, pkill, printf, ps, pwd, readlink,
realpath, reboot, reset, resume, rm, rmdir, route, sed, seedrng, seq,
setfattr, setpriv, setserial, setsid, sh, sha1sum, sha256sum, sha3sum,
sha512sum, shred, sleep, sort, ssl_client, stat, strings, stty, sync,
sysctl, tail, tar, tee, test, tftp, time, top, touch, tr, tree, true,
truncate, tsort, tty, udhcpc, umount, uname, uniq, unlzma, unxz, unzip,
usleep, vconfig, vi, wc, wget, which, xargs, xxd, xz, xzcat, zcat
```

## How the build system includes modules

Three files interact to determine what goes into `tools.cpio` (the initrd):

| File | Line | Role |
|------|------|------|
| `boards/<board>/<board>.config` | `CONFIG_FOO=y` | Board-specific Make variable (e.g. `CONFIG_GPG2=y` enables GPG) |
| `modules/<name>` | `CONFIG_FOO ?= y` | Module default — only sets the variable if the board config did not |
| `Makefile` | `include modules/*` | Loads all module files into the Make namespace |
| `Makefile` | `bin_modules-$(CONFIG_FOO) += foo` | Conditionally builds and adds the module to `tools.cpio` |

**The inclusion decision tree for any board:**

1. `include $(CONFIG)` loads the board config — any `CONFIG_FOO=y`
   (no `export` needed) becomes a Make variable.
2. `include modules/*` loads every module file.  Each module
   can set a default with `?=` which only applies if the board config didn't already
   set the variable.
3. `bin_modules-$(CONFIG_FOO) += foo` conditionally adds the
   module to `tools.cpio` — when `CONFIG_FOO` is `y`, the module is built and included;
   when `n` or unset, it is skipped.
4. `modules-$(CONFIG_FOO) += foo` (in the module file) adds the module to the
   build graph so its compile targets run.

**`export` in board configs is unrelated to module inclusion.**  `export` places the
variable into the initrd's `/etc/config` at build time, where `config-gui.sh` can
modulate it further with user overrides from CBFS `/etc/config.user`.  Module
inclusion is purely based on Make variable state.

### Auto-included modules

These modules use `CONFIG_FOO ?= y` in their `modules/<name>` file, so they
are included in every build unless a board explicitly sets `CONFIG_FOO=n`:

| Module | File | Default |
|--------|------|---------|
| `zstd` | `modules/zstd` | `CONFIG_ZSTD ?= y` — provides `zstd-decompress` |
| `bash` | `Makefile` | `CONFIG_BASH ?= y` — interactive shell |
| `kbd` | `Makefile` | `CONFIG_KBD ?= y` — keymaps and `loadkeys` |
| `heads` | `Makefile` | `CONFIG_HEADS ?= y` — Heads base |

Some auto-included defaults are set in the Makefile itself (before `include modules/*`),
others in the module `.mk` files.  The effect is the same: `?=` only sets the variable
if the board config did not already override it.

### Keymaps

`modules/kbd` stages the keymap tree into `usr/lib/kbd/keymaps`.  The console layout is user-selectable at runtime: `config-gui.sh` browses the shipped keymaps and lets the user pick the layout used at the LUKS passphrase prompt, so the full keymap set is kept.  `loadkeys --default` needs `defkeymap.map`, and the layout `.map` files pull shared fragments from the keymap `include` directories, so those must ship alongside.  A board can set `CONFIG_KBD=n` to omit the keymap tree entirely (the x220 boards do).

### TPM1 vs TPM2 tools

The TPM1 `tpm` mega-binary and its library (`util/tpm` → `bin/tpm`,
`libtpm/libtpm.so`) are built by `modules/tpmtotp`.  They are used only when
`CONFIG_TPM2_TOOLS` is not `y` (TPM1.2 boards); TPM2 boards enable
`CONFIG_TPM2_TOOLS`, which pulls in the `tpm2-tools` module instead, and
`tpmr.sh` dispatches TPM1 vs TPM2 subcommands on that flag.

### Board-enabled modules

These modules default to `n` and must be explicitly enabled in the board config
with `CONFIG_FOO=y` (no `export` needed for inclusion):

```bash
# boards/qemu-coreboot-fbwhiptail-tpm2/qemu-coreboot-fbwhiptail-tpm2.config
CONFIG_GPG2=y          # enables gpg2 module
CONFIG_TPM2_TOOLS=y    # enables tpm2-tools module
```

### Listing auto-included modules

```bash
grep -r 'CONFIG_.*?= y' modules/ Makefile | grep -v '\.git'
```

## Available targets

### Module targets

Each `modules/<name>` file generates a Make target.  Build a single
package and its dependencies:

```bash
nix develop --command make BOARD=$BOARD kexec     # kexec-tools
nix develop --command make BOARD=$BOARD linux      # Linux kernel
nix develop --command make BOARD=$BOARD coreboot   # coreboot ROM
```

Full ROM build (all modules + initrd + ROM assembly):

```bash
nix develop --command make BOARD=$BOARD
```

### Maintenance targets

| Target | What it does |
|--------|-------------|
| `real.clean` | `rm -rf` each module build dir under `build/$ARCH/` (all modules except `musl`/`musl-cross-make`) plus `kernel_headers`, wipe `install/*`, reset the coreboot `.canary`.  Keeps `packages/` and `crossgcc/`.  Destructive last resort. |
| `real.gitclean` | `git clean -fxd` — remove all untracked/ignored files (`build/`, `crossgcc/`, `install/`) |
| `real.gitclean_keep_packages` | `git clean -fxd -e "packages"` — keep downloaded tarballs in `packages/` |
| `real.remove_canary_files-extract_patch_rebuild_what_changed` | Purge every `build/**/.canary`, clear `install/*/*` and the coreboot/board build caches.  The re-extract/re-patch/rebuild runs on the NEXT `make`.  First choice after changing patches. |
| `real.gitclean_keep_packages_and_build` | `git clean -fxd -e "packages" -e "build"` — keep `packages/` and `build/` |

All run under `nix develop` (local) or `./docker_repro.sh` (Docker):

```bash
nix develop --command make BOARD=$BOARD real.clean
nix develop --command make BOARD=$BOARD real.remove_canary_files-extract_patch_rebuild_what_changed
```

### Rebuild helpers

The build is stamp-driven.  Each module carries sentinel files in
`build/$ARCH/PACKAGE-DIR/`: `.canary` (source extracted/cloned and patches
applied), `.configured` (`configure` ran), and `.build` (built/installed);
git-cloned modules additionally carry `.patched` (patches applied to the
clone).  A plain `make BOARD=<board>` rebuilds only what the stamps say is
stale.  It does **not** track `CFLAGS`, so flag changes are invisible to it.

Pick the helper by what you changed:

| You need to… | Run |
|---|---|
| change a file inside a module's source | plain `make BOARD=<board>` |
| change build flags (`CFLAGS`) | `<module>.clean` then `make BOARD=<board> <module>`; for all modules `modules.clean` then `make BOARD=<board>` |
| change board or kernel configuration | plain `make BOARD=<board>` |
| change a patch file | remove that package's `.canary`, `.configured`, and `.build`, then `make BOARD=<board> <pkg>`; broad: the canary purge.  For a git-clone package, removing its `.canary` also triggers that module's board-dir wipe (see the canary-purge caveat below) |
| change an `initrd/` script | plain `make BOARD=<board>` |
| get a trusted build after source/patch edits | `real.remove_canary_files-extract_patch_rebuild_what_changed` then `make BOARD=<board>` |
| prove reproducibility is broken | `real.clean` (destructive, last resort) then `make BOARD=<board>` |

Helper → effect, what each removes and keeps:

| Helper | Removes | Keeps |
|---|---|---|
| `<module>.clean` | that module's `.configured`, then `make -C <builddir> clean` (may delete generated sources for `tpm2-tss`/`tpm2-tools`) | `.canary`, `.build` |
| `modules.clean` | for each module dir, `make -C <dir> clean` + `.configured` | `install/`, `packages/`, `.canary`, `.build` |
| canary purge (`real.remove_canary_files-…`) | every `build/**/.canary`; `install/*/*`; the coreboot board dir and `build/$ARCH/<board>`; resets the coreboot `.canary` | module objects (`.o`, `.build`) |
| `real.clean` | each module build dir under `build/$ARCH/` (all modules except `musl`/`musl-cross-make`) plus `kernel_headers`; `install/*`; resets the coreboot `.canary` | `packages/`, `crossgcc/` |
| `real.gitclean` | `build/`, `crossgcc/`, `install/` (via `git clean -fxd`) | nested git repos, tracked files |
| `real.gitclean_keep_packages` | `build/`, `crossgcc/`, `install/` | `packages/`, nested git repos |
| `real.gitclean_keep_packages_and_build` | `crossgcc/`, `install/` | `packages/`, `build/`, nested git repos |

All five `real.*` clean targets call `overwrite_canary_if_coreboot_git`, which
writes `BOGUS_COMMIT_ID` into the coreboot `.canary` to force a re-check on the
next build.

Two caveats:

- The `git clean` helpers do **not** remove nested git repositories (git skips
  them), so the coreboot and other module source clones survive;
  `overwrite_canary_if_coreboot_git` resets only coreboot's `.canary`, so the
  other surviving clones keep theirs.
- The canary purge cannot fix stale flags: module objects (`.o`, `.build`)
  survive, so flags baked into them remain.  Use `<module>.clean` /
  `modules.clean` for flag changes.

### Module-level helpers

Some packages define their own helpers in `modules/<name>`.
Common ones (run with `nix develop --command make BOARD=$BOARD <target>`):

| Target | Defined in | What it does |
|--------|-----------|-------------|
| `coreboot.save_in_defconfig_format_in_place` | `modules/coreboot` | Normalize to defconfig (minimal, sorted) |
| `coreboot.save_in_oldconfig_format_in_place` | `modules/coreboot` | Normalize to full .config |
| `coreboot.save_in_defconfig_format_backup` | `modules/coreboot` | Same as defconfig but saves as `_defconfig` backup |
| `coreboot.modify_defconfig_in_place` | `modules/coreboot` | Run `menuconfig`, save as defconfig |
| `coreboot.modify_and_save_oldconfig_in_place` | `modules/coreboot` | Run `menuconfig`, save as full .config |
| `linux.save_in_defconfig_format_in_place` | `modules/linux` | Normalize kernel config to defconfig |
| `linux.save_in_olddefconfig_format_in_place` | `modules/linux` | Normalize to olddefconfig format |
| `linux.save_in_versioned_defconfig_format` | `modules/linux` | Save defconfig with version stamp |
| `linux.save_in_versioned_oldconfig` | `modules/linux` | Save full .config with version stamp |
| `linux.modify_and_save_defconfig_in_place` | `modules/linux` | Run `menuconfig`, save as defconfig |
| `linux.modify_and_save_oldconfig_in_place` | `modules/linux` | Run `menuconfig`, save as full .config |
| `linux.prompt_for_new_config_options_for_kernel_version_bump` | `modules/linux` | Prompt for new kernel Kconfig options on version bump |
| `linuxboot.run` | `modules/linuxboot` | Run Heads under LinuxBoot |
| `u-root.clean` | `modules/u-root` | Clean u-root build artifacts |

These are used after manually editing `config/coreboot-BOARD.config` or
`config/linux-BOARD.config` to normalize the file back to the convention
expected by the build system.

## Build lifecycle

Each module (whether tarball or git-sourced) goes through the same stages
controlled by sentinel files in `build/$ARCH/PACKAGE-DIR/`:

```
tarball / git clone → .canary → .configured → .build → binary → initrd
```

- **`.canary`** — package extracted/cloned and patches applied.  Depends
  only on the tarball or git repo HEAD, NOT on patch files.
- **`.configured`** — `./configure` run (or equivalent setup).
- **`.build`** — `make` / `make install` run.  Depends on `.configured`
  and on all dependency packages' `.build` files.

The binary lands in `build/$ARCH/PACKAGE-DIR/$output` and is copied into
the initrd by `bin_modules-$(CONFIG_FOO)`.

### Rebuilding after changing a patch

**The `.canary` sentinel does NOT depend on patch files.**  Modifying a
patch in `patches/PACKAGE-VERSION/` leaves `.canary` up-to-date and the
old binary is used.  To force re-extraction and re-patching:

**Per-package** (fastest, one package only):

```bash
rm build/$ARCH/PACKAGE-DIR/.canary
rm build/$ARCH/PACKAGE-DIR/.configured
rm build/$ARCH/PACKAGE-DIR/.build
nix develop --command sh -c "make BOARD=$BOARD $PACKAGE"
```

Example: after changing `patches/kexec-2.0.26/0003-screen_info-normalize-for-VLFB.patch`:

```bash
rm build/x86/kexec-tools-2.0.26/.canary
rm build/x86/kexec-tools-2.0.26/.configured
rm build/x86/kexec-tools-2.0.26/.build
nix develop --command sh -c "make BOARD=novacustom-nv4x_adl kexec"
```

**Full rebuild** (all packages, use the helper target):

```bash
nix develop --command make BOARD=$BOARD \
  real.remove_canary_files-extract_patch_rebuild_what_changed
nix develop --command make BOARD=$BOARD
```

#### Canary purge deterministically empties the initrd of kernel modules on TPM2 boards

`real.remove_canary_files-extract_patch_rebuild_what_changed` deletes every
`build/**/.canary`.  The standalone-clone recipes (`coreboot`, `tpm-gpio-reset`,
`tpm-gpio-fail`) treat a missing `.canary` as a stale source tree: they take
their `git clean` path and `rm -rf build/$ARCH/$BOARD`.  This is not a race.
On TPM2 boards the `tpm-gpio-reset`/`tpm-gpio-fail` clones are (re)built as part
of the initrd, so their wipe **will** land after `modules.cpio` has been
produced but before the initrd is packaged, and the initrd is assembled
**without the kernel modules**.

After using the helper, always run one extra incremental pass so the deleted
`modules.cpio` is rebuilt and re-packaged:

```bash
nix develop --command make BOARD=$BOARD \
  real.remove_canary_files-extract_patch_rebuild_what_changed
nix develop --command make BOARD=$BOARD     # extra pass
```

Then verify the initrd actually contains `lib/modules` before trusting it (run
this under `nix develop` so `cpio` is available):

```bash
xz -dc build/x86/$BOARD/initrd.cpio.xz | cpio -it 2>/dev/null \
  | grep -m1 '^lib/modules' && echo "kernel modules present" \
  || echo "MISSING kernel modules"
```

## Module file format

Defined in `modules/<name>`.  See `modules/kexec` for a complete example.
Key variables:

```makefile
modules-$(CONFIG_KEXEC) += kexec      # add to build graph
kexec_dir := kexec-tools-$(kexec_version)
kexec_tar := kexec-tools-$(kexec_version).tar.gz
kexec_hash := sha256...
kexec_output := build/sbin/kexec       # installed into initrd
```

The `define_module` function in `Makefile` expands these into the
`.canary` → `.configured` → `.build` chain above.  The package name
is the Make target: `make BOARD=... kexec` builds just that package.

### Shared module build flags

Standalone modules each pass their own `CFLAGS`/`LDFLAGS`; the two flag groups
below are common to almost all of them:

- `-ffunction-sections -fdata-sections` together with
  `-Wl,--gc-sections -Wl,--no-eh-frame-hdr`: the compiler places every function
  and datum in its own section, and the linker keeps only the sections the
  initrd actually calls.
- `-fno-asynchronous-unwind-tables -fno-unwind-tables`: the compiler omits
  `.eh_frame` and unwind tables; the initrd is single-purpose and never
  unwinds the stack.

Rather than repeating this rationale in every module file, each module points
here.

## Toolchain Modules

### musl-cross-make

The `MUSL_CROSS_ONCE` guard prevents `modules/musl-cross-make` from being
included multiple times.

The cross-compiler is included **early** in the Makefile so
that `$(CROSS)` and `$(heads_cc)` are available before any userland module is
included.

See `doc/circleci.md` for how CI orchestrates toolchain caching across jobs.
