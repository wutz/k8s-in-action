#!/usr/bin/env bash

set -x 

TESTDIR=/share/test
ELBENCHO=/usr/local/bin/elbencho
RESFILE=fs.log
THREADS_LIST="1 4 16 64"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root
IODEPTH=16
TIMELIMIT=20

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
TOTAL=64

pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do

          SIZE=$(($TOTAL/$threads))g

          # Sequentially write and read $THREADS large files
          $ELBENCHO --hosts $host -w -n 0 -t $threads -s $SIZE -b 4m --direct --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -r -n 0 -t $threads -s $SIZE -b 4m --direct --resfile $RESFILE $TESTDIR

          # Random write and read IOPS for max $TIMELIMIT seconds:
          $ELBENCHO --hosts $host -w -n 0 -t $threads -s $SIZE -b 4k --direct --iodepth $IODEPTH --rand --timelimit $TIMELIMIT --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -r -n 0 -t $threads -s $SIZE -b 4k --direct --iodepth $IODEPTH --rand --timelimit $TIMELIMIT --resfile $RESFILE $TESTDIR
          $ELBENCHO --hosts $host -F -n 0 -t $threads $TESTDIR
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit