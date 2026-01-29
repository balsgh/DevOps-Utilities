#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
IMAGE_NAME=""
IMAGE_TAG="iac-tools-container"
IMAGE_VERSION="$(grep 'IMAGE_VERSION=' "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/Dockerfile" | tr -cd '0-9.')"

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"

# --- Build ---
docker build \
  --build-arg IMAGE_VERSION="${IMAGE_VERSION}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  "${SCRIPT_DIR}"

echo "✅ Docker image built: [${IMAGE_NAME}:${IMAGE_TAG}]"
