#!/bin/bash

VERSION=$(grep '<Version>' MagicVilla_VillaAPI.csproj | sed -E 's/.*<Version>(.*)<\/Version>.*/\1/')
echo "VERSION=$VERSION" >> $GITHUB_ENV
echo "version: \"$VERSION\"" > version.yaml
ls -l