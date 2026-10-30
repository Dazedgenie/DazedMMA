class_name BalanceStats
extends RefCounted
## How sure a balance number is (D250, docs/01 §2.4): 95% ranges for a win
## share and for the change between two sets of fights. A harness number on its
## own hides how much of it is luck: near 50%, 100 fights only pin a win share to
## about ±10 points, 300 fights to about ±6 and 1,000 to about ±3.
##
## Two kinds of range:
## - wilson(): one share, e.g. "the Kicker wins 55% (45–64%)". The Wilson score
##   range stays inside 0–100% and behaves at small counts, unlike ±1.96·√(p(1−p)/n).
## - paired(): the mean change between fights matched by seed, e.g. the same 100
##   seeds with and without a coach. Each seed is one difference, so luck that hits
##   both fights alike cancels out and the range is much tighter than comparing
##   two separate win shares (unpaired()).

## 95% two-sided.
const Z: float = 1.96


## The 95% Wilson score range for `hits` out of `n`: Vector2(low, high), both 0–1.
## No fights gives the whole 0–1.
static func wilson(hits: float, n: int, z: float = Z) -> Vector2:
	if n <= 0:
		return Vector2(0.0, 1.0)
	var p: float = clampf(hits / n, 0.0, 1.0)
	var z2: float = z * z
	var denom: float = 1.0 + z2 / n
	var centre: float = (p + z2 / (2.0 * n)) / denom
	var half: float = z * sqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n)) / denom
	return Vector2(maxf(0.0, centre - half), minf(1.0, centre + half))


## The mean of per-seed differences (after − before, one per matched seed) with its
## 95% range: { mean, low, high, n }. Under two differences there's no spread to
## measure, so the range is unknown (low and high are -INF and INF).
static func paired(diffs: Array) -> Dictionary:
	var n: int = diffs.size()
	var m: float = mean(diffs)
	if n < 2:
		return { "mean": m, "low": -INF, "high": INF, "n": n }
	var half: float = Z * sqrt(variance(diffs) / n)
	return { "mean": m, "low": m - half, "high": m + half, "n": n }


## The change in mean from `before` to `after` when the fights aren't matched
## (different seeds or a different number of them): { mean, low, high, n } with n
## the smaller side. Wider than paired() on the same fights.
static func unpaired(before: Array, after: Array) -> Dictionary:
	var m: float = mean(after) - mean(before)
	var n: int = mini(before.size(), after.size())
	if before.size() < 2 or after.size() < 2:
		return { "mean": m, "low": -INF, "high": INF, "n": n }
	var half: float = Z * sqrt(variance(before) / before.size() + variance(after) / after.size())
	return { "mean": m, "low": m - half, "high": m + half, "n": n }


static func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / values.size()


## The sample variance (divides by n − 1); 0 under two values.
static func variance(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var m: float = mean(values)
	var total: float = 0.0
	for v: float in values:
		total += (v - m) * (v - m)
	return total / (values.size() - 1)


## True when the range has no spread to show (fewer than two fights to compare).
static func unknown(range_of: Dictionary) -> bool:
	return is_inf(range_of.low) or is_inf(range_of.high)


## A share and its range as text: "55.0% (45.3–64.4%)".
static func share_text(share: float, range_of: Vector2) -> String:
	return "%.1f%% (%.1f–%.1f%%)" % [share * 100.0, range_of.x * 100.0, range_of.y * 100.0]


## A change in points and its range as text: "+12.0% (+4.1 to +19.9)", or "+12.0% (range unknown)".
static func change_text(change: Dictionary) -> String:
	if unknown(change):
		return "%+.1f%% (range unknown)" % (change.mean * 100.0)
	return "%+.1f%% (%+.1f to %+.1f)" % [change.mean * 100.0, change.low * 100.0, change.high * 100.0]
