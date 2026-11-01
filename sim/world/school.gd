class_name School
extends RefCounted
## School weeks (docs/03 §11.4, D314): until he's LEAVES_AT, a week in term time isn't all his to train. School takes
## the MORNINGS (Monday to Friday) and homework two EVENINGS (Tuesday and Thursday; Kyle, 2026-11-01: "Mornings and two
## evenings"), so he trains three weekday evenings and Saturday: 5 of the week's 12 sessions. In the
## summer holidays (a week whose Monday is in HOLIDAY_MONTHS) every slot is his again, which is when a big camp pays.
##
## The career hands the coming week's school slots to his TrainingCamp (`taken`, set as each week begins), so the
## planner, the hub's weeks and a fight camp all lose the same slots. Pure: it reads only the career's calendar and age.

## The sessions school's slots run (data/sessions/school.json and homework.json: no XP, no fatigue, never planned).
const SESSION := "school"
const HOMEWORK := "homework"
## He leaves school on this birthday (a simplification: no exams or sixth-form years).
const LEAVES_AT: int = 18
## The summer holidays: a week whose Monday falls in one of these months has no school.
const HOLIDAY_MONTHS: Array[int] = [7, 8]
## The slots school takes in a school week, counted from 0 (Monday morning), two a day: Monday to Friday mornings …
const MORNINGS: Array[int] = [0, 2, 4, 6, 8]
## … and the evenings homework takes: Tuesday and Thursday.
const EVENINGS: Array[int] = [3, 7]


## Whether he's still at school in week `of_week` (this week when left out): younger than LEAVES_AT then.
static func at_school(c: Career, of_week: int = -1) -> bool:
	var w: int = c.week if of_week < 0 else of_week
	var years: float = c.trainee.age_years + float(w - c.week) / Ageing.WEEKS_PER_YEAR
	return int(years + 0.0001) < LEAVES_AT


## Whether week `of_week`'s Monday is in the summer holidays.
static func on_holiday(c: Career, of_week: int = -1) -> bool:
	return int(c.date(0, of_week).month) in HOLIDAY_MONTHS


## A school week: at school and not on holiday.
static func school_week(c: Career, of_week: int = -1) -> bool:
	return at_school(c, of_week) and not on_holiday(c, of_week)


## The slots school takes this week: slot index → SESSION or HOMEWORK, in slot order ({} in the holidays or once he's left).
static func taken(c: Career) -> Dictionary:
	var out: Dictionary = {}
	if school_week(c):
		for i in TrainingCamp.DAYS * TrainingCamp.SLOTS_PER_DAY:
			if i in MORNINGS:
				out[i] = SESSION
			elif i in EVENINGS:
				out[i] = HOMEWORK
	return out


## Every slot a school week takes.
static func slots() -> Array[int]:
	var out: Array[int] = []
	out.append_array(MORNINGS)
	out.append_array(EVENINGS)
	out.sort()
	return out


## The sessions left to train in a school week (5 of 12).
static func sessions_left() -> int:
	return TrainingCamp.DAYS * TrainingCamp.SLOTS_PER_DAY - slots().size()


## The hub's line about this week's school: "" once he's left.
static func week_line(c: Career) -> String:
	if not at_school(c):
		return ""
	if on_holiday(c):
		return "Summer holidays: every session this week is his."
	return "School week: weekday mornings at school and homework on Tuesday and Thursday evenings, so he trains %d of the 12 sessions." % sessions_left()
