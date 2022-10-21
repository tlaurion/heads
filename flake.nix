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
        buildInputs = with pkgs; [
          bc
          bison # Generate flashmap descriptor parser
          cmake
          cpio
          curl
          elfutils
          flex
          git
          gnat
          gnumake
          innoextract
          m4
          ncurses # make menuconfig
          nss # ca-certs
          perl
          pkgconfig
          python3
          qemu # test the image
          rsync
          wget
          which
          zlib.dev
        ];
        profile = ''
          unset NIX_SSL_CERT_FILE
          unset SSL_CERT_FILE
        '';
      };
    });
}
