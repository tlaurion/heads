{
  description = "heads flake, mostly for devshell for now";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    gnat6nixpkgs.url = "nixpkgs/19cb612405c82c7f4fb3ce4497e24c1efa0b1935";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShell =
        (pkgs.buildFHSUserEnv {
          name = "heads-build-env";
          targetPkgs = pkgs: (with pkgs;
            [
              bison # Generate flashmap descriptor parser
              curl
              flex
              git
              texinfo
              gcc
              git
              gnumake
              m4
              ncurses # make menuconfig
              nss # ca-certs
              perl
              pkgconfig
              wget
              which
              rsync #needed by 5.x linux kernels
              qemu #test image
              swtpm #test image with qemu and BOARD=qemu-(fb)whiptail-tpm(1/2) targets
              zlib.dev
          profile = ''
          '';
        })
        .env;
    });
}
