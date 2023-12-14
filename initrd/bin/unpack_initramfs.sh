#! /bin/bash
set -e -o pipefail

. /etc/functions

TRACE "Under unpack_initramfs.sh"
# Unpack a Linux initramfs archive.
#
# In general, the initramfs archive is one or more cpio archives, optionally
# compressed, concatenated together.  Uncompressed and compressed segments can
# exist in the same file.  Zero bytes between segments are skipped.  To properly
# unpack such an archive, all segments must be unpacked.
#
# This script unpacks such an archive, but with a limitation that once a
# compressed segment is reached, no more segments can be read.  This works for
# common initrds on x86, where the microcode must be stored in an initial
# uncompressed segment, followed by the "real" initramfs content which is
# usually in one compressed segment.
#
# The limitation comes from gunzip/unzstd, there's no way to prevent them from
# consuming trailing data or tell us the member/frame length.  The script
# succeeds with whatever was extracted, since this is used to extract particular
# files and boot can proceed as long as those files were found.

# Usage: unpack_initramfs.sh <initramfs archive> <destination directory> [cpio args]
#  initramfs archive: path to the initramfs archive
#  destination directory: directory to unpack the archive to
#  cpio args: optional arguments to pass to cpio, e.g. --no-absolute-filenames
#  	 (see cpio(1) for more details)
if [ $# -lt 2 ]; then
    die "Usage: $0 <initramfs archive> <destination directory> [cpio args]"
fi

INITRAMFS_ARCHIVE="$1"
DEST_DIR="$2"
shift
shift
# rest of args go to cpio, can specify filename patterns
CPIO_ARGS=("$@")

# Consume zero bytes, the first nonzero byte read (if any) is repeated on stdout
consume_zeros() {
    TRACE "Under unpack_initramfs.sh:consume_zeros"
    next_byte='00'
    while [ "$next_byte" = "00" ]; do
        # if we reach EOF, next_byte becomes empty (dd does not fail)
        next_byte="$(dd bs=1 count=1 status=none | xxd -p | tr -d ' ')"
    done
    # if we finished due to nonzero byte (not EOF), then carry that byte
    if [ -n "$next_byte" ]; then
        echo -n "$next_byte" | xxd -p -r
    fi
}

unpack_cpio() {
    TRACE "Under unpack_initramfs.sh:unpack_cpio"
    (cd "$dest_dir"; cpio -i "${CPIO_ARGS[@]}" 2>/dev/null)
}

# unpack the first segment of an archive, then write the rest to another file
unpack_first_segment() {
    TRACE "Under unpack_initramfs.sh:unpack_first_segment"
    unpack_archive="$1"
    dest_dir="$2"
    rest_archive="$3"

    mkdir -p "$dest_dir"

    # peek the beginning of the file to determine what type of content is next
    magic="$(dd if="$unpack_archive" bs=6 count=1 status=none | xxd -p)"

    # read this segment of the archive, then write the rest to the next file
    (
        # Magic values correspond to Linux init/initramfs.c (zero, cpio) and
        # lib/decompress.c (gzip)
        case "$magic" in
            00*)
                DEBUG "archive segment $magic: uncompressed cpio"
                # Skip zero bytes and copy the first nonzero byte
                consume_zeros
                # Copy the remaining data
                cat
                ;;
            303730373031*|303730373032*)    # plain cpio
                DEBUG "archive segment $magic: plain cpio"
                # Unpack the plain cpio, this stops reading after the trailer
                unpack_cpio
                # Copy the remaining data
                cat
                ;;
            1f8b*|1f9e*)    # gzip
                DEBUG "archive segment $magic: gzip"
                # gunzip won't stop when reaching the end of the gzipped member,
                # so we can't read another segment after this.  We can't
                # reasonably determine the member length either, this requires
                # walking all the compressed blocks.
                gunzip | unpack_cpio
                ;;
            28b5*)  # zstd
                DEBUG "archive segment $magic: zstd"
                # Like gunzip, this will not stop when reaching the end of the
                # frame, and determining the frame length requires walking all
                # of its blocks.
                (zstd-decompress -d || true) | unpack_cpio
                ;;
            *)  # unknown
                die "Can't decompress initramfs archive, unknown type: $magic"
                ;;
        esac
    ) <"$unpack_archive" >"$rest_archive"

    orig_size="$(stat -c %s "$unpack_archive")"
    rest_size="$(stat -c %s "$rest_archive")"
    DEBUG "archive segment $magic: $((orig_size - rest_size)) bytes"
}

DEBUG "Unpacking $INITRAMFS_ARCHIVE to $DEST_DIR"

next_archive="$INITRAMFS_ARCHIVE"
rest_archive="/tmp/unpack_initramfs_rest"

# Break when there is no remaining data
while [ -s "$next_archive" ]; do
    unpack_first_segment "$next_archive" "$DEST_DIR" "$rest_archive"
    next_archive="/tmp/unpack_initramfs_next"
    mv "$rest_archive" "$next_archive"
done
