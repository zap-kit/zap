# long: the table of the 65816, a row an opcode
# The 65816's 256 opcodes, a row each: the opcode, its mnemonic and its addressing mode written as
# its operand reads (decode.zap).

opcodeTable = r"""
00 brk #8
01 ora (d,x)
02 cop #8
03 ora d,s
04 tsb d
05 ora d
06 asl d
07 ora [d]
08 php
09 ora #m
0A asl A
0B phd
0C tsb w
0D ora w
0E asl w
0F ora l
10 bpl r
11 ora (d),y
12 ora (d)
13 ora (d,s),y
14 trb d
15 ora d,x
16 asl d,x
17 ora [d],y
18 clc
19 ora w,y
1A inc A
1B tcs
1C trb w
1D ora w,x
1E asl w,x
1F ora l,x
20 jsr w
21 and (d,x)
22 jsl l
23 and d,s
24 bit d
25 and d
26 rol d
27 and [d]
28 plp
29 and #m
2A rol A
2B pld
2C bit w
2D and w
2E rol w
2F and l
30 bmi r
31 and (d),y
32 and (d)
33 and (d,s),y
34 bit d,x
35 and d,x
36 rol d,x
37 and [d],y
38 sec
39 and w,y
3A dec A
3B tsc
3C bit w,x
3D and w,x
3E rol w,x
3F and l,x
40 rti
41 eor (d,x)
42 wdm #8
43 eor d,s
44 mvp b,b
45 eor d
46 lsr d
47 eor [d]
48 pha
49 eor #m
4A lsr A
4B phk
4C jmp w
4D eor w
4E lsr w
4F eor l
50 bvc r
51 eor (d),y
52 eor (d)
53 eor (d,s),y
54 mvn b,b
55 eor d,x
56 lsr d,x
57 eor [d],y
58 cli
59 eor w,y
5A phy
5B tcd
5C jml l
5D eor w,x
5E lsr w,x
5F eor l,x
60 rts
61 adc (d,x)
62 per rl
63 adc d,s
64 stz d
65 adc d
66 ror d
67 adc [d]
68 pla
69 adc #m
6A ror A
6B rtl
6C jmp (w)
6D adc w
6E ror w
6F adc l
70 bvs r
71 adc (d),y
72 adc (d)
73 adc (d,s),y
74 stz d,x
75 adc d,x
76 ror d,x
77 adc [d],y
78 sei
79 adc w,y
7A ply
7B tdc
7C jmp (w,x)
7D adc w,x
7E ror w,x
7F adc l,x
80 bra r
81 sta (d,x)
82 brl rl
83 sta d,s
84 sty d
85 sta d
86 stx d
87 sta [d]
88 dey
89 bit #m
8A txa
8B phb
8C sty w
8D sta w
8E stx w
8F sta l
90 bcc r
91 sta (d),y
92 sta (d)
93 sta (d,s),y
94 sty d,x
95 sta d,x
96 stx d,y
97 sta [d],y
98 tya
99 sta w,y
9A txs
9B txy
9C stz w
9D sta w,x
9E stz w,x
9F sta l,x
A0 ldy #x
A1 lda (d,x)
A2 ldx #x
A3 lda d,s
A4 ldy d
A5 lda d
A6 ldx d
A7 lda [d]
A8 tay
A9 lda #m
AA tax
AB plb
AC ldy w
AD lda w
AE ldx w
AF lda l
B0 bcs r
B1 lda (d),y
B2 lda (d)
B3 lda (d,s),y
B4 ldy d,x
B5 lda d,x
B6 ldx d,y
B7 lda [d],y
B8 clv
B9 lda w,y
BA tsx
BB tyx
BC ldy w,x
BD lda w,x
BE ldx w,y
BF lda l,x
C0 cpy #x
C1 cmp (d,x)
C2 rep #8
C3 cmp d,s
C4 cpy d
C5 cmp d
C6 dec d
C7 cmp [d]
C8 iny
C9 cmp #m
CA dex
CB wai
CC cpy w
CD cmp w
CE dec w
CF cmp l
D0 bne r
D1 cmp (d),y
D2 cmp (d)
D3 cmp (d,s),y
D4 pei (d)
D5 cmp d,x
D6 dec d,x
D7 cmp [d],y
D8 cld
D9 cmp w,y
DA phx
DB stp
DC jml [w]
DD cmp w,x
DE dec w,x
DF cmp l,x
E0 cpx #x
E1 sbc (d,x)
E2 sep #8
E3 sbc d,s
E4 cpx d
E5 sbc d
E6 inc d
E7 sbc [d]
E8 inx
E9 sbc #m
EA nop
EB xba
EC cpx w
ED sbc w
EE inc w
EF sbc l
F0 beq r
F1 sbc (d),y
F2 sbc (d)
F3 sbc (d,s),y
F4 pea w
F5 sbc d,x
F6 inc d,x
F7 sbc [d],y
F8 sed
F9 sbc w,y
FA plx
FB xce
FC jsr (w,x)
FD sbc w,x
FE inc w,x
FF sbc l,x
"""

pub fn opcodeRows() Row[]:
	rowsOf(opcodeTable)
