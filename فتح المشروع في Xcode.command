#!/bin/zsh
cd -- "${0:A:h}"
open -a Xcode "$PWD/ios/Runner.xcworkspace"
