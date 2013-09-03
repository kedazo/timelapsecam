#!/bin/bash
#
# Time-lapse script
#
# 2013 - David Kedves <kedazo@gmail.com>
#

# some global options
DEBUG=1
SHOTJPEGQ=99
# this can help if the webcams first image is incorrect
BADCAMHACK=1

# variables to be initialized
WEBCAMDEV="/dev/video0"
WEBCAMINFO=""
CAPTURESIZE="640x480"
SHOTPERMIN=6
TOTALMINUTES=0
TMPDIR=""
WORKDIR="."

VIDEO_FPS=20
VIDEO_TYPE=mp4
VIDEO_KBITRATE=512

# parameters: binary, package name
function check_app() {
    if which $1 &> /dev/null && [ "${DEBUG}x" = "1x" ]; then
        echo "Debug: $2 is installed."
    else
        echo "Error: $2 is not installed." 1>&2
        exit 1
    fi
}

# check for the needed applications
function check_applications() {
    check_app /usr/bin/v4l-info v4l-conf
    check_app /usr/bin/streamer streamer
    check_app /usr/bin/ffmpeg ffmpeg
}

# to check webcam and the resolution
function check_webcam() {
    if [ ! -e "${WEBCAMDEV}" ]; then
        echo "Error: Invalid device: ${WEBCAMDEV}"
        exit 1
    fi
    WEBCAMINFO=$(v4l-info ${WEBCAMDEV} | egrep -e "(card|fmt)")
    NAME=$(echo "${WEBCAMINFO}" | grep 'card' | cut -d: -f2)
    MAXWIDTH=$(echo "${WEBCAMINFO}" | grep 'fmt.pix.width' | cut -d: -f2)
    MAXHEIGHT=$(echo "${WEBCAMINFO}" | grep 'fmt.pix.height' | cut -d: -f2)
    echo "Selected camera: ${NAME} (${WEBCAMDEV})"
    echo "Camera resolution: $((MAXWIDTH))x$((MAXHEIGHT))"
    WIDTH=$(echo ${CAPTURESIZE} | cut -dx -f1)
    HEIGHT=$(echo ${CAPTURESIZE} | cut -dx -f2)
    # correcting width if invalid
    if [ $((WIDTH)) -le 0 -o $((WIDTH)) -gt $((MAXWIDTH)) ]; then
        WIDTH=${MAXWIDTH}
    fi
    # and correcting height if invalid
    if [ $((HEIGHT)) -le 0 -o $((HEIGHT)) -gt $((MAXHEIGHT)) ]; then
        HEIGHT=${MAXHEIGHT}
    fi
    CAPTURESIZE="$((WIDTH))x$((HEIGHT))"
    echo "Selected resolution: ${CAPTURESIZE}"
}

# check the capture timing / length parameters
function check_sleep_and_length() {
    if [ $((SHOTPERMIN)) -le 1 ]; then
        echo "Error: invalid frames-per-minute value: ${SHOTPERMIN}"
        usage
        exit 1
    fi
    if [ $((TOTALMINUTES)) -lt 1 ]; then
        echo "Error: invalid time-to-capture value: ${TOTALMINUTES}"
        usage
        exit 1
    fi
}

# this method does the real captures
function capture_frames() {
    TMPDIR=$(mktemp -d --suffix=timelaps --tmpdir="$(pwd)")
    # some options for 'streamer'
    STREAMEROPTS="-j ${SHOTJPEGQ} -c ${WEBCAMDEV} -s ${CAPTURESIZE}"
    COUNTER=0
    while test $((TOTALMINUTES--)) -gt 0; do
        TMP=$((SHOTPERMIN))
        while test $((TMP--)) -gt 0; do
            DEST=${TMPDIR}/shot.jpeg
            if [ "${BADCAMHACK}x" = "1x" ]; then
                DEST=${TMPDIR}/shot000.jpeg
                # the first captured frame is broken (integrated webcams)
                streamer ${STREAMEROPTS} -t 2 -o "${DEST}"
                # take the second shot
                DEST=${TMPDIR}/shot001.jpeg
            else
                # the first captured frame is OK
                streamer ${STREAMEROPTS} -o "${DEST}"
            fi
            # move the current capture to its final destination
            FINALNAME=${TMPDIR}/movie_$(printf "%06d" ${COUNTER}).jpg
            mv "${DEST}" "${FINALNAME}"
            # wait until the next capture
            sleep $((60/SHOTPERMIN))
            # and increase the counter
            let "COUNTER = COUNTER+1"
        done
        echo "* $((TOTALMINUTES)) mins left."
    done
    echo "* captured ${COUNTER} frames."
}

# this function creates the video from the webcam shots
function create_video() {
    VIDEO_FILENAME=$(date +%F_%H%M).${VIDEO_TYPE}
    echo "* creating video (using $((VIDEO_FPS)) shots / sec)"
    # do the actual conversion
    ffmpeg -f image2 -r $((VIDEO_FPS)) -i "${TMPDIR}/movie_%06d.jpg" -y \
           -b $((VIDEO_KBITRATE*1024)) -r 25 "${VIDEO_FILENAME}" || exit 1
    # and clean up the temporary files
    rm -rf ${TMPDIR}
    # and write out the filename
    echo ""
    echo "* Created video: ${VIDEO_FILENAME}"
    echo "* Path: ${WORKDIR}"
}

# this functions returns some info (about cameras) for the gui
function show_info() {
    # lets check the first 10 webcamera
    for devid in seq 0 10; do
        if [ ! -e /dev/video${devid} ]; then
            continue; # no camera
        fi
        WEBCAMINFO=$(v4l-info /dev/video${devid} | egrep -e "(card|fmt)")
        NAME=$(echo "${WEBCAMINFO}" | grep 'card' | cut -d: -f2)
        MAXWIDTH=$(echo "${WEBCAMINFO}" | grep 'fmt.pix.width' | cut -d: -f2)
        MAXHEIGHT=$(echo "${WEBCAMINFO}" | grep 'fmt.pix.height' | cut -d: -f2)
        # print out the infos in CSV format
        echo "/dev/video${devid};$((MAXWIDTH));$((MAXHEIGHT));${NAME}"
    done
}

function exitfail() {
    echo ""
    echo "Error: $@"
    exit 1
}

function check_workdir() {
    cd "${WORKDIR}" &> /dev/null || exitfail "Directory '${WORKDIR}' not exists."
    echo "test" > .testfile &> /dev/null || exitfail "Directory ${WORKDIR} is not writable."
    rm -f .testfile
}

# to show the command line usage
function usage() {
cat << USAGE
Usage: $0 options

OPTIONS:
    -h   shows this message
    -d   the video device (default: ${WEBCAMDEV})
    -s   the capture resolution (default: ${CAPTURESIZE})
    -f   the amount of captured frames per minute (default: ${SHOTPERMIN} shots/min)
    -t   time to capture (in minutes)
    -o   output video frames per second (default: ${VIDEO_FPS} shots/sec)
    -b   bitrate of the output video (default: ${VIDEO_BITRATE} kbit/sec)
    -c   the video container (mp4, avi, mpg) (default: ${VIDEO_TYPE})
    -w   working and temporary directory (default: ${WORKDIR})
USAGE
}

while getopts "ihd:s:f:t:o:b:c:w:" OPTION
do
    case $OPTION in
         i)
            show_info
            # we're not doing anything now so exiting
            exit
            ;;
         h)
            usage
            exit 1
            ;;
         d)
            WEBCAMDEV=$OPTARG
            ;;
         s)
            CAPTURESIZE=$OPTARG
            ;;
         f)
            SHOTPERMIN=$OPTARG
            ;;
         t)
            TOTALMINUTES=$OPTARG
            ;;
         o)
            VIDEO_FPS=$((OPTARG))
            ;;
         b)
            VIDEO_BITRATE=$OPTARG
            ;;
         c)
            VIDEO_TYPE=$OPTARG
            ;;
         w)
            WORKDIR="$OPTARG"
            ;;
         ?)
            usage
            exit
            ;;
    esac
done

check_workdir
cd "${WORKDIR}" 
check_applications
check_webcam
check_sleep_and_length
capture_frames
create_video

