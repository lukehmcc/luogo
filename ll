#!/bin/bash
# Runs flutterw while filtering out useless logs
# "Less Logs" => ll
if [[ "$1" == "ll" ]]; then
  shift # Remove "ll" from arguments
  ./flutterw "$@" 2>&1 | grep -v -E "openmls|Mbgl-HttpRequest|SimpleDecode|SseCodec"
else
  ./flutterw "$@" | grep -v -E "openmls|Mbgl-HttpRequest|SimpleDecode|SseCodec|ImageReader"
fi
