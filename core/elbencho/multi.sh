#!/usr/bin/env bash

TESTDIR=/share/test
ELBENCHO=/usr/local/bin/elbencho
RESFILE=fs.log
DIRS=1
FILES=128
THREADS_LIST="1 4 16 64"
SIZE_LIST="4m 4k"
HOSTS_LIST="gn001 gn[001-004] gn[001-016]"
USER=root

FIRST_HOST=$(echo $HOSTS_LIST | awk '{print $1}')
LAST_HOST=$(echo $HOSTS_LIST | awk '{print $NF}')
LAST_THREAD=$(echo $THREADS_LIST | awk '{print $NF}')
LAST_SIZE=$(echo $SIZE_LIST | awk '{print $NF}')

pdsh -w $USER@$LAST_HOST $ELBENCHO --service

for host in $HOSTS_LIST; do
    if [ "$host" == "$FIRST_HOST" ]; then
        thread_list=$THREADS_LIST
    else
        thread_list=$LAST_THREAD
    fi

    for threads in $thread_list; do
        for size in $SIZE_LIST; do
            #如果是以g结尾就设定4m块大小
            if [[ $(rev <<< "$size" | head -c 1) == "g" ]]; then
                files=1
                block_size="4m"
            else
                files=$FILES
                block_size=$size
            fi

            # Write
            $ELBENCHO --hosts $host  \
                    -w -d --direct -t $threads -n $DIRS -N $files -s $size -b $block_size --resfile $RESFILE $TESTDIR
            # Read
            $ELBENCHO --hosts $host  \
                    -r --direct -t $threads -n $DIRS -N $files -s $size -b $block_size --resfile $RESFILE $TESTDIR
            # Delete
            $ELBENCHO --hosts $host  \
                    -D -F -t $threads -n $DIRS -N $files $TESTDIR
        done
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit