#!/bin/bash

# DISPLAY SECONDS IN DAYS, HOURS, MINUTES & SECONDS
function displayTime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d day%s ' $D $( (( $D > 1 )) && echo s)
  (( $H > 0 )) && printf '%d hour%s ' $H $( (( $H > 1 )) && echo s)
  (( $M > 0 )) && printf '%d minute%s ' $M $( (( $M > 1 )) && echo s)
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d second%s\n' $S $( (( $S != 1 )) && echo s)
}

# PROGRESS BAR
function progressBar {
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")
printf "Progress : [${_fill// /#}${_empty// /-}] ${_progress}%% | "
}

# VARIABLE DECLARATIONS
declare -i previous_block_timestamp
declare -i current_block_head
declare -i current_block_timestamp

# DEFINE NODE API BASE URL
node_api='http://localhost:10717'

# GET networkCode VALUE e.g. OWN_PUBLIC_BLOCKCHAIN_MAINNET
network_code=$(curl -s $node_api/node | jq -r '.networkCode')

# DEFINE START BLOCK
start_block=3 # start analysis from block 2

# GET timestamp VALUE OF BLOCK BEFORE START BLOCK
previous_block_timestamp=$(curl -s $node_api/block/$(($start_block-1)) | jq '.timestamp')

# GET CURRENT BLOCK HEAD NUMBER
current_block_head=$(curl -s $node_api/block/head/number)

# DEFINE END BLOCK
end_block=$current_block_head # end analysis at current block head number or set block # manually.

# DEFINE DOWNTIME THRESHOLD IN SECONDS WITH ms
downtime_threshold=3600000 # 1 hour = 3600.000 seconds

# GET RANGE OF BLOCKS FROM START BLOCK - END BLOCK
blockrange=$(seq $start_block $end_block)

# INIT DOWNTIME EVENT COUNTER
event_counter=0

# DEFINE REPORT FILE PATH & FORMAT
report_file=./reports/$network_code\_OUTAGE_REPORT_-_BLOCK_$(($start_block-1))-$end_block.txt

# REPORT HEADER
echo -e "####################################################################################################"\
"\n############  WeOwn Blockchain Downtime Analysis Report: "$network_code"  ############"\
"\n####################################################################################################"\
"\n##  Report started at "$(date -u +'%Y-%m-%d %H:%M:%S %Z')\
"\n##  Range of blocks analysed: "$(($start_block-1))" - "$end_block\
"\n####################################################################################################\n" | tee -a $report_file

# COMMENCE BLOCK CHECK LOOP
for i in $blockrange; do
	current_block_timestamp=$(curl -s $node_api/block/${i} | jq '.timestamp')
	difference=$((current_block_timestamp-previous_block_timestamp))
	progressBar ${i} ${end_block}
	echo -e "Analysing Block "$i" of "$end_block
		if [ $difference -ge $downtime_threshold ]; then
		((event_counter=event_counter+1))
		previous_block_timestamp_human=$(date -d @$(($previous_block_timestamp/1000)) -u +'%Y-%m-%d %H:%M:%S %Z')
		current_block_timestamp_human=$(date -d @$(($current_block_timestamp/1000)) -u +'%Y-%m-%d %H:%M:%S %Z')
		echo -e "\n####################################################################################################"\
		"\n##  DOWNTIME EVENT NUMBER "$event_counter"\n##\n##  Started at block "$(($i-1))" proposed at "$previous_block_timestamp_human"\n##  Ended   at block "$i" proposed at "$current_block_timestamp_human\
		"\n##\n##  https://explorer.weown.com/block/"$(($i-1))" | https://explorer.weown.com/block/"$i\
		"\n##\n##  The downtime lasted "$(displayTime $(($difference/1000)))\
		"\n####################################################################################################\n" | tee -a $report_file
	fi;
	previous_block_timestamp=$current_block_timestamp
	done

# REPORT FOOTER
echo -e "####################################################################################################"\
"\n##  Report ended at "$(date -u +'%Y-%m-%d %H:%M:%S %Z')\
"\n####################################################################################################" | tee -a $report_file