# language HexRich
# registers: a..n
# arrays: o..z
# immediate: -?\d+
# factor: reg | imm
# mnemonics:
#   REG = geti
#   REG = getb
#   puti FACT
#   putb FACT
#   REG = FACT
#   REG += FACT
#   REG -= FACT
#   REG *= FACT
#   REG /= FACT
#   REG %= FACT
#   REG = -REG
#   REG = REG + FACT
#   REG = REG - FACT
#   REG = REG * FACT
#   REG = REG / FACT
#   REG = REG % FACT
#   REG = ARR[FACT]
#   ARR[FACT] = REG
#   jump label
#   jump label_pos label_zeroneg (REG > 0)
