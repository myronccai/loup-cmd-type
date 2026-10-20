# loup-cmd-type

The Windows `type` command recreated in [Loup](https://code-craft.ai/references/loup):
display the contents of text files, with cmd's wildcards, `\` paths,
messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary, and it is the pilot of
the Windows set: it introduces the shared Windows code in
[`source/win/`](source/win/) (switch parser, wildcard matcher, path helpers,
messages) that the other Windows commands copy.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary: build/type
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="README.md"      # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/type 'demo\hello.txt'
Hello from type.
$ build/type 'demo\*.txt'

demo\hello.txt


Hello from type.

demo\notes.txt


Second file.

demo\unicode.txt


UTF-16 text
$ build/type 'demo\*.txt' 2>/dev/null
Hello from type.
Second file.
UTF-16 text
$ build/type 'demo\logs\*.log' > all.txt

demo\logs\app.log



demo\logs\old.LOG


$ cat all.txt
started
stopped
$ build/type 'demo\missing.txt'; echo "ERRORLEVEL $?"
The system cannot find the file specified.
ERRORLEVEL 1
$ build/type 'demo\hello.txt' 'demo\missing.txt'

demo\hello.txt


Hello from type.
The system cannot find the file specified.
Error occurred while processing: demo\missing.txt.
$ build/type demo; echo "ERRORLEVEL $?"
Access is denied.
ERRORLEVEL 1
$ build/type '/?'
Displays the contents of a text file or files.

TYPE [drive:][path]filename
$ build/type --version
type (loup-cmd-type) 0.1.0
```

(`demo\unicode.txt` is UTF-16LE with a byte order mark; `type` shows it as
UTF-8 text.)

`type` has no switches. `/?` (or `-?`) anywhere prints the help; every other
argument names a file, including `/X` and `-X`, and `--` ends switch
parsing. Operands accept `\` and `/`; wildcards `*` and `?` in the last
component follow Windows rules (case-insensitive, `*.*` matches every name,
`*.` matches names without an extension, `a?.txt` also matches `a.txt`),
skip directories, and are sorted by name. When more than one file is shown,
each name goes to standard error first, so redirecting standard output
collects only the contents.

Exit status (ERRORLEVEL): `0` if every file was shown, `1` if any operand
failed or none was given.

## Differences from the original

- File names are case-sensitive on Linux: `type A.TXT` does not open
  `a.txt`. Wildcards ignore case, so `type A.TX?` does.
- No 8.3 short names, so `*.txt` does not also match `a.txtx`.
- Paths are printed with `\` (`demo\hello.txt`), also when typed with `/`; a
  Linux file name containing `\` cannot be named.
- Messages end with LF, not CRLF. File contents are written unchanged; only
  UTF-16LE files with a byte order mark are converted (to UTF-8, where
  Windows converts to the console code page).
- No device names (`type CON`), no drive letters.
- An unreadable file (permissions) stops the program with the toolchain's
  `IoError` message instead of `Access is denied.`: Loup 1.26.0 has no
  `stat()`, and a native `IoError` cannot be caught.
- A name header is printed only when more than one file is shown in total.
- `--help` and `--version` as the only argument are series conventions.

## Shared Windows code

[`source/win/`](source/win/) is the master implementation of the Windows
conventions used by every loup-cmd Windows command; a copy with a usage
guide lives in `ccai-examples/shared/windows/`. In short:

| Module | Gives you |
|---|---|
| `win/switches.loup` | `parse_switches(argv, specs)`: `/S`, `-s`, `/A:H`, `/AH`, `/T 10`, `/S/Q`, `/?`, `--`; a `/X` that is not declared is a path |
| `win/wildcard.loup` | `wild_match` (Win32 DOS wildcards), `expand`, `list_matches`, `walk_dirs` and `find_recursive` (which do not enter symbolic links to directories), NTFS-like name order |
| `win/paths.loup` | `fs_path` (`\` → `/` for file access), `display_path` (`/` → `\` for printing), split/join helpers |
| `win/messages.loup` | Windows' wording: `The system cannot find the file specified.` and others |

The design is in [specs/windows-conventions/](specs/windows-conventions/).

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # type's switches (none) via win.switches
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/typefile.loup  # plan the files, read, print (`type` is a Loup reserved word)
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/type (make e2e)
specs/type/                    # requirements, design, tasks
specs/windows-conventions/     # the shared Windows code
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
