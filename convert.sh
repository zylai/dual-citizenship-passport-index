#!/bin/bash

alpha2list=$(cat world.json | jq .[].alpha2 | tr -d \" | tr "\n" " ")

for country in $alpha2list;
do
	fullname=$(cat world.json | jq ".[] | select(.alpha2==\"$country\")" | jq .name | tr -d \")
	country_upper=$(echo $country | tr [:lower:] [:upper:])
	sed -i "" -e "s/$country_upper/$fullname/g" $1
done
