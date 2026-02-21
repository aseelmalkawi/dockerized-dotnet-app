#!/bin/bash

VERSION=$(dotnet build -getProperty:Version)
echo "VERSION=$VERSION" >> $GITHUB_ENV
echo "version: \"$VERSION\"" > version.yaml
ls -l