#!/usr/bin/bash

# Adding it490.sh in bashrc with the current working directory
# This is so that the script can be run from anywhere
# Functions work but alias is different when working with sudo
add_alias() {
    # Check to see what is the default shell
    if [ -z "$SHELL" ]; then
        echo "Error: SHELL environment variable not set."
        exit 1
    fi
    # If using bash put in .bashrc if zsh put in .zshrc
    if [[ "$SHELL" == "/bin/bash" ]]; then
        echo "Adding alias to .bashrc ..."
        echo "it490() {" >> ~/.bashrc 
        echo "  $PWD/it490.sh "$@"" >> ~/.bashrc
        echo "}" >> ~/.bashrc
        source ~/.bashrc
        echo "Alias added."
    elif [[ "$SHELL" == "/bin/zsh" ]]; then
        echo "Adding alias to .zshrc ..."
        echo "it490() {" >> ~/.bashrc 
        echo "  $PWD/it490.sh "$@"" >> ~/.bashrc
        echo "}" >> ~/.bashrc
        source ~/.zshrc
        echo "Alias added."
    else
        echo "Error: Unsupported shell. I only care about two at the moment."
        exit 1
    fi
}

add_alias