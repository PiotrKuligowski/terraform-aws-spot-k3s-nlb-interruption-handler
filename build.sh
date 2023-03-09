#!/usr/bin/env bash

cd "$(dirname "$0")"
mkdir -p package
pip3 install -r requirements.txt -t package/ --upgrade
cp *.py package/