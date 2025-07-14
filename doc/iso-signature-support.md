# Enhanced ISO Detached Signature Support

This document describes the enhanced detached signature support for ISO boot in Heads.

## Overview

The `kexec-iso-init` script has been enhanced to support a wider variety of detached signature formats commonly used by major Linux distributions. This improvement provides better compatibility with ISOs from different distributions while maintaining backward compatibility with existing signature formats.

## Supported Signature Patterns

### Direct ISO Signatures

The script now attempts to verify ISO signatures using the following patterns (in order of preference):

1. `<iso_file>.sig` - Standard binary signature format (used by Arch Linux, Fedora, etc.)
2. `<iso_file>.asc` - ASCII armored signature (used by openSUSE, Debian, etc.)
3. `<iso_file>.gpg` - Binary GPG signature (sometimes used)
4. `<iso_name_without_extension>.sig` - Signature file with same base name
5. `<iso_name_without_extension>.asc` - ASCII signature with same base name

### Checksum-based Signatures

If direct ISO signature verification fails, the script attempts checksum-based verification:

1. Looks for common checksum files:
   - `SHA256SUMS`
   - `SHA256SUMS.txt`
   - `sha256sum.txt`
   - `CHECKSUM`
   - `<iso_name_without_extension>.sha256`
   - `checksums.txt`

2. For each checksum file found, looks for corresponding signature files:
   - `<checksum_file>.sig`
   - `<checksum_file>.asc`
   - `<checksum_file>.gpg`

3. Verifies the checksum file signature, then verifies the ISO against the checksums

## Distribution Examples

### Arch Linux
- ISO: `archlinux-2023.12.01-x86_64.iso`
- Signature: `archlinux-2023.12.01-x86_64.iso.sig`

### Fedora
- ISO: `Fedora-Workstation-Live-x86_64-39-1.5.iso`
- Signature: `Fedora-Workstation-Live-x86_64-39-1.5.iso.sig`

### Debian
- ISO: `debian-12.2.0-amd64-netinst.iso`
- Signature: `debian-12.2.0-amd64-netinst.iso.asc`

### Ubuntu (checksum-based)
- ISO: `ubuntu-22.04.3-desktop-amd64.iso`
- Checksum: `SHA256SUMS`
- Signature: `SHA256SUMS.gpg`

### openSUSE
- ISO: `openSUSE-Leap-15.5-DVD-x86_64.iso`
- Signature: `openSUSE-Leap-15.5-DVD-x86_64.iso.asc`

## GPG Keyring

All signature verifications use the GPG keyring located at `/etc/distro/`. Distribution public keys should be added to this keyring for verification to succeed.

See [Distribution Keys Documentation](distro-keys.md) for information about obtaining and adding distribution public keys.

## Error Handling

The enhanced script provides better error reporting:

- Lists all signature files that were attempted
- Shows specific GPG verification errors when debug mode is enabled
- Provides clear indication of which signature file was used for successful verification

## Debug Information

When debug mode is enabled (`CONFIG_DEBUG_OUTPUT=y`), the script outputs detailed information about:

- Which signature files are being tried
- GPG verification error messages
- Checksum verification attempts
- File paths and detection results

## Backward Compatibility

The enhanced functionality maintains complete backward compatibility with existing signature formats. Systems using the original `.sig` and `.asc` patterns will continue to work without modification.

## Usage

No changes are required for end users. The script automatically detects and uses the appropriate signature format for the given ISO file.