#!/bin/bash

path=`dirname $0`

xcodebuild -project "$path"/../../platform/mac/lua.xcodeproj -alltargets -configuration Release

cd $path/ios
./build.sh ../../build/facebook/ios/
cd -

#cd $path/mac
#./build.sh ../../build/facebook/mac/
#cd -

cd $path/android
./build.plugin.sh
cd -

# echo "Succeeded in building: iOS, Mac, Android"
# echo "You must build windows separately"
