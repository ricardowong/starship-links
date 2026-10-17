#!/usr/bin/env zsh
# Renders your current prompt once per palette in starship.toml.
# Run it from a shell that loaded shell/init.zsh, inside a git repo, so the link
# hook has set its env vars: zsh tools/preview-themes.zsh
src=${STARSHIP_CONFIG:-${0:A:h:h}/starship.toml}
tmp=${TMPDIR:-/tmp}/starship-links-preview.toml
for name in ${(f)"$(grep -o '^\[palettes\.[a-z_]*\]' $src | sed 's/\[palettes\.\(.*\)\]/\1/')"}; do
    sed "s/^palette = '.*'/palette = '$name'/" $src >| $tmp
    print "\n  $name"
    print -r -- "  $(STARSHIP_CONFIG=$tmp STARSHIP_SHELL= starship prompt)"
done
rm -f $tmp
print
