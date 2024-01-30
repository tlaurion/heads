FROM nixos/nix:2.16.1

WORKDIR /root
COPY flake.nix flake.lock ./
RUN mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' | tee ~/.config/nix/nix.conf
RUN nix develop --print-build-logs --ignore-environment --command true
#RUN nix-store --delete --ignore-liveness $(nix-store -qR $(nix-store -q --references $(nix-instantiate flake.nix))) && nix-store --optimise
#RUN nix-store nix-collect-garbage --dry-run -vv $(nix-store -qR $(nix-store -q --references $(nix-instantiate flake.nix))) && nix-store --optimise --dry-run -vv $(nix-store -qR $(nix-store -q --references $(nix-instantiate flake.nix)))


#When building qemu with canokey support configured in, currently Docker image is 5.09GB. Nix cleanup needs to be figured out on non-libraries/binaries
# user@heads-tests-deb12-nix:~/heads$ docker images 
#REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
#<none>       <none>    5b2e61063c41   31 minutes ago   5.03GB

