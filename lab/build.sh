#!/usr/bin/env bash
# Buduje 4 obrazy Docker labu P02. Uruchom w GNS3 VM (lub gdziekolwiek, gdzie dziala Docker).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
D="docker"
$D info >/dev/null 2>&1 || D="sudo docker"
for r in router client app-srv db-srv; do
    echo "=== budowa p02/${r} ==="
    $D build -f "lab/${r}/Dockerfile" -t "p02/${r}:latest" .
done
echo
$D images | grep -E "^REPOSITORY|^p02/"
