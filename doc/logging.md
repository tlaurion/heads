# Heads Debug Logging

Heads produces debug logging to aid development and troubleshooting.

Logging is produced in scripts at a _log level_.
Users can set an _output level_ that controls how much output they see on the screen.

# Log Levels

In order from "most verbose" to "least verbose":

LOG > TRACE > DEBUG > INFO > (console) > NOTE > warn

("console" level output is historical and should be replaced with INFO.)

## LOG

LOG is for very detailed output or output with uncontrolled length.
It never goes to the screen, this always goes to the log file.
Usually, we dump outputs of commands like 'lsblk', 'lsusb', 'gpg --list-keys', etc. at LOG level (using DO_WITH_DEBUG or SINK_LOG), so we can tell the state of the system from a log submitted by a user.
We rarely want these on the console as they usually hide more relevant output with information that we already know.

Use this in situations like:
* Dumping information about the state of the system for debugging.  The output doesn't indicate any specific action/decision in Heads or a problem, it's just state relevant for troubleshooting the rest of the log.
* Tracing something that might be very long (including "we don't know how long this will be", even if it's sometimes short).  Very long output isn't useful on the console, since you can't scroll back, and it hides more important information.
* The output is intended for debugging a specific topic, and usually unintersting otherwise.  We want to be able to turn up output to DEBUG/TRACE when working on any topic without excessively filling the console with every topic's detailed output.

## TRACE

TRACE is for following execution flow through Heads.
(TRACE_FUNC logs the current source location at TRACE level, you can use this when entering a function or script, this is much more common than using TRACE directly.)

You can also use TRACE to show parameter values to scripts or functions.
Since TRACE is for execution flow, show the unprocessed parameters as provided by the caller, not an interpreted version.
(This is uncommon though as it is very verbose, and we can also capture interesting call sites with DO_WITH_DEBUG.)

You can invoke TRACE to show specific execution flow when needed, but if you are tracing the result of a decision, consider using DEBUG instead.

### Reading TRACE_FUNC output

Each TRACE_FUNC call emits the full call chain leading to the current function.
The format is:

```text
TRACE: caller(file:line) -> ... -> current_func(file:line)
```

The line number in each entry means something different depending on position:

* **Non-last entries**: the line number is the **call site** — the line within that function where it called the next function in the chain.
* **Last entry**: the line number is where **TRACE_FUNC itself** is called inside the current function (typically the first line of the function body).

Example — a `tpmr unseal` call triggered from `gui-init` (line numbers are illustrative; they will vary with code changes):

```text
TRACE: main(/init:0) -> main(/bin/gui-init:0) -> main(/bin/tpmr:0) -> main(/bin/tpmr:1037) -> tpm2_unseal(/bin/tpmr:635)
```

Dissecting each entry:

* `main(/init:0)` — `/init` is the root script; `:0` marks a cross-process boundary (the exact call site is not tracked across subprocess invocations)
* `main(/bin/gui-init:0)` — `gui-init` was launched by `/init` as a subprocess; `:0` again for the cross-process boundary
* `main(/bin/tpmr:0)` — `tpmr` was launched by `gui-init` as a subprocess; `:0` for the cross-process boundary
* `main(/bin/tpmr:1037)` — line 1037 in `tpmr`'s `main` is where it called `tpm2_unseal "$@"` (call site within `main`)
* `tpm2_unseal(/bin/tpmr:635)` — line 635 is where `TRACE_FUNC` is in `tpm2_unseal` — the function that just entered

To read the trace, open `tpmr` and go to the line numbers shown.
For example, line 1037 (`tpm2_unseal "$@"`) confirms `main` called `tpm2_unseal` there,
and line 635 (`TRACE_FUNC`) confirms that is the entry point of `tpm2_unseal`.

This means you can pinpoint the exact call path — including cross-process subprocess chains — that led to any point in execution.

Use this in situations like:
* Following control flow - use TRACE_FUNC when entering a script or function
* Showing the parameters used to invoke a script/function, when they are especially relevant and not excessively verbose

## DEBUG

DEBUG is for most log information that is relevant if you are a Heads developer.

Use DEBUG to highlight the decisions made in script logic, and the information that affects those decisions.
Generally, focus on decision points (if, else, case, while, for, etc.), because we can keep following straight-line execution without further tracing.

Decision points usually capture program behavior the best.
Show the information that is about to influence a decision (`DEBUG "Found ${#DEVS[@]} block devices: to check for LUKS:" "${DEVS[@]}"`) and/or the results of the decision (`DEBUG "${DEVS[$i]} is not a LUKS device, ignore it`).

Use DO_WITH_DEBUG to capture a particular command execution to the debug log.
The command and its arguments are captured at DEBUG level (as they usually indicate the decisions the command will make), and the command's stdout/stderr are captured at LOG level.
See DO_WITH_DEBUG for examples of usage.

Use this in situations like:

* Showing information derived or obtained that will influence logical decisions and actions
* Showing the result of decisions and the reasons for them

## INFO

INFO is for contextual information that may be of interest to end users, but that is not required for use of Heads.
Users can control whether this is displayed on the console.

Users might use this to troubleshoot Heads configuration or behavior, but this should not require knowledge of Heads implementation or developer experience.

For example:

* "Why can't I enable USB keyboard support?"  `INFO "Not showing USB keyboard option, USB keyboard is always enabled for this board"`
* "Why isn't Heads booting automatically?"  `INFO "Not booting automatically, automatic boot is disabled in user settings"`
* "Why didn't Heads prompt me for a password?"  `INFO "Password has not been changed, using default"`)

These do not include highly technical details.
They can include configuration values or context, _but_ they should refer to configuration settings using the user-facing names in the configuration menus.

Use this in situations like:

* Showing very high level decision-making information, which is reasonably understandable for users not familiar with Heads implementation
* Explaining a behavior that could reasonably be unexpected for some users

## console

This level is historical, use INFO for this.
It is documented as there are still some occurrences in Heads, usually `echo`, `echo >&2`, or `echo >/dev/console`, each intended to produce output directly on the console.
The intent is the same as INFO.

(This is different from `echo` used to produce output that might be captured by a caller, which is not logging at all.)

Avoid using this, and change existing console output to INFO or another level.

## STATUS

STATUS is for progress and action announcements that all users must see regardless of output mode.

Use STATUS when an action is starting, in progress, or just completed — things users need to track what Heads is actively doing:

* "Verifying ISO" — user needs to know a signature check is running
* "Building initrd" — a potentially slow step the user should track
* "LUKS device unlocked" — confirmation of a security-relevant operation
* "Executing default boot for $name" — what is about to boot

Unlike INFO, STATUS is always visible in all output modes — a user in quiet mode must still be able to see what Heads is doing.
Unlike NOTE, STATUS does not sleep — it is for routine progress and action confirmation, not unexpected behavior.

**Future**: STATUS is the placeholder for color output (yellow = in-progress, green = success, red = failure) and eventual whiptail transformation for actionable items.

## NOTE

NOTE is for contextual information explaining something that is _likely_ to be unexpected or confusing to users new to Heads.

Unlike INFO, it cannot be hidden.  Use this only if the behavior is likely to be unexpected or confusing to many users.  If it is only possibly unexpected or uncommon that it is confusing, consider INFO instead.

Do not overuse this above INFO.  Adding too much output at NOTE causes users to ignore it, as there is too much output.

For example:

* "Rebooting in 3 seconds to enable booting default boot option".  Users probably don't expect the firmware to reboot to accomplish this behavior, this is unique to Heads.  Without a message justifying the reboot, it would likely appear that the firmware faulted and reset unexpectedly.
* "Your GPG User PIN, followed by Enter key will be required [...]".  GPG prompts are very confusing to users unfamiliar with GPG (which is most users).

## warn

warn is for output that indicates a problem.  We think the user should act on it, but we are able to continue, possibly with degraded functionality.
(This level and the utility function are lowercase, as they predate the other levels.)

This is apppriate when _all_ of the following are true:

- there is a _likely_ problem
- we are able to continue, possibly with degraded functionality
- the warning is _actionable_ - there is a reasonable change that could silence the warning if this is intentional

**Do not overuse this.** Overuse of this level causes user to become accustomed to ignoring warnings.
This level only has value as long as it does not occur frequently, so users will notice warnings.

Warnings must indicate a _likely_ problem.
(Not a rare or remote possibility of a problem.)

Warnings are only appropriate if we're able to continue operating.
If we can't, consider prompting the user instead, since we cannot do what they asked.

Warnings must be _actionable_.  Only warn if there is a reasonable change the user can make to avoid the warning.

For example:
* Warning when using default passphrases that are completely insecure is reasonable - the user has no security, and if they want that, they should use Basic mode.
* Warning when an unknown variable appears in config.user is not reasonable - there's no reasonable way for the user to address this.

## INPUT

INPUT is a direct replacement for the `echo "prompt"; read [flags] VAR` pattern.
It displays the prompt in **bold cyan** to visually distinguish interactive input requests from progress/info messages.

Usage: `INPUT "prompt text" [read-flags] [VARNAME]`

```bash
# Instead of:
echo "Enter passphrase:"
read -r -s passphrase

# Use:
INPUT "Enter passphrase:" -r -s passphrase
```

INPUT always prints a blank line before the prompt so the user can easily find it on the console.
The prompt text and `INPUT:` label are recorded in debug.log for tracing.
All read flags (`-r`, `-s`, `-n N`, etc.) and the variable name are passed through unchanged to `read`.

Do NOT use INPUT for yes/no confirmation dialogs - use whiptail for those.

# Output Levels

Users can choose one of three output levels for extra console information.

* None - Show no extra output.  STATUS, NOTE and warn always appear on console.
* Info - Show information about operations in Heads.  (INFO and above.)
* Debug - Show detailed information suitable for debugging Heads.  (TRACE and above.)  Log file captures all levels.

Console output styling — chosen for accessibility across color-deficiency types (WCAG 1.4.1: color is never the sole signal; text prefixes carry meaning independently):

| Level  | Style          | ANSI code    | Rationale |
|--------|----------------|--------------|-----------|
| die    | bold red       | `\033[1;31m` | Red = universal danger signal; `!!! ERROR:` prefix is the semantic carrier |
| warn   | bold yellow    | `\033[1;33m` | Most universally perceptible alert color across deuteranopia, protanopia, tritanopia |
| NOTE   | bold magenta   | `\033[1;35m` | Magenta is distinct under all common color-deficiency types; blue was avoided (low contrast on dark terminals, confusable with cyan) |
| STATUS | bold only      | `\033[1m`    | Most frequent output level — bold without hue ensures readability in every terminal theme (dark, light, high-contrast, monochrome); `>>` prefix differentiates semantically |
| INFO   | green          | `\033[0;32m` | Standard informational color; INFO is optional context, its absence is harmless |
| INPUT  | bold white     | `\033[1;37m` | Maximum contrast (21:1) on VGA/dark consoles; no color dependency, readable under all deficiency types and monochrome modes |

debug.log and /dev/kmsg always receive plain text without ANSI codes.

STATUS, NOTE and warn print a blank line before and after the message so they stand out visually from surrounding output.
INPUT prints a blank line before the prompt so it is clearly visible on the console.

## None - no extra output

| Sink           | LOG | TRACE | DEBUG | INFO | STATUS | NOTE | warn |
|----------------|-----|-------|-------|------|--------|------|------|
| Console        |     |       |       |      | Yes    | Yes  | Yes  |
| /tmp/debug.log | Yes |       |       |      | Yes    | Yes  |      |

No extra output is specified with:

```
CONFIG_DEBUG_OUTPUT=n
CONFIG_ENABLE_FUNCTION_TRACING_OUTPUT=n
CONFIG_QUIET_MODE=y
```

## Info

| Sink           | LOG | TRACE | DEBUG | INFO | STATUS | NOTE | warn |
|----------------|-----|-------|-------|------|--------|------|------|
| Console        |     |       |       | Yes  | Yes    | Yes  | Yes  |
| /tmp/debug.log | Yes |       |       |      | Yes    | Yes  |      |

Info output is enabled with:

```
CONFIG_DEBUG_OUTPUT=n
CONFIG_ENABLE_FUNCTION_TRACING_OUTPUT=n
CONFIG_QUIET_MODE=n
```

## Debug

| Sink           | LOG | TRACE | DEBUG | INFO | STATUS | NOTE | warn |
|----------------|-----|-------|-------|------|--------|------|------|
| Console        |     | Yes   | Yes   | Yes  | Yes    | Yes  | Yes  |
| /tmp/debug.log | Yes | Yes   | Yes   | Yes  | Yes    | Yes  | Yes  |

Debug output is enabled with:

```
CONFIG_DEBUG_OUTPUT=y
CONFIG_ENABLE_FUNCTION_TRACING_OUTPUT=y
CONFIG_QUIET_MODE=n
```
