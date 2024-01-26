{
  description = "heads flake, mostly for devshell for now";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShell = pkgs.mkShellNoCC {
        buildInputs = with pkgs; [
          autoconf
          automake
          #bc
          #bison # Generate flashmap descriptor parser
          cacert
          #canokey-qemu # qemu library support. Requires rebuilding qemu below.
          cmake
          cpio
          curl
          #dtc #device tree compiler: not sure needed.
          #elfutils
          #elfutils.dev #otherwise coreboot buidstack fails on nix deployed on top of quebesos 4.2 debian-12
          flex
          git
          #gnat11
          coreboot-toolchain.i386
          coreboot-toolchain.ppc64
          innoextract
          m4
          ncurses # make menuconfig
          perl
          pkgconfig
          python3
          #qemu #needed to test qemu-coreboot-* board configs
          rsync
          shadow #needed by tpm2-tss for groupadd/useradd otherwise fails to build
          #sharutils
          swtpm #needed to test qemu-coreboot-* board configs with qemu
          texinfo
          unzip
          zip
          wget
          which
          zlib.dev
          imagemagick
          vim
          ccache
          #(qemu.override {
          #  canokeySupport = true; #Needed if qemu testing desired with virtual USB Security Dongle (config not yet added)
          #  hostCpuOnly = true;
          #})
        ];
      };
    });
}
