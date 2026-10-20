# Design: type

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with the
shared switch parser (`win.switches`), handles `/?` and `--version`, and
calls `commands.typefile.run_type`. `run_type` first builds a plan (a list
of `Item`s: a file to show, or an operand that failed with its message), then
walks it, printing names and errors to standard error and contents to
standard output.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `type_switches()` (none), `parse_args` via `win.switches` |
| `source/cli/usage.loup` | `usage()` (Windows' help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/typefile.loup` | `plan`, `missing_reason`, `name_header`, `is_utf16le`, `decode_utf16le`, `file_text`, `run_type` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

The command module is `typefile`, not `type`: `type` is a reserved word in
Loup and cannot be an import path component.

`plan` handles each operand in turn: a wildcard in a directory component is
an error; a wildcard in the name expands through `win.wildcard.expand` with
`MATCH_FILES` (no match is an error); a literal operand is checked with
`isFile`, and `missing_reason` picks the message (`Access is denied.` for a
directory, the path message when the parent directory is missing). Names are
shown when the plan has more than one item.

`file_text` reads the bytes once to look for the UTF-16LE mark; other files
are read again with `readText`, which in a native build returns the bytes
unchanged (also invalid UTF-8 and NULs), and `print` writes them as they are.

## Differences from the original

- Names are case-sensitive on Linux: `type A.TXT` does not open `a.txt`.
  Wildcard matching ignores case, so `type A.TX?` does.
- No 8.3 short names, so `*.txt` does not also match `a.txtx`.
- Messages end with LF, not CRLF; file contents are written unchanged.
- Only UTF-16LE with a byte order mark is converted; UTF-8 and other bytes
  pass through (Windows converts to the console code page).
- `type CON` and other device names are not supported.
- An unreadable file (permissions) ends the program with the toolchain's
  `IoError` message instead of `Access is denied.`: Loup 1.26.0 has no
  `stat()` and its native `IoError` cannot be caught.
- A name header is printed only when more than one file is shown in total.
- `--version` and `--help` (alone) are series conventions, not Windows'.

## Error handling

Every failure is reported per operand and processing continues; the exit
status is 1 if any operand failed. An unexpected exception is printed on
standard error and gives status 1.

## Testing

- `tests/args_test.loup`: everything is a file except `/?`; `--`.
- `tests/typefile_test.loup`: the plan for literal, wildcard and failing
  operands; the header; UTF-16LE decoding (surrogates, odd bytes).
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: runs the native binary in a fixture tree and compares
  standard output byte for byte and standard error exactly.
