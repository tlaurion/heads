# BusyBox vs util-linux / coreutils Differences

This document captures the differences between BusyBox v1.36.1 applet implementations
and their GNU coreutils / util-linux counterparts, relevant to Heads development.

BusyBox is a multi-call binary providing simplified versions of standard Unix utilities.
Many applets have reduced option sets, missing features, or behavioral differences.

## Stub / No-op Applets

These commands exist but have minimal or no implementation:

| Command   | Status           | Notes                              |
|-----------|------------------|------------------------------------|
| `ascii`   | No help available | No functionality                   |
| `lsscsi`  | No help available | No functionality                   |
| `lsusb`   | No help available | No functionality                   |
| `tree`    | No help available | No functionality                   |

## Notable Behavioral Differences

### Shell Builtins vs External Commands

| Command | Difference | Impact |
|---------|-------------|--------|
| `[`     | BusyBox ash builtin; syntax errors differ from bash | `[` with missing `]` gives `[: missing ']'` error |
| `[[`    | BusyBox ash does NOT support `[[` (bash extension) | Use `[` or `test` instead; `[[` gives `missing ]]` error |
| `kill`  | Shell builtin with different syntax than /bin/kill | BusyBox `kill` builtin supports `-l`, `-n`, `-s` flags; external `kill` has simpler usage |
| `printf` | Shell builtin; differs from coreutils printf | Supports `%(fmt)T` for date formatting (bash extension) |
| `pwd`    | Shell builtin in ash | Same behavior as GNU pwd with `-L`/`-P` flags |
| `test`   | Shell builtin (same as `[`) | Identical to `[` applet |

### cttyhack

BusyBox-specific utility not present in standard Linux distributions:

```
cttyhack [PROG ARGS]
```

- Gives PROG a controlling tty if possible
- Used in Heads for recovery shell and boot script on serial consoles
- **Usage in init scripts**: `cttyhack /bin/bash` or `setsid cttyhack sh`
- **No equivalent in util-linux or coreutils**

## Commands with Significantly Reduced Option Sets

### awk
- **Missing**: `-i` (include file), advanced gawk features
- **Has**: `-v`, `-F`, `-f`, `-e` (basic awk functionality)

### base32
- **Missing**: `--wrap` long option style, `--decode`
- **Has**: `-d` (decode), `-w` (wrap width)

### cp
- **Missing**: `--preserve`, `--no-dereference`, `--parents`, `--verbose` long options
- **Has**: `-a` (archive), `-R`/`-r` (recursive), `-d`/`-P` (preserve links), `-p` (preserve attributes)

### cut
- **BusyBox addition**: `-D` (don't sort/collate), `-O` (output delimiter)
- **Missing**: `--complement`, `--output-delimiter` long options
- **Has**: `-b`, `-c`, `-d`, `-f`, `-s` (standard options)

### date
- **Missing**: Many GNU `date` format specifiers and `--date`, `--file`, `--rfc-email` options
- **Has**: `-u`, `-d` (display TIME), `-D` (strptime format), `-r` (file mtime), `-R` (RFC-2822), `-I` (ISO-8601)
- **Note**: `%N` (nanoseconds) support may be limited

### dd
- **Missing**: `conv=` options like `excl`, `nocreat`, `notrunc` (partial - has `notrunc`, `noerror`, `sync`, `fsync`, `swab`)
- **Has**: Standard `if=`, `of=`, `bs=`, `count=`, `skip=`, `seek=` with `iflag=`/`oflag=` support
- **Note**: `status=noxfer` and `status=none` supported (newer addition)

### df
- **Missing**: `--total`, `--direct`, `--exclude-type` long options
- **Has**: `-P` (POSIX), `-h` (human), `-T` (type), `-t` (filter type), `-i` (inodes), `-B` (blocksize)

### diff
- **BusyBox limitation**: Only unified diffs (`-U`) are supported
- **Missing**: `-y` (side-by-side), `--ignore-file-name-case`, `--suppress-common-lines`
- **Has**: `-a`, `-b`, `-B`, `-d`, `-i`, `-L`, `-N`, `-q`, `-r`, `-S`, `-T`, `-s`, `-t`, `-U`, `-w`

### du
- **Missing**: `--apparent-size`, `--threshold`, `--exclude` long options
- **Has**: `-a`, `-b` (apparent), `-L`, `-H`, `-d` (max depth), `-c`, `-l`, `-s`, `-x`, `-h`, `-m`, `-k`

### find
- **Missing**: `-perm` octal mode syntax differences, `-context`, `-printf`, `-execdir`, `-okdir`
- **Has**: Standard `-name`, `-type`, `-exec`, `-delete`, `-prune`, `-path`, `-regex`, `-user`, `-group`, `-size`, `-mtime`, etc.
- **Note**: `-regex` uses basic regex by default (not GNU extended)

### getopt
- **Missing**: Some GNU getopt features; enhanced mode available with `-o`, `-l`, `-n`, `-q`, `-Q`, `-s`, `-T`, `-u`
- **Note**: BusyBox `getopt` is enhanced version, not fully GNU-compatible

### grep
- **Missing**: `--color`, `--exclude`, `--include`, `--exclude-dir`, `--binary-files`, `--null`, `--line-buffered`
- **Has**: `-H`, `-h`, `-n`, `-l`, `-L`, `-c`, `-o`, `-q`, `-v`, `-s`, `-r`, `-R`, `-i`, `-w`, `-x`, `-F`, `-E`, `-m`, `-A`, `-B`, `-C`, `-e`, `-f`

### hexdump
- **Missing**: Some format specifiers; `-e` format string syntax is simplified
- **Has**: `-b`, `-c`, `-d`, `-o`, `-x`, `-C` (hex+ASCII), `-v`, `-e`, `-f`, `-n`, `-s`

### id
- **Missing**: `--zero`, `--context` (SELinux)
- **Has**: `-u`, `-g`, `-G`, `-n`, `-r`

### install
- **Missing**: `-D` parent dir creation is BusyBox-specific; missing `--backup`, `--compare`, `--strip-program`
- **Has**: `-c` (default), `-d` (dirs), `-s` (strip), `-p` (preserve), `-o`, `-g`, `-m`, `-t`, `-b`, `-S`

### killall
- **Missing**: `-I` (ignore case), `-q` only suppresses "no processes" msg (limited)
- **Has**: `-l` (list signals), `-q` (quiet)

### ls
- **Missing**: `--color` long option (`--color` works), `--author`, `--escape`, `--indicator-style`, `--time-style`
- **Has**: `-1`, `-a`, `-A`, `-x`, `-d`, `-L`, `-H`, `-R`, `-p`, `-F`, `-l`, `-i`, `-n`, `-s`, `-h`, `-S`, `-X`, `-v`, `-t`, `-r`, `-w`, `--full-time`, `--group-directories-first`

### lsattr/chattr
- **Has**: Standard ext2 attributes (`-R`, `-v`, `-p`, `+-=[AacDdijsStTu]`)
- **Missing**: Some newer ext4 attributes may not be supported

### mount
- **Missing**: Many filesystem-specific mount options, `--bind`, `--move`, `--types` long options
- **Has**: `-a`, `-f`, `-v`, `-r`, `-t`, `-T`, `-O`, plus standard `-o` options
- **Note**: Loop device autodetection is built-in (no need for `-o loop`)

### nc (netcat)
- **BusyBox has**: `-l` (listen), `-p` (port), `-w` (timeout), `-i` (interval), `-f` (file instead of network), `-e` (prog)
- **Missing**: Many OpenBSD/GNU netcat features

### patch
- **Missing**: `--backup`, `--forward`, `--fuzz`, `--ignore-whitespace`, `--reject-file`
- **Has**: `-R` (reverse), `-N` (ignore applied), `-E` (remove empty), `--dry-run`

### ps
- **Missing**: Many BSD/GNU ps options (`-eo`, `-L`, complex format specifiers)
- **Has**: `w` (wide), `l` (long), `T` (threads)
- **Note**: Very simplified process listing

### sed
- **Missing**: Some GNU sed extensions (`--follow-symlinks`, `--sandbox`, `e` command, `R` command)
- **Has**: `-e`, `-f`, `-i` (in-place), `-n`, `-r`/`-E` (extended regex)

### setpriv
- **Missing**: Most util-linux `setpriv` features
- **Has**: `-d` (dump), `--nnp`/`--no-new-privs`, `--inh-caps`, `--ambient-caps`

### sort
- **Missing**: `--parallel`, `--files0-from`, `--compress-program`
- **Has**: `-n`, `-g`, `-h`, `-M`, `-V`, `-t`, `-k`, `-r`, `-s`, `-u`, `-z`, `-b`, `-f`, `-i`, `-d`, `-c`, `-o`

### stat
- **Missing**: `--file-system` long option (`-f` works), `--printf`, `--dereference`
- **Has**: `-c` (format), `-f` (filesystem), `-L` (follow), `-t` (terse)
- **Note**: Format sequences are supported (`%a`, `%A`, `%b`, etc.)

### tar
- **Missing**: Many GNU tar features (`--acls`, `--selinux`, `--xattrs`, `--transform`, `--strip-components` long form)
- **Has**: `-c`/`-x`/`-t`, `-z`/`-j`/`-J`/`-a`, `-f`, `-C`, `-v`, `-O`, `-m`, `-o`, `-k`, `-h`, `-T`, `-X`, `--exclude`, `--overwrite`, `--strip-components`, `--numeric-owner`, `--no-recursion`, `--to-command`

### top
- **Missing**: Many procps top features (batch mode limitations, configurable fields)
- **Has**: `-b` (batch), `-n` (iterations), `-d` (delay), `-m` (memory), `-H` (threads)
- **Interactive**: `N`/`M`/`P`/`T` sort, `S` (memory), `R` (reverse), `H` (threads), `Q` (quit)

### uname
- **Missing**: `-p` (processor) and `-i` (platform) may return "unknown" on some systems
- **Has**: `-a`, `-m`, `-n`, `-r`, `-s`, `-v`, `-i`, `-o`, `-p`

### wget
- **Missing**: HTTPS support unless `CONFIG_SSL_CLIENT` is enabled, `--continue` long form (`-c` works), `--background`, `--execute`, `--server-response` long form
- **Has**: `-c` (continue), `-q` (quiet), `-P` (dir), `-S` (server response), `-T` (timeout), `-O` (output), `-o` (log), `-U` (user-agent), `-Y` (proxy), `--spider`, `--header`, `--post-data`, `--post-file`

### xargs
- **Missing**: `--max-args`, `--max-lines`, `--interactive` long forms
- **Has**: `-0`, `-a`, `-o`, `-r`, `-t`, `-p`, `-E`, `-I`, `-n`, `-s`, `-P`, `-x`

## Key Takeaways for Heads Development

1. **No `[[` support**: BusyBox ash does not support `[[` (bash extension). Use `[` or `test`.
2. **`cttyhack` is BusyBox-specific**: No equivalent in standard distros; used for TTY control in init scripts.
3. **`tree` is a stub**: If directory tree visualization is needed, use `find` with formatting.
4. **`lsscsi` and `lsusb` are stubs**: USB/SCSI detection must use `/sys` or other methods.
5. **Simplified `ps`**: Only basic process listing; use `/proc` directly for detailed info.
6. **GNU long options**: Many commands lack GNU-style `--long-options`; use short options.
7. **`wget` SSL support**: Depends on `CONFIG_SSL_CLIENT` build option.
8. **`find -regex`**: Uses basic regex syntax, not GNU extended regex.
9. **`sed -i`**: Supports in-place editing but may have different backup suffix behavior.
10. **`date` format strings**: Limited compared to GNU date; test format specifiers before use.
