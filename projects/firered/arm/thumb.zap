# long: the table of Thumb, a row an instruction form
# Thumb (ARMv4T): the 19 formats of the ARM7TDMI's manual in its order, each as the ARM
# instruction it is: a shift is a mov of a shifted register, neg a rsb from 0, push a stmdb. A row
# is its bits, `=`, its template (decode.zap); a bl is the pair of its halfwords.

thumbTable = r"""
000 00 iiiii mmm ddd = movs r<d>, r<m>, lsl #<i>
000 01 iiiii mmm ddd = movs r<d>, r<m>, lsr #<i:n32>
000 10 iiiii mmm ddd = movs r<d>, r<m>, asr #<i:n32>
00011 0 0 mmm nnn ddd = adds r<d>, r<n>, r<m>
00011 0 1 mmm nnn ddd = subs r<d>, r<n>, r<m>
00011 1 0 iii nnn ddd = adds r<d>, r<n>, #<i>
00011 1 1 iii nnn ddd = subs r<d>, r<n>, #<i>
001 00 ddd iiiiiiii = movs r<d>, #<i>
001 01 ddd iiiiiiii = cmp r<d>, #<i>
001 10 ddd iiiiiiii = adds r<d>, r<d>, #<i>
001 11 ddd iiiiiiii = subs r<d>, r<d>, #<i>
010000 0000 sss ddd = ands r<d>, r<d>, r<s>
010000 0001 sss ddd = eors r<d>, r<d>, r<s>
010000 0010 sss ddd = movs r<d>, r<d>, lsl r<s>
010000 0011 sss ddd = movs r<d>, r<d>, lsr r<s>
010000 0100 sss ddd = movs r<d>, r<d>, asr r<s>
010000 0101 sss ddd = adcs r<d>, r<d>, r<s>
010000 0110 sss ddd = sbcs r<d>, r<d>, r<s>
010000 0111 sss ddd = movs r<d>, r<d>, ror r<s>
010000 1000 sss ddd = tst r<d>, r<s>
010000 1001 sss ddd = rsbs r<d>, r<s>, #0
010000 1010 sss ddd = cmp r<d>, r<s>
010000 1011 sss ddd = cmn r<d>, r<s>
010000 1100 sss ddd = orrs r<d>, r<d>, r<s>
010000 1101 sss ddd = muls r<d>, r<s>, r<d>
010000 1110 sss ddd = bics r<d>, r<d>, r<s>
010000 1111 sss ddd = mvns r<d>, r<s>
010001 00 D m mmm DDD = add r<D>, r<D>, r<m>
010001 01 D m mmm DDD = cmp r<D>, r<m>
010001 10 D m mmm DDD = mov r<D>, r<m>
010001 11 0 m mmm --- = bx r<m>
01001 ddd iiiiiiii = ldr r<d>, [pc, #<i*4>]
0101 000 mmm nnn ddd = str r<d>, [r<n>, r<m>]
0101 001 mmm nnn ddd = strh r<d>, [r<n>, r<m>]
0101 010 mmm nnn ddd = strb r<d>, [r<n>, r<m>]
0101 011 mmm nnn ddd = ldrsb r<d>, [r<n>, r<m>]
0101 100 mmm nnn ddd = ldr r<d>, [r<n>, r<m>]
0101 101 mmm nnn ddd = ldrh r<d>, [r<n>, r<m>]
0101 110 mmm nnn ddd = ldrb r<d>, [r<n>, r<m>]
0101 111 mmm nnn ddd = ldrsh r<d>, [r<n>, r<m>]
011 00 iiiii nnn ddd = str r<d>, [r<n>, #<i*4>]
011 01 iiiii nnn ddd = ldr r<d>, [r<n>, #<i*4>]
011 10 iiiii nnn ddd = strb r<d>, [r<n>, #<i>]
011 11 iiiii nnn ddd = ldrb r<d>, [r<n>, #<i>]
1000 0 iiiii nnn ddd = strh r<d>, [r<n>, #<i*2>]
1000 1 iiiii nnn ddd = ldrh r<d>, [r<n>, #<i*2>]
1001 0 ddd iiiiiiii = str r<d>, [sp, #<i*4>]
1001 1 ddd iiiiiiii = ldr r<d>, [sp, #<i*4>]
1010 0 ddd iiiiiiii = add r<d>, pc, #<i*4>
1010 1 ddd iiiiiiii = add r<d>, sp, #<i*4>
10110000 0 iiiiiii = add sp, sp, #<i*4>
10110000 1 iiiiiii = sub sp, sp, #<i*4>
1011 0 10 R llllllll = stmdb sp!, {<Rl:list14>}
1011 1 10 R llllllll = ldmia sp!, {<Rl:list15>}
1100 0 nnn llllllll = stmia r<n>!, {<l:list>}
1100 1 nnn llllllll = ldmia r<n>!, {<l:list>}
1101 1111 iiiiiiii = swi #<i:hex>
1101 1110 -------- = undefined
1101 cccc iiiiiiii = b<c:cond> <i:target2>
11100 iiiiiiiiiii = b <i:target2>
11110 hhhhhhhhhhh 11111 lllllllllll = bl <hl:target2>
"""

pub fn thumbRows() Row[]:
	rowsOf(thumbTable)
