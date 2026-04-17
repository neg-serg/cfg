#!/usr/bin/env bash

set -euo pipefail

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
	epp_path="${policy}/energy_performance_preference"
	if [[ -w "${epp_path}" ]]; then
		echo balance_performance >"${epp_path}"
	fi
done
