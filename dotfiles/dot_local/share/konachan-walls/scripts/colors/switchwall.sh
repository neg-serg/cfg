#!/usr/bin/env bash
# Minimal switchwall.sh stub for konachan-walls module.
# Replaces end-4's full matugen/color-generation pipeline.
# Just sets the wallpaper via wl (ssww Vulkan fork).

imgpath=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) imgpath="$2"; shift 2 ;;
        --mode|--type|--color|--noswitch) shift 2 ;;
        *) imgpath="$1"; shift ;;
    esac
done

if [[ -n "$imgpath" && -f "$imgpath" ]]; then
    if command -v wl &>/dev/null; then
        wl img "$imgpath"
    elif command -v swww &>/dev/null; then
        swww img "$imgpath"
    else
        echo "konachan-walls: no wallpaper daemon found (wl or swww)" >&2
        exit 1
    fi
fi
