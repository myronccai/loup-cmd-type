# Design: Windows conventions (shared code)

## Overview

Four modules under `source/win/`, imported by path (`from win.switches
import (...)`). They have no dependency on the command that uses them, so
they can be copied unchanged into every Windows repository. The master copy
is `ccai-examples/shared/windows/`, whose README is the user guide.

## Modules

| Module | Contents |
|---|---|
| `win/switches.loup` | `SwitchSpec` and its constructors `flag`, `optional_value`, `required_value`, `glued_value`, `list_value`; `parse_switches(argv, specs, clusters = false): Result[SwitchArgs, SwitchError]`; lookups `has_switch`, `switch_count`, `last_switch`, `switch_value`, `switch_values`; `switch_error_message`; `parse_int_value` |
| `win/wildcard.loup` | `has_wildcards`, `wild_match`, `compare_names`, `sort_names`, `list_matches`, `subdirectories`, `expand`, `wildcard_in_directory`, `walk_dirs`, `find_recursive`; `MATCH_FILES`, `MATCH_DIRS`, `MATCH_ALL`, `MAX_DEPTH` |
| `win/paths.loup` | `PathParts`, `fs_path`, `display_path`, `is_absolute_path`, `strip_trailing_separators`, `split_path`, `join_path`, `base_name`, `parent_dir`, `path_components` |
| `win/messages.loup` | `MSG_*` constants and `msg_*` formatters with Windows' wording |

### Switch parsing

Each argument is classified by `token_hits`: an empty list means an
operand. The text after the prefix is matched against the declared names,
longest first (so `/NOBREAK` is not `/N` with a value): an exact match is the
switch alone; `:` or `=` after a valued switch's name starts its value; for
`glued` switches the rest of the token is the value if it only uses the
`allowed` characters. If the whole token does not match, a `/`-prefixed
token is split at `/` and accepted only if every piece matches; with
`clusters`, a token of declared one-letter flags is split into them. A
required value missing from the token is taken from the next argument unless
that argument is itself a switch or `--`. A list takes every following
argument up to the next switch.

### Wildcard matching

`wild_match` rewrites the pattern as Win32 does (`?` → DOS_QM; `*` before
`.` → DOS_STAR; `.` before `?`, `*` or the end → DOS_DOT), then fills a
dynamic-programming table `ok[p][k]` (tokens from `p` match name characters
from `k`) from the end. The table is (pattern length + 1) × (name length + 1)
booleans, so no pattern can make it backtrack exponentially.

### Paths

Operands are converted once with `fs_path` and every printed path goes
through `display_path`. `split_path` keeps the directory as typed (minus
trailing separators) so expansions read naturally (`sub\*.txt` →
`sub/a.txt` → printed `sub\a.txt`).

## Toolchain notes (Loup 1.26.0)

- `name_order` is a hand-written insertion sort: a `sort` comparator that
  captures the spec list crashes native builds.
- `list_matches` checks `isDir` first: native `listDir` returns `[]` for a
  missing directory but Stage0 throws.
- `walk_dirs` uses an explicit stack rather than recursion.
- `parse_int_value` exists because `system.text.parseInt` does not link in
  native builds.
- The unit tests must run with `loup-bootstrap test --no-parallel`.

## Error handling

The only parse error is a missing required value (`ERR_VALUE_EXPECTED`);
each command prints Windows' message for it. File-system functions never
throw for a missing directory (they return empty lists).

## Testing

`tests/win_switches_test.loup`, `tests/win_wildcard_test.loup` (a table of
pattern/name cases, and expansion over a tree built under `build/tmp/`) and
`tests/win_paths_test.loup` travel with the modules.
