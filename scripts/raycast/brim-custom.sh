#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Brim Timer
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Brim
# @raycast.argument1 { "type": "text", "placeholder": "minutes" }

open "brim://start?minutes=$1"