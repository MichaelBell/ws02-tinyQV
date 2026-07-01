#!/bin/bash
gcc intel_one_mono.c make_tile.c -o font
./font > font_case.v
