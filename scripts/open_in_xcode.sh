#!/usr/bin/env zsh
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d "DaystingIRC.xcodeproj" ]]; then
	open DaystingIRC.xcodeproj
else
	open Package.swift
fi
