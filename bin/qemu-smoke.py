#!/usr/bin/env python3
"""Generic QEMU serial command-flow smoke harness (stdlib only).

Boots a Heads QA ROM (one whose CONFIG_BOOTSCRIPT=/bin/test-shell.sh) in
qemu-system-x86_64, waits for HEADS_TEST_SHELL_READY and the ``heads-test>``
prompt, runs the TAB-separated command/regex pairs from a plan file, and
asserts every expected regex appears in that command's output.

Plan format (one command per line, TAB separated)::

    <shell command><TAB><Python regex expected in the output>

Blank lines and lines starting with ``#`` are ignored.  No pexpect (or any
other third-party module) is used: the serial console is a pty driven with
select, and QEMU is launched in its own process group so it can be killed
reliably on timeout, failure, or interrupt.
"""

import argparse
import errno
import os
import pty
import re
import select
import signal
import subprocess
import sys
import time

READY_MARKER = "HEADS_TEST_SHELL_READY"
PROMPT = r"heads-test> "
REBOOT_COMMAND = "/bin/busybox reboot -f"

# ANSI/VT control sequences and NULs are dropped from the normalized transcript.
_ANSI = re.compile(
    r"\x1b\[[0-?]*[ -/]*[@-~]"          # CSI
    r"|\x1b\][^\x07]*(?:\x07|\x1b\\)"  # OSC
    r"|\x1b[@-Z\\-_]"                  # single-character ESC sequences
)


def normalize(chunk):
    """Return a transcript fragment with CRLF/CR and terminal escapes gone."""
    chunk = chunk.replace("\r\n", "\n").replace("\r", "\n")
    chunk = chunk.replace("\x00", "")
    return _ANSI.sub("", chunk)


def normalize_stream(chunk, carry=""):
    """Normalize a stream chunk, holding a trailing partial escape/CR over."""
    data = carry + chunk
    carry = ""
    if data.endswith("\r"):
        carry, data = "\r", data[:-1]
    elif "\x1b" in data[-2:]:
        index = data.rfind("\x1b")
        carry, data = data[index:], data[:index]
    return normalize(data), carry


# Distinct from an empty (escape-only) chunk and from "no data yet".
EOF = object()


def load_plan(path):
    """Parse a plan into [(command, compiled_regex), ...]."""
    entries = []
    with open(path, encoding="utf-8") as plan_file:
        for lineno, line in enumerate(plan_file, 1):
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2 or not parts[0].strip() or not "\t".join(parts[1:]):
                raise ValueError(
                    "%s:%d: expected '<command><TAB><regex>'" % (path, lineno)
                )
            pattern = "\t".join(parts[1:])
            try:
                compiled = re.compile(pattern)
            except re.error as exc:
                raise ValueError("%s:%d: bad regex %r: %s" % (path, lineno, pattern, exc))
            entries.append((parts[0], pattern, compiled))
    if not entries:
        raise ValueError("%s: plan has no command lines" % path)
    return entries


def _raise_on_signal(signum, _frame):
    # Turn SIGTERM into an exception so the finally block still kills QEMU.
    raise KeyboardInterrupt("received signal %d" % signum)


class QemuSmoke:
    def __init__(self, rom, plan, log, boot_timeout, command_timeout,
                 reboot_timeout, ready_marker, prompt):
        self.rom = rom
        self.plan = plan
        self.log = log
        self.boot_timeout = boot_timeout
        self.command_timeout = command_timeout
        self.reboot_timeout = reboot_timeout
        self.ready_re = re.compile(re.escape(ready_marker))
        self.prompt_re = re.compile(prompt)
        self.master_fd = None
        self.slave_fd = None
        self.proc = None
        self.parts = []
        self.carry = ""

    @property
    def transcript(self):
        return "".join(self.parts)

    def write_transcript(self):
        parent = os.path.dirname(os.path.abspath(self.log))
        if parent:
            os.makedirs(parent, exist_ok=True)
        # A final whole-transcript pass catches escape sequences that were
        # split across pty reads (the incremental pass holds only a short tail).
        text = normalize(self.transcript)
        with open(self.log, "w", encoding="utf-8") as log_file:
            log_file.write(text)
        print("=== qemu-smoke normalized transcript (%s) ===" % self.log)
        print(text, end="" if text.endswith("\n") else "\n")
        print("=== end qemu-smoke normalized transcript ===")

    def start(self):
        if not os.path.isfile(self.rom):
            raise RuntimeError("ROM not found: %s" % self.rom)
        self.master_fd, self.slave_fd = pty.openpty()
        cmd = [
            "qemu-system-x86_64",
            "-machine", "q35,accel=tcg",
            "-m", "512M",
            "-vga", "std",
            "-display", "none",
            "-serial", "stdio",
            "--bios", self.rom,
            "-no-reboot",
        ]
        print("qemu-smoke: launching: %s" % " ".join(cmd))
        # start_new_session puts QEMU (and anything it forks) in a fresh
        # process group whose id is QEMU's pid; killpg() below reaches all of it.
        self.proc = subprocess.Popen(
            cmd,
            stdin=self.slave_fd,
            stdout=self.slave_fd,
            stderr=self.slave_fd,
            start_new_session=True,
            close_fds=True,
        )
        os.close(self.slave_fd)
        self.slave_fd = None

    def send(self, command):
        os.write(self.master_fd, (command + "\n").encode("utf-8"))

    def pump(self, timeout):
        """Read one chunk: text (possibly empty), None if no data, EOF sentinel."""
        try:
            readable, _, _ = select.select([self.master_fd], [], [], timeout)
        except (OSError, ValueError):
            return EOF
        if not readable:
            return None
        try:
            data = os.read(self.master_fd, 65536)
        except OSError as exc:
            if exc.errno in (errno.EIO, errno.EBADF):
                return EOF
            raise
        if not data:
            return EOF
        text, self.carry = normalize_stream(data.decode("utf-8", "replace"), self.carry)
        self.parts.append(text)
        return text

    def read_until(self, regex, timeout, what, start=0):
        """Wait until regex matches transcript[start:]; return the full text.

        ``start`` matters for the per-command prompt waits: earlier prompts are
        still in the transcript and must not satisfy a later wait immediately.
        """
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError("timed out after %ss waiting for %s (%r)" %
                                   (timeout, what, regex))
            chunk = self.pump(min(remaining, 0.5))
            if chunk is EOF:
                rc = self.proc.poll() if self.proc else None
                raise RuntimeError("QEMU closed serial / exited (rc=%s) before %s (%r)" %
                                   (rc, what, regex))
            if re.search(regex, self.transcript[start:]):
                return self.transcript

    def drain(self, seconds=0.3):
        """Discard already-buffered output (e.g. a prompt we did not consume)."""
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if self.pump(0.05) is EOF:
                break

    def wait_for_exit(self, timeout):
        """Pump the serial pty while waiting for QEMU to exit after reboot."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            rc = self.proc.poll()
            if rc is not None:
                return rc
            self.pump(0.2)
        return None

    def run(self):
        self.start()
        try:
            self.read_until(self.ready_re.pattern, self.boot_timeout,
                            "HEADS_TEST_SHELL_READY marker")
            self.read_until(self.prompt_re.pattern, self.command_timeout,
                            "initial test-shell prompt")
            for command, pattern, compiled in self.plan:
                # Swallow the previous prompt before issuing the next command so
                # the captured window contains only this command's output.
                self.drain()
                start = len(self.transcript)
                print("qemu-smoke: > %s" % command)
                self.send(command)
                self.read_until(self.prompt_re.pattern, self.command_timeout,
                                "prompt after %r" % command, start=start)
                output = self.transcript[start:]
                if not compiled.search(output):
                    raise AssertionError(
                        "expected %r in output of %r; got:\n%s" %
                        (pattern, command, output)
                    )
                print("qemu-smoke: OK %r" % pattern)
            self.drain()
            print("qemu-smoke: > %s" % REBOOT_COMMAND)
            self.send(REBOOT_COMMAND)
            rc = self.wait_for_exit(self.reboot_timeout)
            if rc is None:
                print("qemu-smoke: QEMU did not exit after reboot; killing it",
                      file=sys.stderr)
                self.kill()
            else:
                print("qemu-smoke: QEMU exited with rc=%s" % rc)
        finally:
            self.cleanup()

    def kill(self):
        if self.proc is None:
            return
        try:
            os.killpg(self.proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass

    def cleanup(self):
        if self.proc is not None and self.proc.poll() is None:
            self.kill()
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
            self.master_fd = None
        if self.slave_fd is not None:
            try:
                os.close(self.slave_fd)
            except OSError:
                pass
            self.slave_fd = None


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", required=True, help="Heads QA ROM to boot with --bios")
    parser.add_argument("--plan", required=True, help="TAB-separated command/regex plan")
    parser.add_argument("--log", required=True, help="where to save the normalized transcript")
    parser.add_argument("--boot-timeout", type=float, default=300.0,
                        help="seconds to wait for the ready marker (default: 300)")
    parser.add_argument("--command-timeout", type=float, default=60.0,
                        help="seconds to wait for each prompt (default: 60)")
    parser.add_argument("--reboot-timeout", type=float, default=30.0,
                        help="seconds to wait for QEMU to exit after reboot (default: 30)")
    parser.add_argument("--ready-marker", default=READY_MARKER,
                        help="serial marker printed by the test shell")
    parser.add_argument("--prompt", default=PROMPT,
                        help="Python regex for the test-shell prompt")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    signal.signal(signal.SIGTERM, _raise_on_signal)
    smoke = None
    try:
        plan = load_plan(args.plan)
        smoke = QemuSmoke(
            rom=args.rom, plan=plan, log=args.log,
            boot_timeout=args.boot_timeout, command_timeout=args.command_timeout,
            reboot_timeout=args.reboot_timeout, ready_marker=args.ready_marker,
            prompt=args.prompt,
        )
        smoke.run()
        print("qemu-smoke: all %d plan command(s) passed" % len(plan))
        return 0
    except (KeyboardInterrupt, Exception) as exc:
        print("qemu-smoke: FAIL: %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    finally:
        if smoke is not None:
            smoke.cleanup()
            try:
                smoke.write_transcript()
            except OSError as exc:
                print("qemu-smoke: could not write transcript: %s" % exc,
                      file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
