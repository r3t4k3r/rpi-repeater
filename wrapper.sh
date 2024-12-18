#!/bin/bash
config_path=$1
runner=$2

if [ ! -f $config_path ]; then
	echo "Config file not found!"
	exit 1
fi
if [ ! -f $runner ]; then
	echo "Runner not found!"
	exit 1
fi

ENV=$(cat "$config_path" | tr '\n' ' ')
env $ENV ./$runner
