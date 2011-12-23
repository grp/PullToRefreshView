# this will fail with _main undefined, but should work otherwise
/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/clang++ -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk PullToRefreshView.m -arch armv7 -framework Foundation -framework UIKit -miphoneos-version-min=4.0 -framework QuartzCore

