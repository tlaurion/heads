#!/bin/sh
# pcr0-diag.sh - read-only PCR0 / Boot Guard provenance diagnostics
#
# READ-ONLY DIAGNOSTIC.  This script only reads CPU/MSR registers, TPM PCRs
# and the firmware event log.  It never writes flash, never touches fuses and
# never changes firmware, firmware settings or TPM state.
#
# Targets: MSI V540TU and V560TU running Dasharo/Heads (Intel Boot Guard /
# CBnT platforms) on a live Linux with the Intel provenance tooling available.
# It is safe to run from a live OS and from the Heads recovery shell.
#
# pcr0tool is NOT built or downloaded by this script.  To obtain it, build it
# from the Dasharo coreboot tree:
#
#   cd <dasharo-coreboot>/3rdparty/intel-sec-tools/cmd/pcr0tool
#   GO111MODULE=on go build -o pcr0tool cmd/pcr0tool/
#
# (see that directory's README.md for kernel/`/dev/mem` prerequisites).
#
# Usage: pcr0-diag.sh [path-to-pcr0tool]
#
# Prerequisites checked by this script: /dev/mem access, the kernel parameters
# `iomem=relaxed intel_iommu=on`, and the `msr` kernel module.

set -u

CMDLINE_PARAMS="iomem=relaxed intel_iommu=on"
EVENTLOG_FILE="/sys/kernel/security/tpm0/binary_bios_measurements"
CAPTURE_FILE="$(mktemp 2>/dev/null || echo /tmp/pcr0-diag-capture.$$)"
PCR0TOOL=""

# ---- report destination ----------------------------------------------------
REPORT="./pcr0-report.txt"
if grep -q ' /media/' /proc/mounts 2>/dev/null; then
	REPORT="/media/pcr0-report.txt"
fi
: >"$REPORT" 2>/dev/null || {
	REPORT="./pcr0-report.txt"
	: >"$REPORT"
}

# ---- output helpers --------------------------------------------------------
# Append to the report and echo to stdout, without modifying the content.
say() {
	printf '%s\n' "$*" >>"$REPORT"
	printf '%s\n' "$*"
}

header() {
	say ""
	say "=============================================================="
	say "$1"
	say "=============================================================="
}

# Run "$@", keeping the raw output in $CAPTURED and writing it to both the
# report and stdout untouched.
run_capture() {
	"$@" >"$CAPTURE_FILE" 2>&1
	CAPTURED="$(cat "$CAPTURE_FILE")"
	cat "$CAPTURE_FILE" >>"$REPORT"
	cat "$CAPTURE_FILE"
}

# Minimal hex dump that works with xxd or od.
to_hex() {
	if command -v xxd >/dev/null 2>&1; then
		xxd -p | tr -d ' \n'
	else
		od -An -tx1 | tr -d ' \n'
	fi
}

# ---- argument / pcr0tool resolution ----------------------------------------
if [ "$#" -ge 1 ] && [ -n "$1" ]; then
	PCR0TOOL="$1"
else
	PCR0TOOL="$(command -v pcr0tool 2>/dev/null || true)"
fi

header "PCR0 provenance diagnostic (read-only)"
say "Date:        $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
say "Host:        $(uname -a 2>/dev/null)"
say "Report file: $REPORT"
if [ -n "$PCR0TOOL" ] && [ -x "$PCR0TOOL" ]; then
	say "pcr0tool:    $PCR0TOOL"
else
	say "pcr0tool:    NOT FOUND (pass its path as the first argument,"
	say "             or build it from 3rdparty/intel-sec-tools/cmd/pcr0tool"
	say "             in the Dasharo coreboot tree and put it on PATH)"
fi

# ---- prerequisites ---------------------------------------------------------
header "Prerequisites"

say "-- /dev/mem access --"
if [ -e /dev/mem ]; then
	if [ -r /dev/mem ] && [ -w /dev/mem ]; then
		say "OK: /dev/mem exists and is readable/writable by this user."
	else
		say "WARN: /dev/mem exists but is not readable/writable by this user"
		say "      (run as root; pcr0tool needs /dev/mem and /dev/cpu/0/msr)."
	fi
else
	say "FAIL: /dev/mem does not exist. Enable CONFIG_DEVMEM=y in the kernel."
fi

say ""
say "-- kernel parameters --"
CURRENT_CMDLINE="$(cat /proc/cmdline 2>/dev/null)"
say "Current /proc/cmdline: $CURRENT_CMDLINE"
MISSING=""
printf '%s\n' "$CURRENT_CMDLINE" | grep -q 'iomem=relaxed' || MISSING="$MISSING iomem=relaxed"
printf '%s\n' "$CURRENT_CMDLINE" | grep -q 'intel_iommu=on' || MISSING="$MISSING intel_iommu=on"
if [ -z "$MISSING" ]; then
	say "OK: iomem=relaxed and intel_iommu=on are present."
else
	say "MISSING kernel parameter(s):$MISSING"
	say "Add this to the kernel command line and reboot:"
	say "    $CMDLINE_PARAMS"
	say "(e.g. GRUB_CMDLINE_LINUX_DEFAULT, or the Heads boot entry)."
fi

say ""
say "-- msr kernel module --"
if [ -e /dev/cpu/0/msr ]; then
	say "OK: /dev/cpu/0/msr already present (msr module loaded)."
elif command -v modprobe >/dev/null 2>&1 && modprobe msr >/dev/null 2>&1; then
	if [ -e /dev/cpu/0/msr ]; then
		say "OK: 'modprobe msr' succeeded; /dev/cpu/0/msr is now present."
	else
		say "WARN: 'modprobe msr' succeeded but /dev/cpu/0/msr is absent"
		say "      (check CONFIG_X86_MSR=y and that /dev is populated)."
	fi
else
	say "FAIL: could not load the msr module (need root; check CONFIG_X86_MSR=y)."
fi

# ---- ACM policy / status + Boot Guard / SACM registers ---------------------
ACMS=""
if [ -n "$PCR0TOOL" ] && [ -x "$PCR0TOOL" ]; then
	header "ACM policy/status registers and Boot Guard / SACM info"
	say "Command: $PCR0TOOL dump_registers"
	say ""
	run_capture "$PCR0TOOL" dump_registers
	ACMS="$CAPTURED"
else
	header "ACM policy/status registers and Boot Guard / SACM info"
	say "SKIP: pcr0tool not available (subcommand would be: dump_registers)."
fi

# ---- current PCR 0 ---------------------------------------------------------
header "Current PCR 0 (sha256)"
PCR0_HEX=""
PCRREAD_CMD=""
if command -v tpm2_pcrread >/dev/null 2>&1; then
	PCRREAD_CMD="tpm2_pcrread sha256:0"
elif command -v tpm2 >/dev/null 2>&1; then
	PCRREAD_CMD="tpm2 pcrread sha256:0"
fi
if [ -n "$PCRREAD_CMD" ]; then
	say "Command: $PCRREAD_CMD"
	say ""
	# Word splitting is intended: PCRREAD_CMD is "cmd arg".
	# shellcheck disable=SC2086
	run_capture $PCRREAD_CMD
	PCR0_HEX="$(printf '%s\n' "$CAPTURED" | sed -n 's/.*0 : 0x\([0-9A-Fa-f]*\).*/\1/p' | head -n1 | tr 'A-F' 'a-f')"
	if [ -z "$PCR0_HEX" ]; then
		PCR0_HEX="$(printf '%s\n' "$CAPTURED" | sed -n 's/.*= *\([0-9A-Fa-f]\{40,64\}\).*/\1/p' | head -n1 | tr 'A-F' 'a-f')"
	fi
else
	say "SKIP: neither tpm2_pcrread nor tpm2 is available."
fi

# ---- event log entries related to Boot Guard / IBB -------------------------
header "TPM event log entries related to Boot Guard / IBB"
LOG_TEXT=""
LOG_SRC=""
if command -v tpm2_eventlog >/dev/null 2>&1 && [ -f "$EVENTLOG_FILE" ]; then
	LOG_SRC="tpm2_eventlog $EVENTLOG_FILE"
	say "Command: $LOG_SRC (filtered below)"
	say ""
	run_capture tpm2_eventlog "$EVENTLOG_FILE"
	LOG_TEXT="$CAPTURED"
elif command -v cbmem >/dev/null 2>&1; then
	LOG_SRC="cbmem -L"
	say "Command: $LOG_SRC (Heads recovery shell)"
	say ""
	run_capture cbmem -L
	LOG_TEXT="$CAPTURED"
else
	say "SKIP: no event-log source (need tpm2_eventlog + $EVENTLOG_FILE,"
	say "      or cbmem -L from the Heads recovery shell)."
fi

LOG_COUNT=0
if [ -n "$LOG_TEXT" ]; then
	LOG_COUNT="$(printf '%s\n' "$LOG_TEXT" | grep -Eic 'S_CRTM|S-CRTM|SCRTM|BootGuard|Boot Guard|IBB|PLATFORM_FIRMWARE_BLOB' || true)"
	say ""
	say "-- matching Boot Guard / IBB entries --"
	if [ "$LOG_COUNT" -gt 0 ] 2>/dev/null; then
		printf '%s\n' "$LOG_TEXT" | grep -Ei 'S_CRTM|S-CRTM|SCRTM|BootGuard|Boot Guard|IBB|PLATFORM_FIRMWARE_BLOB' | tee -a "$REPORT"
	else
		say "No Boot Guard / IBB related entries found (searched above log)."
	fi
fi

# ---- replay of the log vs PCR 0 --------------------------------------------
header "Replay of the event log vs PCR 0"
REPLAY_HEX=""
REPLAY_METHOD=""
REPLAY_MATCH=0
if command -v tpmr.sh >/dev/null 2>&1; then
	REPLAY_METHOD="tpmr.sh calcfuturepcr 0"
	say "Command: $REPLAY_METHOD | hex"
	REPLAY_HEX="$(tpmr.sh calcfuturepcr 0 2>/dev/null | to_hex)"
	say "Replayed PCR 0: $REPLAY_HEX"
	say "Current  PCR 0: $PCR0_HEX"
	if [ -n "$REPLAY_HEX" ] && [ -n "$PCR0_HEX" ] && [ "$REPLAY_HEX" = "$PCR0_HEX" ]; then
		REPLAY_MATCH=1
		say "MATCH: replayed value equals current PCR 0."
	else
		say "MISMATCH or unavailable replay value."
	fi
elif command -v tpm2_eventlog >/dev/null 2>&1 && [ -f "$EVENTLOG_FILE" ]; then
	REPLAY_METHOD="tpm2_eventlog --verify $EVENTLOG_FILE"
	say "Command: $REPLAY_METHOD"
	if tpm2_eventlog --verify "$EVENTLOG_FILE" >"$CAPTURE_FILE" 2>&1; then
		REPLAY_MATCH=1
		cat "$CAPTURE_FILE" >>"$REPORT"
		cat "$CAPTURE_FILE"
		say "MATCH: tpm2_eventlog --verify succeeded (log replays to current PCRs)."
	else
		cat "$CAPTURE_FILE" >>"$REPORT"
		cat "$CAPTURE_FILE"
		say "MISMATCH: tpm2_eventlog --verify failed."
	fi
else
	say "SKIP: no replay method available (need tpmr.sh calcfuturepcr,"
	say "      or tpm2_eventlog --verify with $EVENTLOG_FILE)."
fi

# ---- derived register bits -------------------------------------------------
MEASURED=""
BPM=""
TPM_SUCCESS=""
SCRTM_STATUS=""
BTG_CAP=""
if [ -n "$ACMS" ]; then
	MEASURED="$(printf '%s\n' "$ACMS" | awk '/: Measured/ {print $3; exit}' | tr -dc '01')"
	BPM="$(printf '%s\n' "$ACMS" | awk '/BP\.TYPE\.M/ {print $3; exit}' | tr -dc '01')"
	TPM_SUCCESS="$(printf '%s\n' "$ACMS" | awk '/TPM Success/ {print $3; exit}' | tr -dc '01')"
	SCRTM_STATUS="$(printf '%s\n' "$ACMS" | awk '/S-CRTM Status/ {print $3; exit}' | tr -dc '0-9')"
	BTG_CAP="$(printf '%s\n' "$ACMS" | awk '/BootGuardCapability/ {print $3; exit}' | tr -dc '01')"
fi

# PCR 0 zero check: non-empty and made only of zeros.
PCR0_ZERO=0
if [ -z "$PCR0_HEX" ]; then
	PCR0_ZERO=-1
elif printf '%s' "$PCR0_HEX" | grep -q '^0*$'; then
	PCR0_ZERO=1
fi

# Normalise unknowns to 0 for the boolean facts.
case "$MEASURED" in 1) MEASURED=1 ;; *) MEASURED=0 ;; esac
case "$BPM" in 1) BPM=1 ;; *) BPM=0 ;; esac
case "$TPM_SUCCESS" in 1) TPM_SUCCESS=1 ;; *) TPM_SUCCESS=0 ;; esac
case "$SCRTM_STATUS" in ""|0) SCRTM_STATUS=0 ;; *) SCRTM_STATUS=1 ;; esac
case "$BTG_CAP" in 1) BTG_CAP=1 ;; *) BTG_CAP=0 ;; esac
if [ "$MEASURED" -eq 0 ] && [ "$BPM" -eq 1 ]; then
	MEASURED=1
fi

# ---- verdict: four explicit facts + classification -------------------------
header "VERDICT"
say "Fact 1 - Measured bit set (BP.TYPE.M / BTG_SACM_INFO.Measured): $MEASURED"
say "Fact 2 - PCR 0 is zero: $PCR0_ZERO  (1=zero, 0=non-zero, -1=unread)"
say "Fact 3 - Boot Guard / IBB log entry present: $([ "$LOG_COUNT" -gt 0 ] 2>/dev/null && echo 1 || echo 0)"
say "Fact 4 - Log replay matches PCR 0: $REPLAY_MATCH  (1=match, 0=no)"
say "         (S-CRTM status=$SCRTM_STATUS, BootGuardCapability=$BTG_CAP, TPM Success=$TPM_SUCCESS)"
say ""

if [ "$MEASURED" -eq 1 ] && [ "$TPM_SUCCESS" -eq 1 ] && [ "$PCR0_ZERO" -eq 0 ] && [ "$REPLAY_MATCH" -eq 1 ]; then
	say "CLASSIFICATION: measured"
	say "The measured bit is set, the TPM reports success, PCR 0 is non-zero and"
	say "the event-log replay matches.  Boot Guard/CBnT measured the IBB into PCR 0,"
	say "and PCR 0 depends on the measured firmware contents (plus S-CRTM)."
elif [ "$MEASURED" -eq 0 ] && [ "$SCRTM_STATUS" -eq 1 ]; then
	say "CLASSIFICATION: verify-only profile (S-CRTM present but measured bit clear)"
	say "Boot Guard capability and the S-CRTM are present, but the measured bit is"
	say "clear: the IBB is verified, not measured into the TPM.  A PCR 0 reset-then-"
	say "extend of only the S-CRTM separator is expected here."
elif [ "$SCRTM_STATUS" -eq 0 ] && [ "$BTG_CAP" -eq 0 ]; then
	say "CLASSIFICATION: ACM never ran (no S-CRTM, no Boot Guard capability)"
	say "No ACM/Boot Guard evidence: PCR 0 reflects the legacy/CRTM path only, or"
	say "an offline value with no ACM extend."
elif [ "$LOG_COUNT" -gt 0 ] 2>/dev/null && [ "$PCR0_ZERO" -eq 1 ]; then
	say "CLASSIFICATION: log entries with PCR 0 still zero (no ACM extend)"
	say "Boot Guard / IBB entries exist in the event log, yet PCR 0 is all zeros:"
	say "the ACM did not extend the log into PCR 0 (verify-only or a log/TPM delay)."
else
	say "CLASSIFICATION: inconclusive"
	say "The observed facts do not match any of the four expected profiles; inspect"
	say "the raw register, PCR and event-log output above."
fi

say ""
say "Report written to: $REPORT"
rm -f "$CAPTURE_FILE" 2>/dev/null
exit 0
