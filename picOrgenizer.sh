#!/bin/bash

function showHelp {
	echo "
	picOrgenizer  version 1.0
	
	picOrgenizer comes with ABSOLUTELY NO WARRANTY.  This is free software, and you
	are welcome to redistribute it under certain conditions.  See the GPLv3
	General Public Licence for details

	picOrgenizer is a program capable of finding image files in local or remote
	locations, rearrange and index them hierarchicaly by creation time


	Options:
	 -v, --verbose               increase verbosity
	 -d, --directory             search path root
	 -t  --target                directory where hierarchical structure will be created 
	 --remove-src                remove source file after successful copy"
}

function setDefaults {
	TARGET=~/picOrgenizer # TODO: exclude this
	DIRECTORY=~/Pictures	
	REMOVE_SOURCE=0
	VERBOSE=0
}

function printOpts {
	if [ $VERBOSE = 1 ]; then
		echo "----------------------------------------------"
		echo DIRECTORY  = "$DIRECTORY"
		echo TARGET     = "$TARGET"
		echo REMOVE_SOURCE     = "$REMOVE_SOURCE"
		echo "----------------------------------------------"
	fi
}

function validateInput {
	if [ ! -d "$TARGET" ]; then
		if [ $VERBOSE = 1 ]; then
			echo target directory does not exist. creating...
		fi
		$(mkdir "$TARGET")
	fi	
}

function initTargetFolder {
	mkdir -p "$TARGET"/"$1"	
	
	LOCAL_INDEX="$TARGET"/"$1"/index.html

	if [ ! -f $LOCAL_INDEX ];
	then
		if [ $VERBOSE = 1 ]; then
			echo "File $LOCAL_INDEX does not exist. creating..."
		fi
		createIndexFile "$LOCAL_INDEX" "photo orgenizer index file" "$1 Photos index page"
		addLinkEntryToMainIndex "$1"
	fi	
}

function createMainIndexFile {
	MAIN_INDEX_FILE="$TARGET"/index.html
	MAIN_FILE_HEADER="Photos index page ( $(date +"%D %T") )"
	createIndexFile "$MAIN_INDEX_FILE" "photo orgenizer main index file" "Photos main index page ( $(date +"%D %T") )"
}

function closeMainIndexFile {
	if [ $VERBOSE = 1 ]; then
		echo "closing main file:$MAIN_INDEX_FILE"
	fi
	echo "</body>" >> "$MAIN_INDEX_FILE"
	echo "</html>" >> "$MAIN_INDEX_FILE"
}

function closeIndexFile {
	if [ $VERBOSE = 1 ]; then
		echo "closing index file:$1"
	fi
	echo "</table>" >> "$1"
	echo "</body>" >> "$1"
	echo "</html>" >> "$1"
}

# $1 - full path of index file
# $2 - title for html page
# $3 - page header
function createIndexFile {
	touch "$1"
	echo "<html>" >> "$1"
	echo "<head>" >> "$1"
	echo "<title>$2</title>" >> "$1"
	echo "</head>" >> "$1"
	echo "<body>" >> "$1"
	echo "<h1>$3</h1><br><br>" >> "$1"
	echo "<table>" >> "$1"
}

# $1 - relative path under target folder
# $2 - image name
function addLinkEntryToLocalIndex {	
	local local_index="$TARGET"/"$1"/index.html
	echo  "<tr><td><img src=\""$2"\" height=\"48\"></td>" >> "$local_index"
	echo "<td><a href=\""$2"\">$2</a></td</tr>" >> "$local_index"
}

# $1 - relative path under target folder
function addLinkEntryToMainIndex {	
	local path=./"$1"/index.html
	echo "<a href=\""$path"\">$1</a><br>" >> "$MAIN_INDEX_FILE"
}

setDefaults

#
# get options
#
if [ $# = 0 ]; then	
	if [ $VERBOSE = 1 ]; then
		echo "no args. running with defaults"
	fi
else
	while :
	do
		 case "$1" in
		   -d | --directory)
		  DIRECTORY="$2"   # You may want to check validity of $2
		  shift 2
		  ;;
		   -h | --help)
		  showHelp  # Call your function
		  # no shifting needed here, we're done.
		  exit 0;break
		  ;;
		   -t | --target)
		  TARGET="$2" # You may want to check validity of $2
		  shift 2
		  ;;
		  --remove-src)		      
		  REMOVE_SOURCE=1
		  shift
		  ;;		  
			-v | --verbose)		      
		  VERBOSE=1
		  shift
		  ;;		  
		  *)  # No option			
		  	break;
		  ;;
		 esac
	done
fi
#
# END - get options
#

printOpts
validateInput

if [ $VERBOSE = 1 ]; then
	read -p "Press [Enter] key to start operation..."
fi

#
# start execution time measurement
#
START_TIME=$(date)

createMainIndexFile

find "$DIRECTORY" -name "*" -exec file {} \; | grep -o -P "^.+: \w+ image" | while read line; do
	FILE="${line%:*}"
	
	if [ $VERBOSE = 1 ]; then
		echo "---------------------------------------------------------"
		echo "Processing file->${line}"
		echo "file->${FILE}"
		echo "file meta->$(exiv2 "${FILE}")"
	fi	

	TIMESTAMP_LINE=$(exiv2 "${FILE}" | grep "Image timestamp")

	if [ "$TIMESTAMP_LINE" = "" ]; then		
		IMG_PATH="unsorted"
	else
		TIMESTAMP=${TIMESTAMP_LINE#*:} # keep only date	
		TIMESTAMP=$(echo "$TIMESTAMP" | sed 's/ *$//' | sed 's/^ *//')	# trim from both sides
		TIMESTAMP=${TIMESTAMP/' '/:} # replace space with colon in the middle

		# create Date/Time array
		OIFS=$IFS
		IFS=':'
		DATE_ARR=($TIMESTAMP)	
		IFS=$OIFS

		IMG_PATH="${DATE_ARR[0]}/${DATE_ARR[1]}/${DATE_ARR[2]}"
	fi	

	initTargetFolder "$IMG_PATH"

	FILENAME="${FILE##*/}" # get substring from the last index of '/'	
	TARGET_FILE="$TARGET"/"$IMG_PATH"/"$FILENAME"		

	if [ $VERBOSE = 1 ]; then
		echo "target file name->$TARGET_FILE"
	fi

	if [ $REMOVE_SOURCE = 1 ]; then
		OPTIONS="--remove-source-files"
	fi

	if [ -z ${OPTIONS+x} ]; then		
		rsync "$FILE" "$TARGET_FILE"	
	else
		rsync "$OPTIONS" "$FILE" "$TARGET_FILE"
	fi
	
	addLinkEntryToLocalIndex "$IMG_PATH" "$FILENAME"	
done

echo "---------------------------------------------------------"

find "$TARGET" -name "index.html" -exec file {} \; | while read line; do
	FILE="${line%:*}"	

	if [ "$FILE" = "$MAIN_INDEX_FILE" ]; then
		closeMainIndexFile
	else		
		closeIndexFile "$FILE"	
	fi	
done

#
# end execution time measurement
#
END_TIME=$(date)
EXEC_TIME=$(date -d @$(( $(date -d "$END_TIME" +%s) - $(date -d "$START_TIME" +%s) )) -u +'%H:%M:%S')
echo "execution time->$EXEC_TIME"
