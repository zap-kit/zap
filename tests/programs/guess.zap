# Deterministic "guessing game" driven by the seeded RNG and a scripted stdin.
mut rng = Random(71)
secret = rng.next(1..=100)
mut tries = 0
mut done = false
while not done:
	match stdin.line():
		line:
			tries += 1
			match i64.parse(line.trimmed()):
				g:
					if g < secret:
						print("higher")
					elif g > secret:
						print("lower")
					else:
						print("correct in {tries}")
						done = true
				none: print("not a number: {line}")
		none:
			print("gave up, secret was {secret}")
			done = true

test "the seeded guessing game reads its scripted guesses":
	stdin.feed("""
		50
		75
		62
		68
		65
		64
		63

		""")
	main()
	prints """
	    higher
	    lower
	    lower
	    lower
	    lower
	    lower
	    lower
	    gave up, secret was 60
	    """
