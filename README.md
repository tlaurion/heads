# Heads: the other side of TAILS

![Heads booting on an x230](https://user-images.githubusercontent.com/827570/156627927-7239a936-e7b1-4ffb-9329-1c422dc70266.jpeg)

Heads is a configuration for laptops and servers that tries to bring
more security to commodity hardware.  Among its goals are:

* Use free software on the boot path
* Move the root of trust into hardware (or at least the ROM bootblock)
* Measure and attest to the state of the firmware
* Measure and verify all filesystems

![Flashing Heads into the boot ROM](https://farm1.staticflickr.com/553/30969183324_c31d8f2dee_z_d.jpg)

NOTE: It is a work in progress and not yet ready for non-technical users.
If you're interested in contributing, please get in touch.
Installation requires disassembly of your laptop or server,
external SPI flash programmers, possible risk of destruction and
significant frustration.

More information is available in [the 33C3 presentation of building "Slightly more secure systems"](https://trmm.net/Heads_33c3).

## Documentation

The `doc/` directory contains technical reference documentation for the
Heads codebase. Start here:

| Document | What it covers |
| --- | --- |
| [doc/architecture.md](doc/architecture.md) | Component overview: coreboot, Linux payload, initrd, build system, configuration layers |
| [doc/security-model.md](doc/security-model.md) | Trust hierarchy, measured boot, TOTP/HOTP attestation, GPG boot signing, LUKS DUK, fail-closed design |
| [doc/boot-process.md](doc/boot-process.md) | Step-by-step boot flow: /init → gui-init → kexec-select-boot → OS handoff |
| [doc/tpm.md](doc/tpm.md) | PCR assignments, sealing policies, SRTM chain, board-specific TPM variations, developer config reference |
| [doc/ux-patterns.md](doc/ux-patterns.md) | GUI/UX conventions: whiptail wrappers, integrity report, error flows |
| [doc/config.md](doc/config.md) | Board and user configuration system |
| [doc/docker.md](doc/docker.md) | Reproducible build workflow using Docker |
| [doc/qemu.md](doc/qemu.md) | QEMU board targets for development and testing |
| [doc/wp-notes.md](doc/wp-notes.md) | Flash write-protection status per board |
| [doc/BOARDS_AND_TESTERS.md](doc/BOARDS_AND_TESTERS.md) | Supported boards and their maintainers/testers |

For user-facing documentation and guides, see [Heads-wiki](https://osresearch.net).

## Contributing

We welcome contributions to the Heads project! Before contributing, please read our [Contributing Guidelines](CONTRIBUTING.md) for information on how to get started, submit issues, and propose changes.

## Building Heads

Heads builds inside a versioned Docker image. The supported and tested workflow uses the
provided Docker wrappers — no host-side QEMU or swtpm installation is needed.

**Quick start** (requires [Docker CE](https://docs.docker.com/engine/install/)):

```bash
./docker_repro.sh make BOARD=x230-hotp-maximized
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2 run
```

For full details — wrapper scripts, Nix local dev, reproducibility verification, and
maintainer workflow — see **[doc/docker.md](doc/docker.md)**.

For QEMU board testing see **[doc/qemu.md](doc/qemu.md)**.

## General notes on reproducible builds

One such useful example is to build and test qemu board roms and test them through qemu/kvm/swtpm provided in the docker image. 
Please refer to [qemu documentation](targets/qemu.md) for more information.

Eg:
```
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2 # Build rom, export public key to emulated usb storage from qemu runtime
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2 PUBKEY_ASC=~/pubkey.asc inject_gpg # Inject pubkey into rom image
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2 USB_TOKEN=Nitrokey3NFC PUBKEY_ASC=~/pubkey.asc ROOT_DISK_IMG=~/qemu-disks/debian-9.cow2 INSTALL_IMG=~/Downloads/debian-9.13.0-amd64-xfce-CD-1.iso run # Install
```

Alternatively, you can use locally built docker image to build a board ROM image in a single call **but do not expect reproducible builds if not using versioned docker images as per CircleCI as per usage of `./docker_repro.sh`**

Eg:
`./docker_local_dev.sh make BOARD=nitropad-nv41`


Building with the published Docker image (recommended for reproducible builds)
====

The canonical, reproducible way to build Heads is to use `./docker_repro.sh`, which automatically pulls the pinned Docker image digest from `docker/DOCKER_REPRO_DIGEST` and ensures your builds match the CI environment exactly.

**For users**:
```bash
./docker_repro.sh make BOARD=x230-hotp-maximized
./docker_repro.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2 run
```

This will:
1. Resolve the canonical image digest from `docker/DOCKER_REPRO_DIGEST` (immutable, pinned to a specific version)
2. Pull the image if not present locally
3. Execute your build inside that exact Docker environment
4. Guarantee reproducibility: your ROM output will match official CircleCI builds for that commit

**About the published image**:
- **Repository**: `tlaurion/heads-dev-env` on Docker Hub is the maintainer's canonical image (configurable via `HEADS_MAINTAINER_DOCKER_IMAGE`)
- **Versioning**: Tagged with version numbers (e.g., `v0.2.7`) for stability; `:latest` is mutable and not recommended
- **Pinning**: The repository file `docker/DOCKER_REPRO_DIGEST` pins an immutable digest (`tlaurion/heads-dev-env@sha256:...`) to ensure reproducibility
- **Trust**: As long as flake.nix and flake.lock are not modified locally, your build will produce identical digests, confirming integrity
- **Fork/Override**: To use a different image repository (e.g., for testing or forks), set `HEADS_MAINTAINER_DOCKER_IMAGE="youruser/your-image"` before running any Docker wrapper script

Pinning the reproducible image
---

- `DOCKER_REPRO_DIGEST` — pin the image used by `./docker_repro.sh` to an immutable digest: `tlaurion/heads-dev-env@<digest>`. This environment variable (or the repository file `docker/DOCKER_REPRO_DIGEST`) is *consumed by* `./docker_repro.sh` via `resolve_docker_image()`; pinning ensures reproducible builds and mitigates supply-chain risk from mutable `:latest` tags.

```bash
./docker_repro.sh make BOARD=x230-hotp-maximized
./docker_repro.sh make BOARD=nitropad-nv41
```

Verifying reproducibility of locally-built Docker images
---

**Best practice**: Verify that your locally-built Docker image is reproducible by comparing its digest with the published maintainer image.

The Heads project maintains the canonical `tlaurion/heads-dev-env` Docker image on Docker Hub (configurable via `HEADS_MAINTAINER_DOCKER_IMAGE` environment variable for forks or testing). As long as you do not modify `flake.nix` or `flake.lock`, your locally-built image **should produce an identical digest** to the published image, demonstrating that your build is fully reproducible.

#### Quick reference

| Scenario | Command |
|----------|---------|
| **Check against latest maintainer image** | `HEADS_CHECK_REPRODUCIBILITY=1 ./docker_local_dev.sh` |
| **Check against specific version tag** | `HEADS_CHECK_REPRODUCIBILITY=1 HEADS_CHECK_REPRODUCIBILITY_REMOTE="tlaurion/heads-dev-env:v0.2.7" ./docker_local_dev.sh` |
| **Check fork maintainer's image** | `HEADS_MAINTAINER_DOCKER_IMAGE="youruser/heads-dev-env" HEADS_CHECK_REPRODUCIBILITY=1 ./docker_local_dev.sh` |
| **Standalone check (any time)** | `./docker/check_reproducibility.sh linuxboot/heads:dev-env tlaurion/heads-dev-env:v0.2.7` |

#### Prerequisites

You have either:
- Built a local Docker image with `./docker_local_dev.sh` (produces `linuxboot/heads:dev-env`), or
- Built from `nix build .#dockerImage` (results in `result` symlink loadable via `docker load`)

#### Check reproducibility

**Method 1: Automated check during build (recommended)**

Enable reproducibility verification automatically during your build with `HEADS_CHECK_REPRODUCIBILITY=1`:

```bash
# Verify against the default (maintainer's :latest image)
HEADS_CHECK_REPRODUCIBILITY=1 ./docker_local_dev.sh

# Example output when digests MATCH (reproducible build):
# === Reproducibility Check ===
# Local image  (linuxboot/heads:dev-env): sha256:5f890f3d1b6b57f9e567191695df003a2ee880f084f5dfe7a5633e3e8f937479
# Remote image (tlaurion/heads-dev-env:latest): sha256:5f890f3d1b6b57f9e567191695df003a2ee880f084f5dfe7a5633e3e8f937479
# ✓ MATCH: Local build is reproducible!
```

To test against a **specific version tag** instead of `:latest`:

```bash
HEADS_CHECK_REPRODUCIBILITY=1 \
  HEADS_CHECK_REPRODUCIBILITY_REMOTE="tlaurion/heads-dev-env:v0.2.7" \
  ./docker_local_dev.sh

# Example output when digests DIFFER (expected for different versions):
# === Reproducibility Check ===
# Local image  (linuxboot/heads:dev-env): sha256:5f890f3d1b6b57f9e567191695df003a2ee880f084f5dfe7a5633e3e8f937479
# Remote image (tlaurion/heads-dev-env:v0.2.6): sha256:75af4c816a4a92ebdd0030c2e56ebf23c066858e08145ec1cc64a9e750a0031d
# ✗ MISMATCH: Local build differs from remote
#   (This is expected if Nix/flake.lock versions differ or if uncommitted changes exist)
```

Note: Docker images can have two different identifiers: a local image ID and a registry manifest digest. If a local image has no `RepoDigests` entry, the reproducibility check will compare image IDs (and may pull the remote tag) instead of manifest digests to avoid false mismatches. This can happen for locally built images that have not been pulled from a registry.

**Method 2: Standalone reproducibility check**

Use the provided reproducibility checker script to compare hashes at any time:

```bash
# Compare your local dev image with a published version
./docker/check_reproducibility.sh linuxboot/heads:dev-env tlaurion/heads-dev-env:v0.2.7

# Output (example of a match):
# ✓ SUCCESS: Digests match!
#   Your local build is reproducible and identical to tlaurion/heads-dev-env:v0.2.7
```

**Method 3: Manual digest inspection**

Manually inspect the digest:

```bash
# Get the digest of your local image (after docker load)
docker inspect --format='{{.Id}}' linuxboot/heads:dev-env
# Output: sha256:8ae7744cc8b4ff0e959aa6dfeeb40dbd40d20ac6fa1f7071dd21ec0c2d0f9f41

# Compare with the published image (will pull if needed)
docker pull tlaurion/heads-dev-env:v0.2.7
docker inspect --format='{{.Id}}' tlaurion/heads-dev-env:v0.2.7
# Output: sha256:8ae7744cc8b4ff0e959aa6dfeeb40dbd40d20ac6fa1f7071dd21ec0c2d0f9f41
```

#### When digests should match

✓ **Digests match** → Your build is **reproducible and trustworthy**; matches the maintainer's published image for that Nix snapshot.

Your locally-built image **will** produce an identical digest to the published image when:
- `flake.nix` and `flake.lock` are **not modified** (i.e., repository is clean relative to these files)
- The same Nix version and dependencies are used
- Build runs on the same Nix store state

✗ **Digests differ** → Expected in these cases:

- You have uncommitted changes in `flake.nix` or `flake.lock`
- Different Nix version or Nix dependencies resolved differently on your system
- Using a different `nixpkgs` version than the locked one in `flake.lock`

#### Trust model

The `tlaurion/heads-dev-env` image on Docker Hub is the **maintainer's canonical build** and serves as the source of truth for reproducibility. By verifying that your locally-built image produces the same digest as the published `v0.2.7` (or current version), you confirm:

1. **No tampering**: Your build environment has not been compromised
2. **Reproducibility**: The Heads build system is deterministic for your specific Nix snapshot
3. **Auditability**: You can map your build back to a specific published, reviewed version

**Recommendation**: Always pin to a specific version tag (e.g., `tlaurion/heads-dev-env:v0.2.7`) rather than `:latest`, and verify the digest matches the published value before using it for critical builds.

Maintenance notes on docker image
===

To update the Docker image to a new version (e.g., vx.y.z), follow these steps. This ensures reproducible builds with immutable digests.

```
# Set variables
docker_version="vx.y.z"
docker_hub_repo="tlaurion/heads-dev-env"

# Update pinned packages to latest if needed, modify flake.nix as required
nix flake update

# Commit flake changes
git add flake.nix flake.lock
git commit --signoff -m "Bump nix develop based docker image to $docker_version"

# Verify reproducibility: ensure the local build matches (no further changes to flake files)
nix develop --ignore-environment --command true

# Build the new Docker image
nix build .#dockerImage
docker load < result

# Verify you can extract the digest (for fully reproducible builds, flake.nix/flake.lock must be committed)
docker inspect --format='{{.Id}}' linuxboot/heads:dev-env

# Tag the image with the new version
docker tag linuxboot/heads:dev-env "$docker_hub_repo:$docker_version"

# Push the new version to Docker Hub (requires push access)
docker push "$docker_hub_repo:$docker_version"

# Capture the digest of the pushed image (use --yes to auto-pull)
new_digest=$(./docker/get_digest.sh -y "$docker_hub_repo:$docker_version" | tail -n1)
prev_digest=$(grep '^[^#]' docker/DOCKER_REPRO_DIGEST | head -n1)

# Update the digest in the repository file and CircleCI config
sed -i "s|$prev_digest|$new_digest|" docker/DOCKER_REPRO_DIGEST .circleci/config.yml

# Update the version comment in the repository file
sed -i "s|# Version: .*|# Version: $docker_version|" docker/DOCKER_REPRO_DIGEST

# Update .circleci/config.yml to use the new digest and add version comments
# The first -e removes existing "# Docker image" comment lines. The second -e inserts a
# fresh "# Docker image: $docker_hub_repo:$docker_version" comment immediately above the
# matching "- image: $docker_hub_repo@<digest>" line while preserving indentation.
sed -i -e "/^[[:space:]]*# Docker image: /d" -e "/^[[:space:]]*- image: ${docker_hub_repo//\//\\/}@/ s|^\([[:space:]]*\)\(- image: ${docker_hub_repo//\//\\/}@\)|\\1# Docker image: $docker_hub_repo:$docker_version\n\\1\\2|" .circleci/config.yml

# Commit the digest and config changes
git add docker/DOCKER_REPRO_DIGEST .circleci/config.yml
git commit --signoff -m "Pin docker image to digest for $docker_version"

# Push the branch and create a PR for testing with CircleCI
git push origin docker/squash-docker-changes

# After PR is merged and tested:
# Tag the tested version as latest (optional; use with caution, prefer explicit versioning)
# docker tag "$docker_hub_repo:$docker_version" "$docker_hub_repo:latest"
# docker push "$docker_hub_repo:latest"
```

**Maintainer checklist**:
1. **Reproducibility**: Before pushing, verify `nix build .#dockerImage` produces a deterministic result (flake.nix and flake.lock must be committed and clean).
2. **Digest verification**: After pushing, use `./docker/check_reproducibility.sh` to verify local and remote digests match, confirming the build is reproducible.
3. **Supply chain**: Pin the digest in `docker/DOCKER_REPRO_DIGEST` and `.circleci/config.yml` to ensure all builds reference an immutable, auditable image.
4. **Documentation**: Update the version comment in `docker/DOCKER_REPRO_DIGEST` so users know which image version is pinned.
5. **User migration**: When releasing a new version, communicate the new digest and version to users via release notes.

**For forks and alternate maintainers**:
If you maintain a fork or want to test with a different Docker image repository, set `HEADS_MAINTAINER_DOCKER_IMAGE` before running any wrapper script:
```bash
# Example: use your own Docker image repository
export HEADS_MAINTAINER_DOCKER_IMAGE="youruser/heads-dev-env"

# Now all scripts will reference your repository
./docker_local_dev.sh make BOARD=x230
HEADS_CHECK_REPRODUCIBILITY=1 ./docker_local_dev.sh

# Reproducibility check will compare against youruser/heads-dev-env:latest
# resolve_docker_image will use youruser/heads-dev-env as the base image
```

Maintenance tip: The repository file `docker/DOCKER_REPRO_DIGEST` pins the canonical reproducible image used by `./docker_repro.sh`, ensuring immutable, secure builds.

Acceptable formats include `sha256:<64-hex>`, `sha256-<64-hex>` (normalized to `sha256:<hex>`), or just `<64-hex>` (normalized to `sha256:<hex>`). The helper will normalize these formats and produce an image reference like `tlaurion/heads-dev-env@sha256:<hex>`.

If you need to pin the convenience `./docker_latest.sh` wrapper, set the `DOCKER_LATEST_DIGEST` environment variable locally; we do not maintain a `docker/DOCKER_LATEST_DIGEST` file in the repository because 'latest' is a user-level convenience and should be explicitly chosen. When `DOCKER_LATEST_DIGEST` is unset, `./docker_latest.sh` may fall back to `DOCKER_REPRO_DIGEST` only when the base image matches the maintainer repo; otherwise it will prompt before using an unpinned `:latest` unless `HEADS_ALLOW_UNPINNED_LATEST=1` is set in the environment.

Example: obtain the immutable digest for a published image and use it to force `docker_latest.sh` to use an immutable image:

```bash
# 1) Obtain the digest for a published image (exact repo:name:tag form is required)
#
# Tip: inspect tags on Docker Hub: https://hub.docker.com/layers/tlaurion/heads-dev-env/
# Click a tag to see details (Content type, Digest (sha256:...), Size, Last updated).
# Use the shown tag name with docker pull, e.g.:
#   docker pull tlaurion/heads-dev-env:v0.2.7
#
# Example: pull the image and then obtain its digest locally
#   docker pull tlaurion/heads-dev-env:v0.2.7
#   ./docker/get_digest.sh tlaurion/heads-dev-env:v0.2.7
#
# Or: query the registry for the digest and optionally pull it when prompted
#   ./docker/get_digest.sh tlaurion/heads-dev-env:v0.2.7
#   (the script will show the remote digest and ask if you want to pull the image to create a local repo@digest)
#
# Use -y to auto-pull and return the digest in one go:
#   ./docker/get_digest.sh -y tlaurion/heads-dev-env:v0.2.7

./docker/get_digest.sh tlaurion/heads-dev-env:v0.2.7
# Output (example): tlaurion/heads-dev-env@sha256:50a9110c...\nsha256:50a9110c...

# 2) If the image is not present locally, the helper will offer to pull it so a local repo@digest is available.
#    Use '-y' / '--yes' to skip the interactive prompt and pull automatically.
./docker/get_digest.sh -y tlaurion/heads-dev-env:latest

# 3) Export the raw digest into the env var expected by the wrapper
export DOCKER_LATEST_DIGEST=$(./docker/get_digest.sh tlaurion/heads-dev-env:latest | tail -n1)

# 4) Run the convenience wrapper using the pinned digest
DOCKER_LATEST_DIGEST=$DOCKER_LATEST_DIGEST ./docker_latest.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2

Note: when a digest is discovered, helpers print a concise summary to help auditing, for example:

  Image: tlaurion/heads-dev-env@sha256:50a9...
  Digest: sha256:50a9...
  Resolved from: local|registry API|env|file
  Tip: export DOCKER_LATEST_DIGEST=sha256:50a9...

This makes it easy to copy/pin digests or verify provenance.

If you want to change what `./docker_latest.sh` uses as the "latest" image:
- For a temporary override: run `./docker/pin-and-run.sh <repo:tag> -- ./docker_latest.sh <command>` to run the wrapper pinned to a specific digest.
- To set a local convenience env: `export DOCKER_LATEST_DIGEST=$(./docker/get_digest.sh tlaurion/heads-dev-env:vX.Y.Z | tail -n1)`.
- To change the canonical fallback used by the project: edit `docker/DOCKER_REPRO_DIGEST` with the desired digest and commit the change.

# Convenience: helper to obtain a digest and run a wrapper pinned to that digest
# Example: obtains digest and runs the 'latest' wrapper pinned to that digest (explicit wrapper is recommended)
./docker/pin-and-run.sh tlaurion/heads-dev-env:v0.2.7 -- ./docker_latest.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2
# Auto-pull and run (non-interactive)
./docker/pin-and-run.sh -y tlaurion/heads-dev-env:v0.2.7 -- ./docker_latest.sh make BOARD=qemu-coreboot-fbwhiptail-tpm2

# Shortcut: omit the wrapper and just provide the command — the helper will use the default './docker_latest.sh'
./docker/pin-and-run.sh tlaurion/heads-dev-env:v0.2.7 -- make BOARD=qemu-coreboot-fbwhiptail-tpm2

# Explicit wrapper flag: use -w/--wrapper to avoid ambiguity
./docker/pin-and-run.sh -w ./docker_repro.sh tlaurion/heads-dev-env:v0.2.7 -- make BOARD=qemu-coreboot-fbwhiptail-tpm2


```

Alternative (manual) commands without the helper script:

```bash
docker pull tlaurion/heads-dev-env:latest
# prints full repo@digest (if available)
docker inspect --format='{{index .RepoDigests 0}}' tlaurion/heads-dev-env:latest
# to get only the digest portion:
docker inspect --format='{{index .RepoDigests 0}}' tlaurion/heads-dev-env:latest | cut -d'@' -f2
```

Notes: some registries or Docker versions may require `docker manifest inspect` or `skopeo inspect` to obtain an authoritative digest; the helper script tries `docker inspect` first, then `docker manifest inspect` when available.

Update the appropriate file after publishing a new image to keep the repo in sync.

Notes:
- Local builds can use ":latest" tag, which will use latest tested successful CircleCI run
- To reproduce CircleCI results, make sure to use the same versioned tag declared under .circleci/config.yml's "image:" 



General notes on reproducible builds
===
In order to build reproducible firmware images, Heads builds a specific
version of gcc and uses it to compile the Linux kernel and various tools
that go into the initrd.  Unfortunately this means the first step is a
little slow since it will clone the `musl-cross-make` tree and build gcc...

Once that is done, the top level `Makefile` will handle most of the
remaining details -- it downloads the various packages, verifies the
hashes, applies Heads specific patches, configures and builds them
with the cross compiler, and then copies the necessary parts into
the `initrd` directory.

There are still dependencies on the build system's coreutils in
`/bin` and `/usr/bin/`, but any problems should be detectable if you
end up with a different hash than the official builds.

The various components that are downloaded are in the `./modules`
directory and include:

* [musl-libc](https://www.musl-libc.org/)
* [busybox](https://busybox.net/)
* [kexec](https://wiki.archlinux.org/index.php/kexec)
* [mbedtls](https://tls.mbed.org/)
* [tpmtotp](https://trmm.net/Tpmtotp)
* [coreboot](https://www.coreboot.org/)
* [cryptsetup](https://gitlab.com/cryptsetup/cryptsetup)
* [lvm2](https://sourceware.org/lvm2/)
* [gnupg](https://www.gnupg.org/)
* [Linux kernel](https://kernel.org)

We also recommend installing [Qubes OS](https://www.qubes-os.org/),
although there Heads can `kexec` into any Linux or
[multiboot](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html)
kernel.

### Notes

* Building coreboot's cross compilers can take a while.  Luckily this is only done once.
* Builds are finally reproducible! The [reproduciblebuilds tag](https://github.com/osresearch/heads/issues?q=is%3Aopen+is%3Aissue+milestone%3Areproduciblebuilds) tracks any regressions.
* Currently only tested in QEMU, the Thinkpad x230, Librem series and the Chell Chromebook.
** Xen does not work in QEMU.  Signing, HOTP, and TOTP do work; see below.
* Building for the Lenovo X220 requires binary blobs to be placed in the blobs/x220/ folder.
See the readme.md file in that folder
* Building for the Librem 13 v2/v3 or Librem 15 v3/v4 requires binary blobs to be placed in
the blobs/librem_skl folder. See the readme.md file in that folder

### QEMU

OS booting can be tested in QEMU using a software TPM.  HOTP can be tested by forwarding a USB token from the host to the guest.

For more information and setup instructions, refer to the [qemu documentation](doc/qemu.md).

### coreboot console messages

The coreboot console messages are stored in the CBMEM region
and can be read by the Linux payload with the `cbmem --console | less`
command.  There is lots of interesting data about the state of the
system.
