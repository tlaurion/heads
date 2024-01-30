FROM nixos/nix:2.16.1
#FROM nixos/nix:2.3.15-minimal

WORKDIR /root
#copy the flake.nix and flake.lock to the root directory
COPY flake.nix flake.lock ./
# populate the nix store
RUN mkdir -p ~/.config/nix/ && echo 'experimental-features = nix-command flakes' | tee ~/.config/nix/nix.conf
# run nix develop to populate the nix store
RUN nix develop --print-build-logs --ignore-environment --command true
# create a gcroot for flake.nix
RUN mkdir -p /nix/var/nix/gcroots/auto
RUN ln -s /root/flake.nix /nix/var/nix/gcroots/auto/flake.nix
# run garbage collection and optimization for the nix store
RUN nix-store --gc
#No real gain in running optimize which cleans duplicates with hardlinks. Damn slow also.
#RUN nix-store --optimise

#When building qemu with canokey support configured in, currently Docker image is 5.09GB. Nix cleanup needs to be figured out on non-libraries/binaries
# user@heads-tests-deb12-nix:~/heads$ docker images 
#REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
#<none>       <none>    5b2e61063c41   31 minutes ago   5.03GB

