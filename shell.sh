#!/bin/bash

# Set shell paths
sh="/bin/sh"
tcsh="/bin/tcsh"

# Iterate from 00 to 49
for i in $(seq -w 0 49)
do
    # Calculate password suffix (49 - current number)
    passSuffix=$(printf "%02d" $((49-i)))

    # Set username and password
    username="sa_${i}"
    password="sa_${passSuffix}"

    # Check if i is even or odd and set shell accordingly
    if [ $((10#$i%2)) -eq 0 ]
    then
        shell=${sh}
    else
        shell=${tcsh}
    fi

    # Create user with specified username, password, and shell
    
    sudo pw useradd "$username" -m -s "$shell" -h - # -h - 設置 home 目錄為空字串
    echo "$password" | pw mod user "$username" -h 0
done
