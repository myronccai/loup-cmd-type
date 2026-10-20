#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree. Names are listed in the order type shows them.
W="$TMP/w"
mkdir -p "$W/sub" "$W/u"
printf 'alpha\n' > "$W/a.txt"
printf 'ab\n' > "$W/ab.txt"
printf 'bravo\n' > "$W/b.txt"
printf 'charlie' > "$W/C.TXT"
printf 'readme\n' > "$W/README"
: > "$W/empty.txt"
printf 'sub c\n' > "$W/sub/c.txt"
printf 'sub d\n' > "$W/sub/d.log"
printf '\xff\xfeH\x00i\x00 \x00\xe9\x00\r\x00\n\x00' > "$W/u/utf16.txt"
printf 'x\xff\x00y\n' > "$W/u/binary.dat"
cd "$W"

nf='The system cannot find the file specified.'

# Help and version.
help=$'Displays the contents of a text file or files.\n\nTYPE [drive:][path]filename\n'
check_both "/? help"                0 "$help" ''              '/?'
check      "-? help"                0 "$help"                 '-?'
check      "/? among files"         0 "$help"                 a.txt '/?'
check      "--help"                 0 "$help"                 --help
check      "--version"              0 $'type (loup-cmd-type) 0.1.0\n' --version

# One file: no name header.
check_both "one file"               0 $'alpha\n' ''           a.txt
check_both "no final newline"       0 'charlie' ''            C.TXT
check_both "empty file"             0 '' ''                   empty.txt
check      "backslash path"         0 $'sub c\n'              'sub\c.txt'
check      "slash path"             0 $'sub c\n'              sub/c.txt
check      "absolute path"          0 $'alpha\n'              "$W/a.txt"
check      "dot prefix"             0 $'alpha\n'              '.\a.txt'

# Several files: names on stderr, contents on stdout.
check_both "two files"              0 $'alpha\nbravo\n' \
    $'\na.txt\n\n\n\nb.txt\n\n\n'                             a.txt b.txt
check_both "same file twice"        0 $'alpha\nalpha\n' \
    $'\na.txt\n\n\n\na.txt\n\n\n'                             a.txt a.txt
check_both "star dot txt"           0 $'alpha\nab\nbravo\ncharlie' \
    $'\na.txt\n\n\n\nab.txt\n\n\n\nb.txt\n\n\n\nC.TXT\n\n\n\nempty.txt\n\n\n' '*.txt'
check_both "question mark"          0 $'alpha\nab\n' \
    $'\na.txt\n\n\n\nab.txt\n\n\n'                            'a?.txt'
check_both "upper-case pattern"     0 $'alpha\nab\n' \
    $'\na.txt\n\n\n\nab.txt\n\n\n'                            'A?.TXT'
check_both "star dot: no extension" 0 $'readme\n' ''          '*.'
check      "star dot star"          0 $'alpha\nab\nbravo\ncharliereadme\n' '*.*'
check_both "subdirectory wildcard"  0 $'sub c\nsub d\n' \
    $'\nsub\\c.txt\n\n\n\nsub\\d.log\n\n\n'                   'sub/*'
check_both "backslash wildcard"     0 $'sub c\n' ''           'sub\*.txt'
check_both "wildcard skips dirs"    1 '' "$nf"$'\n'           'su*'

# Encodings and bytes.
check      "UTF-16LE"               0 $'Hi \xc3\xa9\r\n'      'u\utf16.txt'
printf 'x\xff\x00y\n' > "$TMP/binary"
check_file "bytes pass through"     0 "$TMP/binary"           u/binary.dat

# Errors (ERRORLEVEL 1).
check_both "no operand"             1 '' $'The syntax of the command is incorrect.\n'
check_both "missing file"           1 '' "$nf"$'\n'           nope.txt
check_both "missing directory"      1 '' $'The system cannot find the path specified.\n' 'nodir\x.txt'
check_both "a directory"            1 '' $'Access is denied.\n' sub
check_both "no match"               1 '' "$nf"$'\n'           '*.none'
check_both "wildcard in directory"  1 '' \
    $'The filename, directory name, or volume label syntax is incorrect.\n' 's*\c.txt'
check_both "one of two missing"     1 $'alpha\n' \
    $'\na.txt\n\n\n'"$nf"$'\nError occurred while processing: nope.txt.\n' a.txt nope.txt
check_both "missing then found"     1 $'bravo\n' \
    "$nf"$'\nError occurred while processing: sub\\nope.txt.\n\nb.txt\n\n\n' sub/nope.txt b.txt
check_both "unknown switch is a file" 1 '' "$nf"$'\n'         /p
check_both "-- ends switches"       1 '' "$nf"$'\n'           -- '/?'

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
