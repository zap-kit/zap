# The cartridge's structure, from the community

`bank*.cfg` and `symbols.toml` are DKC1Recomp's (github.com/elliotttate/DKC1Recomp, MIT, see
LICENSE-DKC1Recomp): per bank of the USA v1.0 cartridge, the data regions inside the code banks,
the function entries with their M and X flag states, the targets of each indirect-dispatch site,
and the names of the routines the community has identified. They were distilled by that project
from Yoshifanatic1's GPL-3 disassembly; no code or data of the game is in them. The recompiler
(`snes/`) reads them so the flow analysis starts from known entries instead of guessing.
