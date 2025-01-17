#! /bin/bash

# Replace with root of package analysis folder
PACKAGE_ANALYSIS_ROOT=~/package-analysis

# This script runs static analysis on all packages in a directory and
# creates a new directory with all the static analysis results for each package.
# Currently, it only supports NPM packages (as static analysis does).


RUN_ANALYSIS="$PACKAGE_ANALYSIS_ROOT/scripts/run_analysis.sh"
FORMAT_JSON="$PACKAGE_ANALYSIS_ROOT/scripts/format-static-analysis-json.py"

if ! [[ -x "$RUN_ANALYSIS" ]]; then
	echo "could not locate run_analysis.sh script at $RUN_ANALYSIS"
	exit 1
elif ! [[ -x "$FORMAT_JSON" ]]; then
	echo "could not locate format-json.py script at $FORMAT_JSON"
	exit 1
fi

ARCHIVES_DIR="$1"
RESULTS_DIR=${2:-"$ARCHIVES_DIR-results"}
START_LETTER="$3"

if [[ -z "$ARCHIVES_DIR" ]]; then
	echo "Archives dir not provided, please specify directory of .tgz archives"
	exit 1
fi

if [[ ! -d "$ARCHIVES_DIR" ]]; then
	echo "error: archives dir is not a directory"
	exit 1
fi


mkdir -p "$RESULTS_DIR"

function process_archive {
	ARCHIVE_PATH="$1"
	RESULTS_DIR="$2"
	START_LETTER="$3"
	if [[ -z "$ARCHIVE_PATH" ]]; then
		echo "Archive path is empty"
		return 1
	elif [[ -z "$RESULTS_DIR" ]]; then
		echo "Results dir is empty"
		return 1
	fi

	rm -rf /tmp/staticResults
	PACKAGE_VERSION_EXT=${ARCHIVE_PATH##"$ARCHIVES_DIR/"}
	PACKAGE_VERSION=${PACKAGE_VERSION_EXT%%.tgz}
	PACKAGE_FIRST_LETTER=${PACKAGE_VERSION:0:1}
	if [[ "$PACKAGE_FIRST_LETTER" < "$START_LETTER" ]]; then
		echo SKIP "$PACKAGE_VERSION"
		return
	fi
	# package name is everything before the last '-' character
	# package version is everything between the last '-' character and .tgz
	PACKAGE=$(python3 -c "print('-'.join(\"$PACKAGE_VERSION\".split('-')[:-1]))")
	VERSION=$(python3 -c "print(\"$PACKAGE_VERSION\".split('-')[-1])")
	echo "Package: $PACKAGE"
	echo "Version: $VERSION"

	OUTPUT_RESULTS_DIR=$(mktemp -d)
	STATIC_RESULTS_DIR=$OUTPUT_RESULTS_DIR "$RUN_ANALYSIS" -ecosystem npm -package "$PACKAGE" -local "$ARCHIVE_PATH" -nopull -mode static -offline -fully-offline -nointeractive

	# pretty print while keeping some of the small JSON structs on a single line
	"$FORMAT_JSON" "$OUTPUT_RESULTS_DIR/results.json" "$RESULTS_DIR/$PACKAGE_VERSION-results.json"

	rm -rf "$OUTPUT_RESULTS_DIR"
}

for ARCHIVE_PATH in "$ARCHIVES_DIR"/*.tgz; do
	process_archive "$ARCHIVE_PATH" "$RESULTS_DIR" "$START_LETTER"
done

# TODO parallelise loop
# export -f process_archive
# shopt -s nullglob
# ARCHIVES=("$ARCHIVES_DIR"/*.tgz)
# parallel -i process_archive "{}" "$RESULTS_DIR" "$START_LETTER" ::: ${ARCHIVES[@]}
