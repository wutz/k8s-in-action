#!/bin/bash

dir=$(dirname $0)
cd $dir

ENV=prod helmwave up --tags promtail

