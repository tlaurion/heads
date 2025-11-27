#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Validate that CBFS size fits within IFD BIOS region
# and report space usage statistics

set -e

usage() {
    cat <<EOF
Usage: $0 --coreboot-dir <path> --board-dir <path> --config <path> [--fix]

Validates that CONFIG_CBFS_SIZE from coreboot config matches the BIOS region
size reported by the Intel Flash Descriptor (IFD), and provides space usage
statistics from cbfstool.

Options:
  --coreboot-dir  Path to coreboot build directory
  --board-dir     Path to board build directory  
  --config        Path to coreboot config file
  --fix           Automatically fix CONFIG_CBFS_SIZE to match IFD BIOS region
  --help          Show this help message

Exit codes:
  0: Validation passed (or fix applied successfully, or tools not available yet)
  1: Validation failed - CONFIG_CBFS_SIZE exceeds IFD BIOS region
EOF
    exit "${1:-0}"
}

# Parse arguments
FIX_MODE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --coreboot-dir)
            COREBOOT_DIR="$2"
            shift 2
            ;;
        --board-dir)
            BOARD_DIR="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --fix)
            FIX_MODE=1
            shift
            ;;
        --help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$COREBOOT_DIR" ] || [ -z "$BOARD_DIR" ] || [ -z "$CONFIG_FILE" ]; then
    echo "Error: Missing required arguments" >&2
    usage 1
fi

# Check if tools exist
CBFSTOOL="$COREBOOT_DIR/cbfstool"
IFDTOOL="$COREBOOT_DIR/util/ifdtool/ifdtool"

if [ ! -x "$CBFSTOOL" ]; then
    echo "Warning: cbfstool not found at $CBFSTOOL" >&2
    echo "Skipping CBFS analysis (coreboot not built yet)" >&2
    CBFSTOOL=""
fi

if [ ! -x "$IFDTOOL" ]; then
    echo "Warning: ifdtool not found at $IFDTOOL" >&2
    echo "Skipping IFD validation (coreboot not built yet)" >&2
    IFDTOOL=""
fi

# Extract CONFIG_CBFS_SIZE from config
CBFS_SIZE=$(grep "^CONFIG_CBFS_SIZE=" "$CONFIG_FILE" | cut -d= -f2)
if [ -z "$CBFS_SIZE" ]; then
    echo "Error: CONFIG_CBFS_SIZE not found in $CONFIG_FILE" >&2
    exit 1
fi

# Convert to decimal
CBFS_SIZE_DEC=$((CBFS_SIZE))

# Extract IFD path from config
IFD_PATH=$(grep "^CONFIG_IFD_BIN_PATH=" "$CONFIG_FILE" | cut -d'"' -f2)

# Resolve relative IFD path to absolute, preferring coreboot base dir
if [ -n "$IFD_PATH" ] && [[ "$IFD_PATH" != /* ]] && [[ "$IFD_PATH" != *"@"* ]]; then
    COREBOOT_BASE_DIR="$(dirname "$COREBOOT_DIR")"
    if [ -d "$COREBOOT_BASE_DIR" ]; then
        IFD_PATH="$COREBOOT_BASE_DIR/$IFD_PATH"
    else
        IFD_PATH="$PWD/$IFD_PATH"
    fi
fi

# If IFD path uses @BLOB_DIR@, resolve it
# @BLOB_DIR@ typically expands to blobs/ from the repo root
if [[ "$IFD_PATH" == *"@BLOB_DIR@"* ]]; then
    # Try to find the Heads repo root (go up from coreboot-dir)
    # COREBOOT_DIR is like /home/user/heads/build/x86/coreboot-25.09/BOARD
    # So we need to go up 4 levels: BOARD -> coreboot-25.09 -> x86 -> build -> heads
    if [ -d "$COREBOOT_DIR" ]; then
        REPO_ROOT=$(cd "$COREBOOT_DIR/../../../../" 2>/dev/null && pwd || echo "")
        if [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/blobs" ]; then
            IFD_PATH="${IFD_PATH/@BLOB_DIR@/$REPO_ROOT/blobs}"
        fi
    fi
fi

# If IFD path uses @BLOB_DIR@, we need to resolve it
# For now, skip validation if no IFD or if path is not resolved
if [ -z "$IFD_PATH" ] || [[ "$IFD_PATH" == *"@"* ]]; then
    # Try to find the IFD in the coreboot build
    BUILD_IFD="$COREBOOT_DIR/flashmap_descriptor.bin"
    if [ ! -f "$BUILD_IFD" ]; then
        echo "Info: No IFD validation possible (CONFIG_IFD_BIN_PATH=$IFD_PATH, build IFD not found)"
        echo "Skipping IFD vs CBFS size validation"
        IFD_VALIDATION_SKIPPED=1
        # Still report CBFS space usage even without IFD
        if [ -n "$CBFSTOOL" ] && [ -f "$COREBOOT_DIR/coreboot.rom" ]; then
            echo ""
            CBFS_OUTPUT=$("$CBFSTOOL" "$COREBOOT_DIR/coreboot.rom" print 2>&1 || true)
            FREE_BYTES=$(echo "$CBFS_OUTPUT" | awk '/\(empty\)/ {sum += $4} END {print sum+0}')
            FREE_KB=$((FREE_BYTES / 1024))
            echo "CBFS configured size: $CBFS_SIZE ($CBFS_SIZE_DEC bytes)"
            echo "CBFS Free Space: $FREE_BYTES bytes ($FREE_KB KiB)"
            echo ""
        fi
    else
        IFD_PATH="$BUILD_IFD"
    fi
fi

# Perform IFD validation if we have a path
if [ -z "$IFD_VALIDATION_SKIPPED" ] && [ -f "$IFD_PATH" ] && [ -n "$IFDTOOL" ]; then
    echo "==================================================================="
    echo "IFD vs CBFS Size Validation"
    echo "==================================================================="
    
    # Get BIOS region from IFD - try different platform versions
    # Try without platform flag first (auto-detect), then try all known versions
    IFD_OUTPUT=$("$IFDTOOL" -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform ifd2 -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform ifd1 -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform sklkbl -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform aplk -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform cnl -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform lbg -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform icl -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform tgl -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform adl -d "$IFD_PATH" 2>/dev/null || \
                 "$IFDTOOL" --platform mtl -d "$IFD_PATH" 2>/dev/null || \
                 true)
    
    if [ -n "$IFD_OUTPUT" ]; then
        # Extract BIOS region line (Flash Region 1)
        BIOS_REGION=$(echo "$IFD_OUTPUT" | grep "Flash Region 1 (BIOS):" | head -1)
        
        if [ -n "$BIOS_REGION" ]; then
            # Parse start and end addresses - format is "00021000 - 00bfffff"
            BIOS_START=$(echo "$BIOS_REGION" | awk '{print $(NF-2)}')
            BIOS_END=$(echo "$BIOS_REGION" | awk '{print $NF}')
            
            # Calculate BIOS region size
            BIOS_SIZE=$(( 0x$BIOS_END - 0x$BIOS_START + 1 ))
            
            echo "IFD BIOS Region: 0x$BIOS_START - 0x$BIOS_END"
            echo "IFD BIOS Size:   0x$(printf '%X' $BIOS_SIZE) ($BIOS_SIZE bytes)"
            echo "CONFIG_CBFS_SIZE: $CBFS_SIZE ($CBFS_SIZE_DEC bytes)"
            echo ""
            
            # Compare sizes
            if [ $CBFS_SIZE_DEC -gt $BIOS_SIZE ]; then
                OVERFLOW=$(( CBFS_SIZE_DEC - BIOS_SIZE ))
                
                if [ $FIX_MODE -eq 1 ]; then
                    echo "🔧 AUTO-FIX MODE: Updating CONFIG_CBFS_SIZE"
                    echo ""
                    echo "   Current CONFIG_CBFS_SIZE: 0x$(printf '%X' $CBFS_SIZE_DEC) ($CBFS_SIZE_DEC bytes)"
                    echo "   New CONFIG_CBFS_SIZE:     0x$(printf '%X' $BIOS_SIZE) ($BIOS_SIZE bytes)"
                    echo "   Reducing by: $OVERFLOW bytes (0x$(printf '%X' $OVERFLOW))"
                    echo ""
                    
                    # Update the config file
                    sed -i "s/CONFIG_CBFS_SIZE=0x[0-9A-Fa-f]*/CONFIG_CBFS_SIZE=0x$(printf '%X' $BIOS_SIZE)/" "$CONFIG_FILE"
                    
                    echo "✓ Updated $CONFIG_FILE"
                    echo "  New value: CONFIG_CBFS_SIZE=0x$(printf '%X' $BIOS_SIZE)"
                    echo ""
                    exit 0
                else
                    echo ""
                    echo "=================================================================="
                    echo "❌ VALIDATION FAILED: CONFIG_CBFS_SIZE exceeds IFD BIOS region!"
                    echo "=================================================================="
                    echo "   Overflow: $OVERFLOW bytes (0x$(printf '%X' $OVERFLOW))"
                    echo ""
                    echo "   Current CONFIG_CBFS_SIZE: 0x$(printf '%X' $CBFS_SIZE_DEC) ($CBFS_SIZE_DEC bytes)"
                    echo "   Maximum allowed (IFD):    0x$(printf '%X' $BIOS_SIZE) ($BIOS_SIZE bytes)"
                    echo ""
                    echo "   This will cause coreboot build failures or runtime issues."
                    echo "   CONFIG_CBFS_SIZE must be <= IFD BIOS region size."
                    echo ""
                    echo "To fix this issue, update CONFIG_CBFS_SIZE in:"
                    echo "   $CONFIG_FILE"
                    echo ""
                    echo "Set CONFIG_CBFS_SIZE=0x$(printf '%X' $BIOS_SIZE)"
                    echo ""
                    if [ -n "$BOARD" ]; then
                        echo "Or run: make BOARD=$BOARD fix_cbfs_ifd"
                        echo "Or (docker wrapper): ./docker_repro.sh make BOARD=$BOARD fix_cbfs_ifd"
                    else
                        echo "Or run: make BOARD=<board> fix_cbfs_ifd"
                    fi
                    echo "=================================================================="
                    echo ""
                    exit 1
                fi
            elif [ $CBFS_SIZE_DEC -eq $BIOS_SIZE ]; then
                echo "✓ CONFIG_CBFS_SIZE exactly matches IFD BIOS region size"
            else
                FREE_SPACE=$(( BIOS_SIZE - CBFS_SIZE_DEC ))
                echo "✓ CONFIG_CBFS_SIZE fits within IFD BIOS region"
                echo "   Free space in BIOS region: $FREE_SPACE bytes (0x$(printf '%X' $FREE_SPACE))"
            fi

            # CBFS space usage analysis (always report, even if zero)
            if [ -n "$CBFSTOOL" ] && [ -f "$COREBOOT_DIR/coreboot.rom" ]; then
                echo ""
                CBFS_OUTPUT=$("$CBFSTOOL" "$COREBOOT_DIR/coreboot.rom" print 2>&1 || true)
                
                # Sum all (empty) entry sizes; if none, treat as 0
                FREE_BYTES=$(echo "$CBFS_OUTPUT" | awk '/\(empty\)/ {sum += $4} END {print sum+0}')
                FREE_KB=$((FREE_BYTES / 1024))
                echo "CBFS Free Space: $FREE_BYTES bytes ($FREE_KB KiB)"
                
                # Show optimization opportunity only if BIOS region larger than configured CBFS
                if [ $CBFS_SIZE_DEC -lt $BIOS_SIZE ]; then
                    ADDITIONAL_SPACE=$(( BIOS_SIZE - CBFS_SIZE_DEC ))
                    ADDITIONAL_KB=$((ADDITIONAL_SPACE / 1024))
                    POTENTIAL_TOTAL=$((FREE_BYTES + ADDITIONAL_SPACE))
                    POTENTIAL_KB=$((POTENTIAL_TOTAL / 1024))
                    echo ""
                    echo "Optimization opportunity: CONFIG_CBFS_SIZE could be increased by"
                    echo "  $ADDITIONAL_SPACE bytes ($ADDITIONAL_KB KiB) to match IFD BIOS region"
                    echo "  This would provide $POTENTIAL_TOTAL bytes ($POTENTIAL_KB KiB) total free space"
                    echo ""
                    echo "To maximize CBFS size automatically, run:"
                    echo "  make BOARD=$BOARD fix_cbfs_ifd"
                fi
            fi
            
            echo ""
            VALIDATION_PERFORMED=1
        fi
    fi
fi

if [ "$VALIDATION_PERFORMED" = "1" ]; then
    echo "==================================================================="
    echo "✓ Validation complete"
    echo "==================================================================="
fi

exit 0
