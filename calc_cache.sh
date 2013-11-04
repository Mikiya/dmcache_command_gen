#!/usr/bin/env bash

# Configs
meta_header_size_bytes=4194304
meta_per_block=16
cache_meta_dev_name=ssd-metadata
cache_block_dev_name=ssd-blocks
cached_home_dev_name=home-cached

# Check args and devices

if [ $# -lt 1 ]
then
  echo "Usage: $0 {cache_dev} {slow_dev}"
  exit 1
fi

if [ ! -b $1 ]
then
  tmp=`find /dev -name $1`
  if [ ! -b $tmp ]
  then
    echo "No such device: $1"
    exit 1
  else
    cache_dev=$tmp
  fi
else
  cache_dev=$1
fi

if [ ! -b $2 ]
then
  tmp=`find /dev -name $2`
  if [ ! -b $tmp ]
  then
    echo "No such device: $2"
    exit 1
  else
    slow_dev=$tmp
  fi
else
  slow_dev=$2
fi

if [ ! -z $3 ]
then
  cache_blk_sz=$3
else
  cache_blk_sz=$((256 * 1024))
fi

# Calculation
cache_dev_size_bytes=`blockdev --getsize64 $cache_dev`

meta_size_bytes=$(($meta_header_size_bytes + ($meta_per_block * $cache_dev_size_bytes / $cache_blk_sz)))
meta_size_blocks=$(($meta_size_bytes / 512))
if [ $(($meta_size_bytes % 512)) -ne 0 ]
then
  meta_size_blocks=$(($meta_size_blocks + 1))
fi

cache_data_size_blocks=$(($cache_dev_size_bytes / 512 - $meta_size_blocks))

echo "dmsetup create $cache_meta_dev_name --table '0 $meta_size_blocks linear $cache_dev 0'"
echo "dd if=/dev/zero of=/dev/mapper/$cache_meta_dev_name"
echo "dmsetup create $cache_block_dev_name --table '0 $cache_data_size_blocks linear $cache_dev $meta_size_blocks'"

slow_dev_size_blocks=`blockdev --getsz $slow_dev`
echo "dmsetup create $cached_home_dev_name --table '0 $slow_dev_size_blocks cache /dev/mapper/$cache_meta_dev_name /dev/mapper/$cache_block_dev_name $slow_dev 512 1 writeback default 0'"

