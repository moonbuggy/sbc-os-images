## the root account doesn't have coloured prompts because it doesn't source
## .bashrc. Adding this .profile fixes that.

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
