# Requirements: Windows conventions (shared code)

## Introduction

The loup-cmd Windows commands run on Linux but take their arguments the way
cmd.exe commands do. This spec covers the code they share, kept in
`source/win/` and copied into each Windows repository from
`ccai-examples/shared/windows/`: a switch parser, a wildcard matcher and
expander, path helpers and Windows' message texts.

## Requirements

### Requirement 1: Switches

**User Story:** As a command author, I want one parser for cmd's switch
syntax so that every Windows command accepts the same forms.

#### Acceptance Criteria

1. THE parser SHALL accept switches starting with `/` or `-`, in any case,
   anywhere among the operands.
2. WHEN `/X` or `-X` is not a switch the command declares, THE parser SHALL
   treat it as an operand (so `/tmp/a.txt` is a path).
3. THE parser SHALL support flags (`/S`), optional values (`/A`, `/A:H`,
   glued `/AH` restricted to declared characters), required values (`/T:10`,
   `/T=10`, `/T 10`, optionally glued `/LB5`) and value lists (`/XF a b`).
4. WHEN a required value is missing (end of line, a switch, `--`, or empty),
   THE parser SHALL return an error naming the switch as typed.
5. THE parser SHALL split `/S/Q` into `/S` and `/Q` when every piece is a
   declared switch, and, when asked, `/SQ` into flags (findstr style).
6. WHEN `/?` or `-?` appears, THE parser SHALL report a help request.
7. WHEN `--` appears, THE parser SHALL treat every later argument as an
   operand.
8. WHEN `--help` or `--version` is the only argument, THE parser SHALL report
   help or version.
9. THE parser SHALL keep values' case and report the switch as typed.

### Requirement 2: Wildcards

**User Story:** As a command author, I want Windows wildcard semantics so
that `del *.tmp` and `dir a?.txt` select what they select on Windows.

#### Acceptance Criteria

1. THE matcher SHALL compare names case-insensitively.
2. THE matcher SHALL implement Win32's DOS wildcards: `?` matches one
   character other than `.`, or nothing before a `.` or at the end; `*`
   before a `.` cannot consume the name's last `.`; a `.` before `?`/`*` or
   at the end also matches the end of the name. So `*.*` matches every name
   and `*.` only names without an extension.
3. THE expander SHALL turn an operand whose last component has wildcards
   into the sorted matching paths of the requested kinds (files,
   directories, both), keeping the operand's directory as typed.
4. THE expander SHALL return an operand without wildcards unchanged, and
   nothing for a wildcard in a directory component.
5. THE library SHALL list matches recursively in `/S` order (each
   directory's matches, then its subdirectories, depth first).
6. THE library SHALL sort names as an NTFS listing does (upper-case form,
   then exact form).

### Requirement 3: Paths and messages

**User Story:** As a command author, I want one convention for separators
and messages so that all Windows commands look alike.

#### Acceptance Criteria

1. THE helpers SHALL accept `\` and `/` in operands and convert them to `/`
   for file access (`fs_path`).
2. THE helpers SHALL convert `/` to `\` in every path a command prints
   (`display_path`).
3. THE helpers SHALL split, join and take apart paths with either separator.
4. THE library SHALL provide Windows' wording for the common messages.
