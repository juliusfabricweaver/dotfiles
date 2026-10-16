#!/bin/zsh
export PATH="$HOME/.spicetify:$PATH"
spicetify upgrade -n
spicetify backup apply -n
