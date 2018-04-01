#!/bin/bash

function usage() {
	cat << EOF
Usage: $0 -w watermark_file [-d dataset_dir | -D datasets_dir | -F dataset_file ] [-n dataset_name] [-r result_dir] [-f frame_length]

	-w - path to watermark image file, mandatory

	Options to specify dataset(s). In order of priority:
	-F - path to file containing list of dataset paths
	-D - path to directory containing dataset sub-directories
	-d - path to the dataset directory
	You should specify only one of options above

	-n - name of dataset (default value is name of directory of dataset)
	-r - resulting directory (default value is ./videos)
	-f - frame length (default value is 20 sec)

	Examples:
		$0 -w dataset/watermark.png -d dataset/grison -f 2
		$0 -w dataset/watermark.png -D dataset
		$0 -w dataset/watermark.png -F datasets.txt

	Suggestions:
		- Text file with list of steps must be named steps.txt and placed in dataset directory
			Example: dataset/grison/steps.txt
		- Text file must have one step per line
		- Image files must be named as [dataset_name]-[frame_number].png
			- dataset_name - directory name or argument from switch -n
			- frame_number - number with leading 0 and starting from 1
			Example: dataset/grison/grison-01.png
		- Resulting video file will be saved as [result_dir]/[dataset_name].mp4

EOF
	exit 0
}

function log() {
	local M=$1
	echo $M
}

function err() {
	log "$1. Exiting.."
	exit 1
}

function process_video() {
	local NAME=$1 DIR=$2
	local FILE N=0
	local TEXT_FILE=$DIR/steps.txt
	local VIDEO=${RESULT_DIR}/${NAME}.mp4
	local CONCAT_FILE=${RESULT_DIR_TMP}/${NAME}-concat.txt

	[ $NAME ] || err "No dataset name specified"
	[ $DIR ] || err "No dataset directory specified"

	log
	log "[ Start processing '$NAME' in '$DIR' ]"
	log

	log "=> [ Dataset directory '$DIR' ]"
	log "=> [ Text file '$TEXT_FILE' ]"
	log "=> [ Concat file '$CONCAT_FILE' ]"
	log "=> [ Output filename '$VIDEO' ]"

	rm -f $CONCAT_FILE

	for FILE in $(find $DIR -depth 1 -type f -name "$NAME*.png" | sort -n); do
		let N++
		TEXT=$(sed -n ${N}p $TEXT_FILE)
		process_step "$NAME" "$FILE" "$TEXT" "$CONCAT_FILE"
	done

	if [ -s $CONCAT_FILE ]; then
		log "=> [ Concatenating files in '$CONCAT_FILE' ]"
		$FFMPEG -v warning -f concat -i $CONCAT_FILE -c copy -y $VIDEO
	else
		log "=> [ Concat file '$CONCAT_FILE' not found or empty. Skipping.. ]"
	fi

	log "=> [ Deleting temporary files ]"
	rm -f ${RESULT_DIR_TMP}/${NAME}-*
}

function process_step() {
	local NAME=$1 FILE=$2 TEXT=$3 CONCAT_FILE=$4
	local VIDEO=${RESULT_DIR_TMP}/$(basename $FILE).mp4
	local TEXT_FILE=${RESULT_DIR_TMP}/${NAME}-step.txt

	[ $NAME ] || err "No dataset name specified"
	[ $FILE ] || err "No current file specified"
	[ "$TEXT" ] || err "No text line specified"
	[ $CONCAT_FILE ] || err "No concat file specified"

	echo "==> [ Processing image file '$FILE' ]"
	echo "===> [ Video temporary file '$VIDEO' ]"
	echo "===> [ Text to be added '$TEXT' ]"
	echo "===> [ Text temporary file '$TEXT_FILE' ]"

	echo "file '$(basename $FILE).mp4'" >> $CONCAT_FILE
	echo $TEXT | fold -s -w 80 > $TEXT_FILE

	$FFMPEG -v warning \
		-loop 1 -i $FILE \
	 	-i $WATERMARK \
		-filter_complex "[0]fps=25,format=yuv420p[a];[a]overlay=W-w-10:H-h-10,format=yuv420p[b];[b]drawtext=fontsize=$FONTSIZE:textfile=$TEXT_FILE:fontfile=$FONT:fontcolor=$FONTCOLOR:x=(w-text_w)/2:y=10,format=yuv420p[out]" \
		-map "[out]" -t $FRAME -c:v libx264 -crf 10 -y $VIDEO
}

PATH=.:$PATH
FFMPEG=$(which ffmpeg)
FONT='./FreeSans.ttf'
FONTSIZE='20'
FONTCOLOR='333333'
RESULT_DIR_TMP='/tmp/creating-videos-tmp'

unset -v WATERMARK DATASET DATASET_DIR DATASET_FILE NAME RESULT_DIR FRAME

RESULT_DIR='./videos'
FRAME='20'

while getopts ":w:d:D:F:n:r:f:h" opt; do
	case $opt in
		'w')
			WATERMARK=$OPTARG
			;;
		'd')
			DATASET=$OPTARG
			;;
		'D')
			DATASET_DIR=$OPTARG
			;;
		'F')
			DATASET_FILE=$OPTARG
			;;
		'n')
			NAME=$OPTARG
			;;
		'r')
			RESULT_DIR=$OPTARG
			;;
		'f')
			FRAME=$OPTARG
			;;
		'h')
			usage
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			usage
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			usage
			;;
	esac
done

[ "$WATERMARK" ] || err "Watermark not specified"
[ -f "$WATERMARK" ] || err "Watermark file not found"

mkdir -p $RESULT_DIR $RESULT_DIR_TMP

if [ "$DATASET_FILE" ]; then

	[ -f "$DATASET_FILE" ] || err "Dataset file '$DATASET_FILE' not found"

	for DATASET in $(cat $DATASET_FILE); do
		[ -d "$DATASET" ] || log "Dataset directory '$DIR' not found. Skipping.."
		NAME=$(basename $DATASET)
		process_video "$NAME" "$DATASET"
	done

elif [ "$DATASET_DIR" ]; then

	[ -d "$DATASET_DIR" ] || err "Datasets directory '$DATASET_DIR' not found"

	for DATASET in $(find $DATASET_DIR -depth 1 -type d); do
		[ -d "$DATASET" ] || log "Dataset directory '$DIR' not found. Skipping.."
		NAME=$(basename $DATASET)
		process_video "$NAME" "$DATASET"
	done

elif [ "DATASET" ]; then

	NAME=${NAME:-$(basename $DATASET)}
	process_video "$NAME" "$DATASET"

else

	err "No dataset specified"

fi
