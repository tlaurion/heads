# Distribution Public Keys for ISO Signature Verification

This document provides information about obtaining and adding official GPG public keys for major Linux distributions to enable ISO signature verification in Heads.

## Overview

The enhanced `kexec-iso-init` script supports verifying ISO signatures from major Linux distributions. To enable this verification, you need to add the official GPG public keys used by these distributions to the `/etc/distro/keys/` directory.

## Currently Supported Distributions

### Arch Linux
- **Key already included**: `archlinux.key` (Pierre Schmitz)
- **Key ID**: 3E80CA1A8B89F69CBA57D98A76A5EF905444 9A5C
- **Used for**: Direct ISO signature verification (`.sig` files)

### Tails
- **Key already included**: `tails.key` (Tails developers)
- **Key ID**: A490D0F4D311A4153E2BB7CADBBB02B258ACD84F
- **Used for**: Direct ISO signature verification (`.sig` files)

### Qubes OS
- **Keys already included**: Multiple Qubes signing keys
- **Used for**: Direct ISO signature verification (`.sig` files)

## Distribution Keys To Add

### Debian
- **Official page**: https://www.debian.org/CD/verify
- **Key ID**: 64E6EA7D
- **Download**: `wget -O debian.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x64E6EA7D`
- **Used for**: Checksum file verification (`SHA256SUMS.sign`)

### Ubuntu
- **Official page**: https://help.ubuntu.com/community/VerifyIsoHowto
- **Key ID**: 843938DF228D22F7B3742BC0D94AA3F0EFE21092
- **Download**: `wget -O ubuntu.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x843938DF228D22F7B3742BC0D94AA3F0EFE21092`
- **Used for**: Checksum file verification (`SHA256SUMS.gpg`)

### Fedora
- **Official page**: https://fedoraproject.org/security/
- **Key ID**: 38AB71F4
- **Download**: `wget -O fedora.key https://fedoraproject.org/fedora.gpg`
- **Used for**: Direct ISO signature verification (`.sig` files)

### openSUSE
- **Official page**: https://en.opensuse.org/openSUSE:Build_Service_Signing
- **Key ID**: 3DBDC284
- **Download**: `wget -O opensuse.key https://build.opensuse.org/projects/openSUSE:Factory/public_key`
- **Used for**: Direct ISO signature verification (`.asc` files)

### CentOS
- **Official page**: https://www.centos.org/keys/
- **Key ID**: 05B555B3
- **Download**: `wget -O centos.key https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Linux Mint
- **Official page**: https://linuxmint.com/verify.php
- **Key ID**: 27DEB15644C6B3CF
- **Download**: `wget -O mint.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x27DEB15644C6B3CF`
- **Used for**: Checksum file verification (`sha256sum.txt.gpg`)

### Manjaro
- **Official page**: https://manjaro.org/downloads/official/
- **Key ID**: 11C7F07E
- **Download**: `wget -O manjaro.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x11C7F07E`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Elementary OS
- **Official page**: https://elementary.io/
- **Key ID**: 204DD8AEC33A7AFF
- **Download**: `wget -O elementary.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Pop!_OS
- **Official page**: https://pop.system76.com/
- **Key ID**: 204DD8AEC33A7AFF
- **Download**: `wget -O popos.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Kali Linux
- **Official page**: https://www.kali.org/docs/introduction/download-official-kali-linux-images/
- **Key ID**: 44C6513A8E4FB3D3
- **Download**: `wget -O kali.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x44C6513A8E4FB3D3`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Alpine Linux
- **Official page**: https://alpinelinux.org/keys/
- **Key ID**: 0482D84022F52DF1
- **Download**: `wget -O alpine.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0482D84022F52DF1`
- **Used for**: Direct ISO signature verification (`.asc` files)

### Gentoo
- **Official page**: https://www.gentoo.org/downloads/signatures/
- **Key ID**: 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910
- **Download**: `wget -O gentoo.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x13EBBDBEDE7A12775DFDB1BABB572E0E2D182910`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Void Linux
- **Official page**: https://voidlinux.org/download/
- **Key ID**: 307EA4CBAB8FBE56
- **Download**: `wget -O void.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x307EA4CBAB8FBE56`
- **Used for**: Direct ISO signature verification (`.sig` files)

### NixOS
- **Official page**: https://nixos.org/download.html
- **Key ID**: B541D55301270E0BCF15CA5D8170B4726D7198DE
- **Download**: `wget -O nixos.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB541D55301270E0BCF15CA5D8170B4726D7198DE`
- **Used for**: Direct ISO signature verification (`.sig` files)

### EndeavourOS
- **Official page**: https://endeavouros.com/
- **Key ID**: 003DB8B0CB23504F
- **Download**: `wget -O endeavouros.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x003DB8B0CB23504F`
- **Used for**: Direct ISO signature verification (`.sig` files)

### Zorin OS
- **Official page**: https://zorin.com/os/
- **Key ID**: 2BED339A87A1C2F4
- **Download**: `wget -O zorin.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2BED339A87A1C2F4`
- **Used for**: Direct ISO signature verification (`.sig` files)

### MX Linux
- **Official page**: https://mxlinux.org/download-links/
- **Key ID**: 03872F78
- **Download**: `wget -O mxlinux.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x03872F78`
- **Used for**: Direct ISO signature verification (`.sig` files)

### SUSE Linux Enterprise
- **Official page**: https://www.suse.com/download/
- **Key ID**: 39DB7C82
- **Download**: `wget -O sle.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x39DB7C82`
- **Used for**: Direct ISO signature verification (`.asc` files)

### Rocky Linux
- **Official page**: https://rockylinux.org/download/
- **Key ID**: 15AF5DAC6D745A60
- **Download**: `wget -O rocky.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x15AF5DAC6D745A60`
- **Used for**: Direct ISO signature verification (`.sig` files)

### AlmaLinux
- **Official page**: https://almalinux.org/
- **Key ID**: 51D6647EC21AD6EA
- **Download**: `wget -O alma.key https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x51D6647EC21AD6EA`
- **Used for**: Direct ISO signature verification (`.sig` files)

## Adding Keys Manually

1. Download the public key from the official source
2. Copy the key file to `/etc/distro/keys/`
3. The key will be automatically imported by the `key-init` script

## Automated Key Addition

Use the provided script to automatically download and add keys:

```bash
./add-distro-keys.sh [distribution-name]
```

## Verification

After adding keys, you can verify they were imported correctly:

```bash
gpg --homedir=/etc/distro/ --list-keys
```

## Security Notes

- Always verify key fingerprints against official sources
- Keys should be obtained from official distribution websites or keyservers
- Be cautious of key expiration dates and updates
- Some distributions may update their signing keys periodically

## See Also

- [Enhanced ISO Signature Support](iso-signature-support.md)
- [Heads FAQ](../FAQ.md)
- [Distribution-specific documentation](https://osresearch.net)