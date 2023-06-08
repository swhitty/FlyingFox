#!/usr/bin/env bash

set -eu

docker run -it \
  --rm \
  --mount src="$(pwd)",target=/flyingfox,type=bind \
  swiftlang/swift:nightly-5.9-jammy \
  /usr/bin/swift test --package-path /flyingfox
