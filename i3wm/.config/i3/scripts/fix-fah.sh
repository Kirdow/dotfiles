#!/bin/bash

# i3-msg workspace 3
# i3-msg exec "zen-browser https://v8-4.foldingathome.org/"

echo Fixing FAH-Client
sleep 8 && sudo systemctl restart fah-client # Returns Always Allow on sudoers.d/kirdow
echo FAH-Client should be fixed now
sleep 1 # sleep to give room for any needed propagation
