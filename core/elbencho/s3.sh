#!/usr/bin/env bash

S3SERVER=http://s3.example.com
S3KEY=xxx
S3SECRET=xxxxxx
S3BUCKET=benchmark
ELBENCHO=/usr/local/bin/elbencho
RESFILE=s3.log
DIRS=1
FILES=128
THREADS_LIST="1 4 16 64"
SIZE_LIST="4k 128k 4m 4g"
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
            if [[ "$size" == "$LAST_SIZE" ]]; then
                files=1
            else
                files=$FILES
            fi

            # Create bucket
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -d $S3BUCKET
            # Write
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -w -t $threads -n $DIRS -N $files -s $size -b $size --resfile $RESFILE $S3BUCKET
            # Read
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -r -t $threads -n $DIRS -N $files -s $size -b $size --resfile $RESFILE $S3BUCKET
            # Delete
            $ELBENCHO --hosts $host --s3endpoints $S3SERVER --s3key $S3KEY --s3secret $S3SECRET \
                    -D -F -t $threads -n $DIRS -N $files $S3BUCKET
        done
    done
done

$ELBENCHO --hosts $USER@$HOSTS --quit