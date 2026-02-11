#!/bin/bash

VERSION=$(grep 'version' version.yaml | cut -d'"' -f2)
echo "VERSION=$VERSION" >> $GITHUB_ENV
