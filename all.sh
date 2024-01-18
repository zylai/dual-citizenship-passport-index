#!/bin/bash

# Numbers correspond to color codes and visa requirements on passportindex.org
# 0  =  red     =  visa required
# 1  =  blue    =  visa on arrival
# 2  =  green   =  visa free
# 3  =  orange  =  eTA

command -v jq &>/dev/null || { echo "\`jq\` is not installed. Exiting..."; exit 1; }
command -v bc &>/dev/null || { echo "\`bc\` is not installed. Exiting..."; exit 1; }

storage="/tmp/passportcombo-`date +"%Y-%m-%d"`"

mkdir $storage &>/dev/null || { echo "Cannot create temp folder at $storage. Exiting..."; exit 1; }

trap "rm -r $storage" EXIT

curl -s 'https://www.passportindex.org/incl/compare2.php' -X POST -H 'X-Requested-With: XMLHttpRequest' --data-raw 'compare=1' > $storage/raw.json

jq keys $storage/raw.json | grep \" | cut -c 4-5 | tee -i $storage/country_list.txt $storage/country_remaining.txt > /dev/null

num_countries=`wc -l < $storage/country_list.txt | xargs`

for country_a in $(cat $storage/country_list.txt)
do
	country_a_vf_destinations=`jq ".$country_a.destination[] | select(.text_col==2) | .code" $storage/raw.json | tr -d \"`
	country_a_voa_destinations=`jq ".$country_a.destination[] | select(.text_col==1) | .code" $storage/raw.json | tr -d \"`
	country_a_eta_destinations=`jq ".$country_a.destination[] | select(.text_col==3) | .code" $storage/raw.json | tr -d \"`

	for country_b in $(cat $storage/country_remaining.txt)
	do
		if [ "$country_a" == "$country_b" ]; then
			continue
		fi

		country_b_vf_destinations=`jq ".$country_b.destination[] | select(.text_col==2) | .code" $storage/raw.json | tr -d \"`
		country_b_voa_destinations=`jq ".$country_b.destination[] | select(.text_col==1) | .code" $storage/raw.json | tr -d \"`
		country_b_eta_destinations=`jq ".$country_b.destination[] | select(.text_col==3) | .code" $storage/raw.json | tr -d \"`

		combo_vf=`echo "$country_a_vf_destinations $country_b_vf_destinations" | tr " " "\n" | sort | uniq | tr "\n" " "`
		combo_voa=`echo "$country_a_voa_destinations $country_b_voa_destinations" | tr " " "\n" | sort | uniq | tr "\n" " "`
		combo_eta=`echo "$country_a_eta_destinations $country_b_eta_destinations" | tr " " "\n" | sort | uniq | tr "\n" " "`

		combo_score=0

		for country in $(cat $storage/country_list.txt)
		do
			echo $combo_vf | grep -q $country
			if [ $? == "0" ]; then
				combo_score=`echo "scale=3; $combo_score + 1" | bc`
			else
				echo $combo_voa | grep -q $country
				if [ $? == "0" ]; then
					combo_score=`echo "scale=3; $combo_score + 0.75" | bc`
				else
					echo $combo_eta | grep -q $country
					if [ $? == "0" ]; then
						combo_score=`echo "scale=3; $combo_score + 0.5" | bc`
					fi
				fi
			fi
		done

		printf "$country_a;$country_b;$combo_score\n"
	done

	echo "`tail -n +2 $storage/country_remaining.txt`" > $storage/country_remaining.txt
done

exit 0
