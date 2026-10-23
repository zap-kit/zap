# JSON round trip of a nested config struct, with defaults for missing optional fields.
type Window:
	width i64
	height i64
	title str
type Config:
	window Window
	volume f64
	tags str[]
	nickname str?
cfg = Config(
	window = Window(width = 800, height = 600, title = "Zap"),
	volume = 0.5,
	tags = ["a", "b"],
	nickname = none
)
text = cfg.toJson()
print(text)
match Config.fromJson(text):
	back: print("{back.window.title} {back.window.width}x{back.window.height} vol={back.volume} tags={back.tags.len} nick={back.nickname ?? "-"}")
	none: print("bad json")
print(Config.fromJson("\{\"window\": 1}") == none)
partial = "\{\"window\":\{\"width\":1,\"height\":2,\"title\":\"t\"},\"volume\":1,\"tags\":[],\"nickname\":\"zed\"}"
match Config.fromJson(partial):
	c: print(c.nickname ?? "-")
	none: print("bad json 2")

test "a nested config round-trips through JSON, a missing optional field taking its default":
	main()
	prints r"""
	    {"window":{"width":800,"height":600,"title":"Zap"},"volume":0.5,"tags":["a","b"],"nickname":null}
	    Zap 800x600 vol=0.5 tags=2 nick=-
	    true
	    zed
	    """
