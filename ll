#!/bin/bash
# Runs flutterw while filtering out useless logs
# "Less Logs" => ll
./flutterw "$@" | grep -v -E "openmls|Mbgl-HttpRequest|SimpleDecode|SseCodec|ImageReader|E/Mbgl"
