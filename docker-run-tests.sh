#!/usr/bin/env bash

set -eu

docker run -it \
  --rm \
  --mount src="$(pwd)",target=/flyingfox,type=bind \
  swift \
  /usr/bin/swift test --package-path /flyingfox
