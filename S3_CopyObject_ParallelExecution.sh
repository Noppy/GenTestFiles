#!/bin/bash

# Configuration
Target_List_CSV_FILE="list_of_copy_files.csv"
NumOfParallels=${1:-800}
SummaryResultCSVFile=${2:-ResultsSummary_CopyObject.csv}
DetailResultsFile=${3:-ResultsDetail}
AwsRetry=20
ExecCommand=./S3_CopyObject.py


function help {
    echo "S3_CopyObject_ParallelExecution.sh NumOfParallels SummaryResultsCSVFile"
    echo "    NumOfParallels : Specify a number of Parallels."
    echo "    SummaryResultsCSVFile : Specify FileName of the results report file."
}


# Initialize
rows=$(grep -c '' ${Target_List_CSV_FILE})
NumOfsplitLines=$(( rows/NumOfParallels ))


#------------------------
# Functions
#------------------------
function utcserial2date {
    #echo $(date -j -f '%s' ${1} '+%Y/%m/%d %H:%M:%S') #for mac
    echo $(date --date="@${1}" '+%Y/%m/%d %H:%M:%S')  #for linux
}

#------------------------
# Main
#------------------------
# Start message
echo "Start test: targetfile=${rows} parallels=${NumOfParallels} Retry=${AwsRetry}"

# Split Target_List_CSV_FILE
split -a 5 -l ${NumOfsplitLines} ${Target_List_CSV_FILE} "test_3_target_list_"

# Run by background
echo "Run test programs."
StartTime=$(date '+%s')

i=0
for target in test_3_target_list_*
do
    ${ExecCommand} -i ${target} -o test_3_results_temp_$(printf "%05d" $i) -r ${AwsRetry} &
    i=$((i+1))
done

# Wait
while [ $( ps -f |grep "${ExecCommand}"|grep -cv grep ) -gt 0 ]
do
    sleep 1
done
EndTime=$(date '+%s')
echo "Done all test programs."

# Print result
cat test_3_results_temp_* > ${DetailResultsFile}_${rows}_${NumOfParallels}.csv
rm test_3_results_temp_*
success=$(grep -c Success ${DetailResultsFile}_${rows}_${NumOfParallels}.csv )
failed=$(grep -c Failed ${DetailResultsFile}_${rows}_${NumOfParallels}.csv )
total=$(( success+failed ))

echo "NumOfFiles, NumOfParallels, ExeTime(sec), StartTime, EndTime, SuccessedFiles, FailedFiles, TotalFiles"
echo "${rows},${NumOfParallels},$((EndTime-StartTime)),$(utcserial2date ${StartTime}),$(utcserial2date ${EndTime}),${success},${failed},${total}" >> ${SummaryResultCSVFile}
echo "${rows},${NumOfParallels},$((EndTime-StartTime)),$(utcserial2date ${StartTime}),$(utcserial2date ${EndTime}),${success},${failed},${total}"


# Finall
rm test_3_target_list_*
