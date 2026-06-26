#!/bin/bash
# Delete stale Flutter.framework so Flutter always copies a fresh xattr-free version
rm -rf /Users/bash/Desktop/ClubOS/build/ios/Debug-iphonesimulator/Flutter.framework
# Strip quarantine from engine source
xattr -dr com.apple.quarantine /opt/homebrew/share/flutter/bin/cache/artifacts/engine 2>/dev/null
flutter run -d "iPhone 17 Pro" "$@"
