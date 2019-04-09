#!/bin/sh

OPTS=$(getopt -o f:d: --long file:,directory: -n 'parse-options' -- "$@")
getOptsExitCode=$?
if [ $getOptsExitCode != 0 ]; then
        echo "Failed parsing options." >&2 ;
        exit 1 ;
fi

eval set -- "$OPTS"

HELP=false

while true; do
        case "$1" in
                --file | -f ) inputFile="$2"; shift; shift ;;
                --directory | -d ) outDir="$2"; shift; shift ;;
                -- ) shift; break ;;
                * ) break ;;
        esac
done

###################################

ffprobeBin="/root/bin/ffprobe"
ffmpegBin="/root/bin/ffmpeg"
sizeWide=160
sizeHigh=90
picsW=5
picsH=5
size=$picsW"x"$picsH
timeInterval=2

spritePositionH=0
spritePositionW=0

hash $ffmpegBin 2>/dev/null || { echo >&2 "I require FFMPEG but it's not installed. compile ffmpeg in /root. Aborting."; exit 1; }
hash $ffprobeBin 2>/dev/null || { echo >&2 "I require FFMPEG but it's not installed. compile ffmpeg in /root. Aborting."; exit 1; }

if [ ! -d $outDir ]; then
        echo "Directory $outDir does not exist. I will create it for you"
        mkdir -p $outDir
        if [ $? -ne 0 ] ; then
                echo "could not create directory $outDir"
                exit 1
        else
                echo "directory $outDir created"
        fi
fi

if [ ! -f $inputFile ]; then
        echo "$inputFile file not found! Aborting."
        exit 1
fi

inputFileSuffix=$(echo $inputFile | cut -d'.' -f2)
inputFileName=$(basename -s .$inputFileSuffix $inputFile)

workDir=$outDir/$inputFileName
vttFile=$workDir/$inputFileName.vtt

mkdir -p $workDir
if [ $? -ne 0 ] ; then
        echo "could not create directory $workDir"
        exit 1
else
        echo "directory $workDir created"
fi

echo $inputFile $outDir $workDir
fileDuration=$($ffprobeBin -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 $inputFile)
fileDuration=$(echo $fileDuration | cut -d'.' -f1)

if [[ $fileDuration -gt 120 ]] && [[ $fileDuration -le 600 ]]; then
        timeInterval=5
elif [[ $fileDuration -gt 600 ]] && [[ $fileDuration -le 1800 ]]; then
        timeInterval=10
elif [[ $fileDuration -gt 1800 ]] && [[ $fileDuration -le 3600 ]]; then
        timeInterval=20
else
        timeInterval=30
fi

#$ffmpegBin -i $inputFile -vsync vfr -vf "select=isnan(prev_selected_t)+gte(t-prev_selected_t\,$timeInterval),scale=$sizeWide:$sizeHigh,tile=$size" -qscale:v 3 $workDir/$inputFileName-%03d.jpg

thumbsNumber=$(($fileDuration / $timeInterval))
echo $thumbsNumber
jpgFiles=$(($thumbsNumber / $(($picsW * $picsH))))

counter=1
echo -e "WEBVTT\n" > $vttFile

for ((k=1;k<=$(($jpgFiles+1));k++)) do
        for ((i=0;i<$picsH;i++)) do
                for ((j=0;j<$picsW;j++)) do
                        spritePositionH=$(($i*$sizeHigh))
                        spritePositionW=$(($j*$sizeWide))
                        if [[ $fileDuration -gt $(($timeInterval*$(($counter)))) ]]; then
                                startTime=$(($timeInterval*$(($counter-1))))
                                startTimeE=$(date -d@$startTime -u +%M:%S.001)
                                endTime=$(($timeInterval*$(($counter))))
                                endTimeE=$(date -d@$endTime -u +%M:%S.000)
                                if [[ $k -lt 10 ]]; then
                                        echo -e "$startTimeE --> $endTimeE\n/$inputFileName-00$k.jpg#xywh=$spritePositionW,$spritePositionH,$sizeWide,$sizeHigh\n" >> $vttFile
                                elif [[ $k -ge 10 ]] && [[ $k -lt 100 ]]; then
                                        echo -e "$startTimeE --> $endTimeE\n/$inputFileName-0$k.jpg#xywh=$spritePositionW,$spritePositionH,$sizeWide,$sizeHigh\n" >> $vttFile
                                elif [[ $k -ge 100 ]]; then
                                        echo -e "$startTimeE --> $endTimeE\n/$inputFileName-$k.jpg#xywh=$spritePositionW,$spritePositionH,$sizeWide,$sizeHigh\n" >> $vttFile
                                fi
                        fi
                        counter=$(($counter+1))
                done
        done
done
