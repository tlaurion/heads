# Star Labs builds

Star Labs Cezanne boards require the maintained AMD binary tree in addition to
the files carried by the Heads tree. The binary tree is not committed here.

Mount the maintained tree read-only at the build path before configuring or
building either Cezanne target:

```sh
mkdir -p build/x86/amd_binaries
mount --bind /path/to/starlabs/amd_binaries build/x86/amd_binaries
mount -o remount,bind,ro build/x86/amd_binaries
```

The mounted tree must contain the paths listed in
`config/starlabs-amd-binaries.sha256`, including:

```text
CZN/APCB/
CZN/PSP/
FSP/CEZANNE_M.fd
FSP/CEZANNE_S.fd
```

The build verifies the mounted files against
`config/starlabs-amd-binaries.sha256` before coreboot configuration and build
steps run. Update that manifest when the maintained binary input changes.
