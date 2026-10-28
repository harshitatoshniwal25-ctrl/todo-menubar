# Fonts

Caveat and Shantell Sans are OFL, and the design system says to embed them here
rather than fetching them at runtime. They are not committed — run:

    ./Scripts/fetch-fonts.sh

Anything with a .ttf/.otf extension in this folder is registered at launch.
Without them the app falls back to Bradley Hand, per `type.families`.
