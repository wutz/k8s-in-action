#!/usr/bin/env bash

warp mixed \
        --host=s3.example.com \
        --access-key=xxx \
        --secret-key=xxxxxx \
        --bucket=benchmark \
        --concurrent 100 \
        --objects 100000 \
        --obj.size 1MiB \
        --get-distrib 50 \
        --stat-distrib 0 \
        --put-distrib 50 \
        --delete-distrib 0 \
        --duration 1m 

        # --tls \
        # --duration 10m