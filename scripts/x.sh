#!/usr/bin/env bash

# Navigate to the directory containing the repositories
cd nimble_develop

# Loop through each folder
for repo in */; do
    # Navigate into the repository
    cd "$repo"
    
    # Check if it's a Git repository
    if [ -d .git ]; then
        echo "Repository: $repo"
        git rev-parse HEAD
        git fetch
        echo
    else
        echo "$repo is not a Git repository"
    fi
    
    # Return to the parent directory
    cd ..
done
