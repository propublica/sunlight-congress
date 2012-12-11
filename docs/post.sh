#!/bin/bash

mkdir -p output

curl -X POST --data-urlencode content@index.md --data-urlencode name="Congress API" --data-urlencode twitter=sunlightlabs "http://documentup.com/compiled" > output/index.html