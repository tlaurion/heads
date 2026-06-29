{
  description = "Optimized heads flake for Docker image with garbage collection protection";

  # Inputs define external dependencies and their sources.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # Using the unstable channel for the latest packages, while flake.lock fixates the commit reused until changed.
    # No flake for 3.8.0
    # Pinned nixpkgs for sdcc 4.2.0 - matches: https://github.com/Dasharo/ec-sdk/pull/2
    # sdcc 4.5.0 has optimizer bug: https://github.com/Dasharo/dasharo-issues/issues/1785
    nixpkgs-sdcc.url = "github:nixos/nixpkgs/7a339d87931bba829f68e94621536cad9132971a";
    flake-utils.url = "github:numtide/flake-utils"; # Utilities for flake functionality.
    nixpkgs-tinygo.url = "github:nixos/nixpkgs/e73de5be04e0eff4190a1432b946d469c794e7b4"; # Pinned for tinygo 0.41.1
    nixpkgs-tinygo.flake = false;
    tlaurion-tinygo.url = "github:tlaurion/tinygo/main";
    tlaurion-tinygo.flake = false;
    tlaurion-net.url = "github:tlaurion/net/main";
    tlaurion-net.flake = false;
  };
  # Outputs are the result of the flake, including the development environment and Docker image.
  outputs = {
    self,
    flake-utils,
    nixpkgs,
    nixpkgs-sdcc,
    nixpkgs-tinygo,
    tlaurion-tinygo,
    tlaurion-net,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system}; # Accessing the legacy package set.
      pkgs-sdcc = nixpkgs-sdcc.legacyPackages.${system}; # Pinned for sdcc 4.2.0
      pkgs-tinygo = import nixpkgs-tinygo { inherit system; }; # Pinned for tinygo 0.41.1
      lib = pkgs.lib; # The standard Nix packages library.

      # Patched tinygo: build from tlaurion fork directly.
      # tlaurion-tinygo has os/sync/crypto/tls patches committed in-tree.
      # tlaurion-net replaces src/net with net/tcp/udp/tls/http patches.
      # lib/ submodules (device defs, C runtimes) come from the nixpkgs source
      # which has fetchSubmodules=true.
      tinygo-patched = pkgs-tinygo.tinygo.overrideAttrs (old: {
        src = tlaurion-tinygo;
        version = old.version; # keep 0.41.1 for naming consistency
        # nixpkgs makefile patch doesn't apply cleanly to fork (uses ${LLVM_PROJECTDIR}).
        # We handle the needed GNUmakefile changes in postPatch instead.
        patches = [];
        vendorHash = "sha256-Hcn0FwclRpFfZ/KAfXUodZu1QyBsGyczZ3zbnJdCHV8=";
        postPatch = (old.postPatch or "") + ''
          echo "tinygo-patched: restoring lib/ submodules from nixpkgs source"
          # tlaurion-tinygo (flake input) doesn't include submodules.
          # Copy them from the nixpkgs source which has fetchSubmodules=true.
          for libdir in CMSIS avr bdwgc binaryen cmsis-svd macos-minimal-sdk mingw-w64 musl nrfx picolibc stm32-svd wasi-cli wasi-libc; do
            src="${old.src}/lib/$libdir"
            dst="lib/$libdir"
            if [ -d "$src" ]; then
              rm -rf "$dst"
              cp -r "$src" "$dst"
              chmod -R u+w "$dst"
              echo "tinygo-patched: lib/$libdir"
            fi
          done
          echo "tinygo-patched: replacing src/net from tlaurion-net"
          rm -rf src/net
          cp -r "${tlaurion-net}" src/net
          chmod -R u+w src/net

          echo "tinygo-patched: fixing GNUmakefile for nix build"
          # Remove Darwin Homebrew path search (not applicable in nix build)
          sed -i '/BREW_PREFIX/d; /brew --prefix/d; /Also explicitly search Brew/d' GNUmakefile
          # Simplify build/release target: nix provides LLVM/clang/binaryen
          sed -i 's/build\/release: tinygo gen-device.*/build\/release:/' GNUmakefile
          # Remove clang include headers copy (nix provides LLVM headers at runtime)
          sed -i '/lib\/clang\/include/d' GNUmakefile
          # Use nix-provided compiler-rt builtins (from nix postPatch)
          sed -i 's|''${LLVM_PROJECTDIR}/compiler-rt/lib/builtins|lib/compiler-rt-builtins|g' GNUmakefile
          # LICENSE.TXT is at compiler-rt root, not in lib/builtins/; skip that line
          sed -i '/compiler-rt\/LICENSE.TXT/d' GNUmakefile
        '';
      });

      # Dependencies are the packages required for the Heads project.
      # Organized into subsets for clarity and maintainability.
      deps = with pkgs; [
        # Core build utilities
        autoconf
        automake
        bashInteractive
        coreutils #basic tools like ls, cp, mv, kill)
        bc
        bison # Generate flashmap descriptor parser
        bzip2
        cacert
        ccache
        coreboot-utils #consumed by diffoscope for ifdtool cbfsutils etc
        cmake
        cpio
        curl
        diffutils
        dtc
        e2fsprogs
        elfutils
        findutils
        flex
        gawk
        git
        gnat # required for libgfxinit under coreboot, hacked around for kgpe-d16
        gnugrep
        gnumake
        gnused
        gnutar
        gzip
        imagemagick # For bootsplash manipulation
        innoextract # ROM extraction for dGPU
        libtool
        m4
        ncurses5 # make menuconfig and slang
        nss
        openssl # needed for talos-2 kernel build
        parted
        patch
        perl
        pkg-config
        procps #process tools like free, pidof, pkill, top, vmstat, watch, etc
        psmisc #process tools like killall, pstree, etc
        python3 # me_cleaner, coreboot
        rsync # coreboot
        pkgs-sdcc.sdcc  # Dasharo EC build — pinned to 4.2.0 (matches Debian oldstable, 4.5 has optimizer bug)
        sharutils
        texinfo
        unzip
        wget
        which
        xxd # Dasharo EC build
        xz
        zip
        zlib
        zlib.dev
      ] ++ [
        qemu_full #Heavier then qemu + qemu_kvm, but contains qemu-img + kvm and everything else needed to do development/testing cycles under docker
      ] ++ [
        # Additional tools for debugging/editing/testing
        vim # Mostly used amongst us, sorry if you'd like something else, open issue
        swtpm # QEMU requirement to emulate tpm1/tpm2
        dosfstools # QEMU requirement to produce valid fs to store exported public key to be fused through inject_key on qemu (so qemu flashrom emulated SPI support).
        diffoscopeMinimal # Not sure exactly what is packed here, let's try. Might need diffoscope if something is missing
        gnupg #to inject public key inside of qemu create rom through inject_gpg target of targets/qemu.mk TODO: remove when pflash supported by flashrom + modify code
        less # so 'git log' is usable
        moreutils # so that 'make 2>&1 | ts' can give timestamps
      ] ++ [
        # Tools for handling binary blobs in their compressed state. (blobs/xx30/vbios_[tw]530.sh)
        bundler
        p7zip
        ruby
        sudo # ( °-° )
        upx
        binwalk # Extract all components of a binary
        uefi-firmware-parser #Parse and extract further hidden UEFI blobs from binaries
        tinygo-patched # Patched TinyGo from tlaurion forks (u-root build fixes)
      ];
    in {
      # Development shell with all dependencies.
      # devShell.<system> for: nix develop .#devShell.x86_64-linux
      devShell = pkgs.mkShellNoCC {
        buildInputs = deps;
      };
      # devShells.default.<system> for: nix develop (auto-detect in Nix ≥ 2.17)
      devShells.default = pkgs.mkShellNoCC {
        buildInputs = deps;
      };

      # myDevShell outputs environment variables necessary for development.
      packages.myDevShell =
        pkgs.runCommand "my-dev-shell" {}
        #bash
        ''
          grep \
            -e CMAKE_PREFIX_PATH \
            -e NIX_CC_WRAPPER_TARGET_TARGET \
            -e NIX_CFLAGS_COMPILE_FOR_TARGET \
            -e NIX_LDFLAGS_FOR_TARGET \
            -e PKG_CONFIG_PATH_FOR_TARGET \
            -e ACLOCAL_PATH \
            ${self.devShell.${system}} >$out
        '';

      # Docker image configuration for the Heads project.
      packages.dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "linuxboot/heads";
        tag = "dev-env";
        config.Entrypoint = ["bash" "-c" ''source /devenv.sh; if (( $# == 0 )); then exec bash; else exec "$0" "$@"; fi''];
        contents =
          deps
          ++ [
          pkgs.dockerTools.binSh
          pkgs.dockerTools.caCertificates
          pkgs.dockerTools.usrBinEnv
        ];
        enableFakechroot = true;
        fakeRootCommands =
          #bash
          ''
          set -e

          # Environment setup for the development shell.
          grep \
            -e NIX_CC_WRAPPER_TARGET_TARGET \
            -e NIX_CFLAGS_COMPILE_FOR_TARGET \
            -e NIX_LDFLAGS_FOR_TARGET \
            -e NIX_PKG_CONFIG_WRAPPER_TARGET \
            -e PKG_CONFIG_PATH_FOR_TARGET \
            -e ACLOCAL_PATH \
            ${self.devShell.${system}} >/devenv.sh

          mkdir /tmp; # Temporary directory for various operations.
          chmod 1777 /tmp

          # Ensure /etc/passwd and /etc/group exist with root entries
          echo "root:x:0:0:root:/root:/bin/bash" > /etc/passwd
          echo "root:x:0:" > /etc/group
          mkdir -p /root
          chmod 700 /root

          # Git configuration for safe directory access.
          echo -e '[safe]\n\tdirectory = *\n' > /root/.gitconfig
        '';
      };
    });
}
