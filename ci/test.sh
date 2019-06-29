#!/bin/bash

echo "Download und extract sourcemod"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

for file in addons/sourcemod/scripting/forum*.sp
do
  echo "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 $file
done
