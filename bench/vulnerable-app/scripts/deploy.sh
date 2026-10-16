#!/bin/bash
# Usage: deploy.sh <build_dir> <branch>
BUILD_DIR=$1
BRANCH=$2

echo "Deploying $BUILD_DIR"
rm -rf $DEPLOY_TARGET/*
cp -r $BUILD_DIR/* $DEPLOY_TARGET/
eval "echo Deployed branch $BRANCH at $(date)"
