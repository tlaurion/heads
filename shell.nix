let
  _pkgs = import <nixpkgs> {};
in
  {
    pkgs ?
      import (_pkgs.fetchFromGitHub {
        owner = "NixOS";
        repo = "nixpkgs";
        #branch@date: nixpkgs-unstable@2023-01-03
        rev = "298add347c2bbce14020fcb54051f517c391196b";
        sha256 = "0q0c6gf21rbfxvb9fvcmybvz9fxskbk324xbvqsh1dz2wzgylrja";
      }) {},
  }:
    (pkgs.buildFHSUserEnv {
      name = "heads-build-env";
      targetPkgs = pkgs: (with pkgs; [
        bison # Generate flashmap descriptor parser
        curl
        flex
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
      ]);
      profile = ''
      '';
    })
    .env
