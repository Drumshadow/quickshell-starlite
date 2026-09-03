#!/usr/bin/env bash
# Install the tablet-side theming pieces (run ON the tablet from the repo).
set -e
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.config/wallust/templates ~/.config/wallust/colorschemes ~/.config/quickshell-starlite ~/.local/bin
cp "$D/wallust/wallust.toml" ~/.config/wallust/wallust.toml
cp "$D/wallust/templates/"* ~/.config/wallust/templates/
cp "$D/wallust/colorschemes/"* ~/.config/wallust/colorschemes/
install -m755 "$D/starlite-theme-post" "$D/starlite-theme-previews" ~/.local/bin/
echo "installed: wallust config, templates, ariadne colourscheme, starlite-theme-post, starlite-theme-previews"
