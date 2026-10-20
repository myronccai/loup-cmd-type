# Requirements: type

## Introduction

`type` is the cmd.exe built-in that writes the contents of text files to
standard output. This repository recreates it in Loup for Linux, keeping
Windows' operand syntax (`\` separators, `*` and `?` wildcards expanded by
the command itself, `/?` help), messages and ERRORLEVELs. It is the first
Windows command in the loup-cmd series and introduces the shared Windows
code in `source/win/` (see [../windows-conventions/](../windows-conventions/)).

## Requirements

### Requirement 1: Show files

**User Story:** As a cmd user, I want to print files so that I can read or
concatenate them.

#### Acceptance Criteria

1. WHEN type is given one file, THE program SHALL write its contents to
   standard output unchanged, byte for byte, and exit with status 0.
2. WHEN a file starts with the UTF-16LE byte order mark (FF FE), THE program
   SHALL write its text converted to UTF-8, without the mark.
3. WHEN type is given several operands, THE program SHALL show them in
   command-line order.
4. WHEN more than one file is shown, THE program SHALL write, before each
   file, a blank line, the file's name and two blank lines to standard
   error, so that redirecting standard output collects only the contents.
5. THE program SHALL accept `\` and `/` as separators in operands, and SHALL
   print names with `\`.

### Requirement 2: Wildcards

**User Story:** As a cmd user, I want `type *.txt` to work, since cmd does
not expand wildcards for me.

#### Acceptance Criteria

1. WHEN the last component of an operand contains `*` or `?`, THE program
   SHALL show every matching file in that directory, sorted by name without
   regard to case, skipping directories.
2. THE program SHALL match with Windows rules: case-insensitive, `?` also
   matching nothing before a `.` or at the end, `*.*` matching every name and
   `*.` matching names without an extension.
3. WHEN nothing matches, THE program SHALL report
   `The system cannot find the file specified.`
4. WHEN a wildcard appears in a directory component, THE program SHALL report
   `The filename, directory name, or volume label syntax is incorrect.`

### Requirement 3: Errors

**User Story:** As a script author, I want Windows' messages and ERRORLEVELs
so that scripts written for cmd behave the same.

#### Acceptance Criteria

1. WHEN no operand is given, THE program SHALL print
   `The syntax of the command is incorrect.` on standard error and exit 1.
2. WHEN a file does not exist, THE program SHALL print
   `The system cannot find the file specified.`, or
   `The system cannot find the path specified.` when its directory does not
   exist; WHEN the operand is a directory, `Access is denied.`
3. WHEN an operand fails and type was given several files, THE program SHALL
   follow the message with `Error occurred while processing: NAME.` and go on
   with the next operand.
4. WHEN any operand fails, THE program SHALL exit with status 1.

### Requirement 4: Switches

**User Story:** As a cmd user, I want `type /?` to explain the command.

#### Acceptance Criteria

1. WHEN `/?` or `-?` appears among the arguments, THE program SHALL print
   Windows' help text and exit 0.
2. THE program SHALL treat every other argument, including `/X` and `-X`, as
   a file name (type has no switches), and everything after `--` as a file
   name.
3. WHEN `--version` is the only argument, THE program SHALL print
   `type (loup-cmd-type) 0.1.0`; `--help` alone SHALL print the help.
