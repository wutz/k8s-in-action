#!/bin/bash

dir=$(dirname $0)
cd $dir

ENV=prod helmwave build --tags promtail --yml

