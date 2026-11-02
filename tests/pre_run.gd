extends GutHookScript
## Before the tests (D358): new careers in tests start without the world's 10 years of history (Career.history_years),
## which would take seconds a career; the history's own tests turn a little of it back on.


func run() -> void:
	Career.history_years = 0
