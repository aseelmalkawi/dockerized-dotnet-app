#!/bin/bash

ARTIFACT_NAME="cicd-aseel-${VERSION}-${GITHUB_SHA:0:7}.tgz"
# -p means to create if if it doesn't exist. Ensure the pipeline doesn't throw an error
mkdir -p artifacts
mkdir -p artifact-temp
# extends the bash shell to include more commands
shopt -s extglob
# copy everything to artifact-temp except what's in the brackets
cp -r !(artifact-temp|artifacts|.git|.github) artifact-temp/
# compresses what's in artifact-temp to artifact
tar -czf "artifacts/$ARTIFACT_NAME" -C artifact-temp .
rm -rf artifact-temp
ls -R artifacts