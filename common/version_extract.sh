#!/bin/bash

VERSION=$(jq -r .version package.json)
echo "VERSION=$VERSION" >> $GITHUB_ENV
echo "version: \"$VERSION\"" > version.yaml
ls -l