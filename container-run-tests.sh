#!/usr/bin/env bash

set -eu

container run -it \
  --rm \
  --mount src="$(pwd)",target=/flyingfox,type=bind \
  swift:6.2 \
  /usr/bin/swift test --package-path /flyingfox
