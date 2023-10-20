#!/bin/bash

# $1: directory
# return: list of files with dir name as prefix
function GetFilesInDir() {
    local res=''
    for file in $(ls $1); do
	res="$res $1/$file"
    done
    echo $res
}

# $1: file name
function SplitChars() {
    sed 's/\(.\)/\1\n/g' $1 > $1.tmp
}

# $1: list of files
function SplitAllFilesInDir() {
    for file in $1; do
	SplitChars $file
    done
}

# $1: file1; $2: file2
# return: percentage of equality
function GetDiff() {
    local f1_len=$(cat $1.tmp | wc -l)
    local f2_len=$(cat $2.tmp | wc -l)
    local max_len=$(echo $f1_len$'\n'$f2_len | sort -n -r | head -1)

    local difference=$(sdiff -s $1.tmp $2.tmp | wc -l)

    echo $(( 100 * ($max_len - $difference) / $max_len ))
}

# $1: Associative array where result will be written; $2: list of files;
# $3: list of files
function GetDiffsList() {
    local -n res=$1
    for f1 in $2; do
	for f2 in $3; do
	    res["$f1 - $f2"]=$(GetDiff $f1 $f2)
	done
    done
}


# $1: Associative array of files pair and their equality
function EchoEqualFiles() {
    local -n diffs_ref=$1
    for key in "${!diffs_ref[@]}"; do
	if [[ ${diffs_ref[$key]} = 100 ]]; then
	    echo $key
	fi
    done
}

# $1: Associative array of files pair and their equality;
# $2: min equality value to decide that files are the same
function EchoSameFiles() {
    local -n diffs_ref=$1
    for key in "${!diffs_ref[@]}"; do
	local same=${diffs_ref[$key]}
	if [[ $same != 100 && $same -ge $2 ]]; then
	    echo $key $same
	fi
    done
}

# $1: Associative array of files pair and their equality;
# $2: list of files; $3: list of files
# $4: min equality value to decide that files are the same;
# $5: is need to reverse files order in key
function EchoUniqueFilesHelper() {
    local -n diffs_ref=$1

    if [[ $5 = true ]]; then
	loop=$3
	nested_loop=$2
    else
	loop=$2
	nested_loop=$3
    fi
    
    for f1 in $loop; do
	local is_unique=true
	for f2 in $nested_loop; do
	    if [[ $5 = true ]]; then
		local key="$f2 - $f1"
	    else
		local key="$f1 - $f2"
	    fi
	    
	    if [[ ${diffs_ref[$key]} -ge $4 ]]; then
		is_unique=false
		break
	    fi
	done

	if [[ $is_unique = true ]]; then
	    echo $f1
	fi
    done
}


# $1: Associative array of files pair and their equality;
# $2: list of files; $3: list of files;
# $4: min equality value to decide that files are the same
function EchoUniqueFiles() {
    EchoUniqueFilesHelper $1 "$2" "$3" $4 false
    EchoUniqueFilesHelper $1 "$2" "$3" $4 true
}

# $1: list of files without *.tmp suffix
function RemoveTmpFiles() {
    for file in $1; do
	rm $file.tmp
    done
}

# $1: directory; $2: directory;
# $3: min equality value to decide that files are the same
function Main() {
    local files1=$(GetFilesInDir $1)
    local files2=$(GetFilesInDir $2)

    SplitAllFilesInDir "$files1"
    SplitAllFilesInDir "$files2"

    declare -A diffs
    GetDiffsList diffs "$files1" "$files2"

    EchoEqualFiles diffs
    echo
    EchoSameFiles diffs $3
    echo
    EchoUniqueFiles diffs "$files1" "$files2" $3

    RemoveTmpFiles "$files1"
    RemoveTmpFiles "$files2"
    unset diffs
}

if [[ $# != 3 ]]; then
    echo "Usage: $0 <directory1> <directory2> <min_similarity>"
else
    Main $1 $2 $3
fi
