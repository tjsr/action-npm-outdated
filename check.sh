#!/bin/bash

if command -v npm &> /dev/null
then
    echo "npm found ok."
else
    echo "npm is not installed."
    exit 1
fi