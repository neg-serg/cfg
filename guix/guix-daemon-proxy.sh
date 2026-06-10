#!/bin/bash
export http_proxy=http://127.0.0.1:10880
export https_proxy=http://127.0.0.1:10880
exec /var/guix/profiles/per-user/root/current-guix/bin/guix-daemon "$@"
