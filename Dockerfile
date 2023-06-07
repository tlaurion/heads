FROM nixos/nix:2.16.1

WORKDIR /root
COPY flake.nix flake.lock ./
RUN mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' | tee ~/.config/nix/nix.conf
RUN nix develop --ignore-environment --command true
