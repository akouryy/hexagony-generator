# Language HexRich
The high-level language you write
## specs
```
REGisters: a..n
ARRays: o..z
IMMediate: -?\d+
FACtor: REG | IMM
MNEmonics:
  REG = geti
  REG = getb
  puti FAC
  putb FAC
  REG = FAC
  REG += FAC
  REG -= FAC
  REG *= FAC
  REG /= FAC
  REG %= FAC
  REG = -REG
  REG = REG + FAC
  REG = REG - FAC
  REG = REG * FAC
  REG = REG / FAC
  REG = REG % FAC
  REG = ARR[FAC]
  ARR[FAC] = REG
  jump label
  jump label_pos label_zeroneg (REG > 0)
program: (label | MNE \n)*
```
## Memory location
![Memory location](https://raw.github.com/akouryy/hexagony-generator/master/specs/hexrich_memory_location.svg?sanitize=true)
