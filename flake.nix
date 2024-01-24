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
            cmake
            cpio
            curl
            dtc
            elfutils
            flex
            git
            gnat11
            innoextract
            m4
            ncurses5 # make menuconfig
            perl
            pkgconfig
            python3
            rsync
            sharutils
            texinfo
            unzip
            zip
            wget
            which
            zlib.dev
            imagemagick
            vim
          ]
          ++ [
            # qemu-coreboot-fbwhiptail-tpm2-hotp
            libtool
          ]
          ++ [
            # t440p
            e2fsprogs
            parted
          ];
      };
    });
}
