# Distribution Public Keys

This directory contains GPG public keys for various Linux distributions used to verify ISO signatures.

## Currently Available Keys

- `archlinux.key` - Arch Linux release signing key (Pierre Schmitz)
- `tails.key` - Tails developers signing key  
- `qubes-*.key` - Qubes OS signing keys

## Adding Distribution Keys

To add keys for other distributions, download the official GPG public keys from the distribution's official website or keyserver and place them in this directory.

### Common Distribution Keys to Add

1. **Ubuntu**: Ubuntu CD Image Signing Key
   - Key ID: 843938DF228D22F7B3742BC0D94AA3F0EFE21092
   - Download from: https://keyserver.ubuntu.com/

2. **Debian**: Debian CD signing key
   - Key ID: 64E6EA7D
   - Download from: https://www.debian.org/CD/verify

3. **Fedora**: Fedora release signing key
   - Key ID: 38AB71F4
   - Download from: https://fedoraproject.org/fedora.gpg

4. **openSUSE**: openSUSE project signing key
   - Key ID: 3DBDC284
   - Download from: https://build.opensuse.org/projects/openSUSE:Factory/public_key

5. **CentOS**: CentOS official signing key
   - Key ID: 05B555B3
   - Download from: https://www.centos.org/keys/

6. **Linux Mint**: Linux Mint signing key
   - Key ID: 27DEB15644C6B3CF

7. **Manjaro**: Manjaro signing key
   - Key ID: 11C7F07E

8. **Elementary OS**: Elementary OS signing key
   - Key ID: 204DD8AEC33A7AFF

9. **Kali Linux**: Kali Linux signing key
   - Key ID: 44C6513A8E4FB3D3

10. **Alpine Linux**: Alpine Linux signing key
    - Key ID: 0482D84022F52DF1

## Usage

Keys placed in this directory are automatically imported by the `key-init` script and trusted for ISO signature verification.

## Security Notes

- Always verify key fingerprints against official sources
- Only add keys from trusted, official distribution sources
- Keys should be in ASCII-armored format (.key or .asc files)
- Remove any keys you don't need to minimize attack surface

## Automated Key Addition

Use the provided script to automatically download and add keys:

```bash
/bin/add-distro-keys.sh [distribution-name|all]
```

See `../../../doc/distro-keys.md` for detailed information about distribution keys and how to obtain them.