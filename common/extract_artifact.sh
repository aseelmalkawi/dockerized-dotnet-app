#!/bin/bash

mkdir -p app
ARTIFACT=$(ls cicd-aseel-${VERSION}-*.tgz | tail -n -1)
echo $ARTIFACT
tar -xzf  "$ARTIFACT" -C app