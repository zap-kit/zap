# A second file of the same module (a dir is a module).

pub greeting = "hello"

pub fn shout(s str) str:
	"{s.upper()}!"

suffix = "?"

pub type Banner:
	text str
	mark str = suffix + suffix

# the defaults name this module's constant: they mean it from any module that calls
pub fn ask(s str, end str = suffix) str:
	s + end

# a tag of this module; game.world declares a Tag of its own, laid out otherwise: the two (and
# lists of them) must be freed each by its own drop
pub type Tag:
	name str
	parts i64[]

pub fn tags() Tag[]:
	[Tag(name = "a".repeat(3), parts = [1, 2, 3]), Tag(name = "b".repeat(2), parts = [])]
