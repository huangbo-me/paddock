#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/tools .build/modules
xcrun swiftc -swift-version 5 -warnings-as-errors -parse-as-library \
  -module-cache-path .build/modules Sources/Core/Commerce.swift Tools/LicenseTool.swift \
  -o .build/tools/paddock-license
printf 'License issuer built at .build/tools/paddock-license\n'
