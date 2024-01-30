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

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShell = pkgs.mkShellNoCC {
        buildInputs = with pkgs;
          [
            autoconf
            automake
            bc
            bison # Generate flashmap descriptor parser
            cacert
            canokey-qemu # qemu library support. Requires rebuilding qemu below.
            ccache
            cmake
            cpio
            curl
            dtc
            e2fsprogs
            elfutils
            flex
            git
            gnat
            gnumake
            imagemagick
            innoextract
            libtool
            m4
            ncurses5 # make menuconfig
            #nix-docker # build docker image from this flake. Doesn't exist, nnixOS not nix based.
            parted
            perl
            pkg-config
            python3
            rsync
            sharutils
            texinfo
            unzip
            wget
            which
            zip
            zlib.dev
          ]
          ++ [
            # debugging/fixing/testing
            #(qemu.override {
            #  canokeySupport = true; #Needed if qemu testing desired with virtual USB Security Dongle (config not yet added under qemu.mk)
            #})
            vim
          ];
      };

      packages.heads-docker = pkgs.dockerTools.buildImage {
        name = "heads-docker";
        tag = "0.1.0";
        contents = self.devShell;
      };

      defaultPackage = self.packages.heads-docker;
    });
}

