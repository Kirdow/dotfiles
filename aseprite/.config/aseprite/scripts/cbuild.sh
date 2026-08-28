#!/usr/bin/env bash

# Build script for Test/Demo file tex_reshade.c which helped develop aseprite script tex_reshade.lua

set -e

gcc -lm -std=gnu11 -o /tmp/tex_reshade ./tex_reshade.c
chmod +x /tmp/tex_reshade
/tmp/tex_reshade