# Solo playtest checklist

> For playing the playtest build on your own when there are no testers (D127; Kyle, 2026-10-28: "I dont really have testers
> atm"). About 40 minutes: 30 playing, 10 answering. The full kit ([`script.md`](script.md), [`feedback-form.md`](feedback-form.md),
> [`write-up-template.md`](write-up-template.md)) stays for when testers come along.

**What a solo run can and can't tell you.** You built the game, so you already know why the catch-kick works: you can't be
the blind tester of test 1 (`10` §2, "4 of 5 testers can explain why") or test 4. What a solo run *can* find is everything
that's broken, confusing, too fast, unfair or dull, and whether you want another fight. Those are most of the reasons a
playtest says "adjust".

## 1. Before you start

- [ ] On GitHub, open **Actions → Playtest build**, click the newest green run on `main`, and download
      `ChinCheck-windows-<commit>` under **Artifacts** ([`README.md`](README.md) §1). Note the commit.
- [ ] Unzip it and double-click `ChinCheck.exe` (if Windows warns: **More info → Run anyway**).
- [ ] Open a notes file next to the game. Jot one line every time you think "huh?", "too fast", "why did that happen?" or "nice".
- [ ] On the setup screen: type your name, pick **Playtest 1**, leave Difficulty on Normal, set **Speed** to 2×, press Start.

## 2. The fights, in order

**Fight 1: Playtest 1, your first calls** (Wrestler vs Boxer, 2×)
- [ ] Calls take a moment to reach him (the ring over the fighter), and he sometimes says "nah". Could you tell why?
- [ ] Calling a lot runs your voice out.
- [ ] On top, **1** is **Ground and pound!**, and the health bars drop.
- [ ] Shooting on the Boxer can get your head caught in a **guillotine** (rare). If it happens, the danger meter shows and
      **6** is **Defend the sub!** Did the meter make sense?
- [ ] How did it end (decision, knockout, the referee, the towel), and did you see it coming? This fight often ends early.

**Fight 2: Playtest 2, catch the kick** (Wrestler vs Kicker), played twice: at 2×, then on the result screen **Change setup**,
switch **Speed** to 1×, pick Playtest 2 again
- [ ] You spot the glow on the Kicker's leg before the kick, and **Q** (Catch the kick!) catches it. How does the first
      perfect catch feel?
- [ ] When Q did nothing, could you tell why? (The feed says when a read call misses or runs out before the kick comes.)
- [ ] From the bottom of full guard the Kicker goes for a **triangle** or an **armbar**. When one locks, **6 Defend the sub!**
      pushes the danger meter down. Did it seem to do anything?
- [ ] If your Wrestler locks a guillotine (rare), **1** is **Finish it!**
- [ ] Which speed felt better, and was anything too fast to react to or slow and boring? Did slow motion (**Space**) help?

**Fight 3: Playtest 3, a drilled rule** (Wrestler vs Kicker, whichever speed you liked; the result screen's **Next** button)
- [ ] You notice the drilled rule fire on its own (the panel on the left flashes).
- [ ] You still want to make calls, or you just watch.
- [ ] On your back you use **7 Get up!** or **8 Survive!**

**Then**, if you feel like another fight, play one (**Fight again**, or any Playtest fight). Note which and why: that's test 5.

## 3. Ten questions (10 minutes)

A line each is plenty. The tag is what it answers (`10` §2, the decisions), so the write-up can use it.

1. The catch-kick takedown felt: **1 2 3 4 5** (1 = nothing special). What made it feel that way? *(Feel)*
2. When a takedown or a catch failed, could you tell why from the screen and the feed (sprawl, knee, guillotine, too far)? *(Test 4, Timing, Fairness)*
3. Could you read at a glance: the range · who's on top or on the fence · what each fighter is doing · when to call · how hurt
   each is? Which was hard? *(Readability)*
4. Without your calls, did the Wrestler still fight sensibly? *(Autonomy)*
5. Did the Kicker or the Boxer ever feel cheap or lucky? *(Fairness)*
6. 2× or 1× from now on? *(D91)*
7. Fights ending early: saw them coming? Too often · about right · too rarely? *(D120)*
8. Ground and pound and the submissions: did the danger meter make sense, and did **Ground and pound!**, **Defend the sub!**
   or **Finish it!** seem to change anything? *(D121, D126)*
9. Do you want another fight right now? *(Fun, test 5)*
10. The best moment, the most confusing moment, and one thing you'd change.

## 4. Sending it back

- [ ] On the result screen press **Open saved fights** (or open `%APPDATA%\Godot\app_userdata\Chin Check\fights`) and take
      every `.json` file. Each one is a single fight: settings, how it ended, your calls, catches and takedowns, and its replay.
- [ ] Drop the files, your notes and your ten answers into the project chat.

Claude then writes it up as `docs/playtests/YYYY-MM-DD-solo.md` (the shape is §5), opens an issue for each problem, and adds
the decision row to `00` §0. The counts come straight from the saved files, so nobody needs Godot for them; the report's
replay check (`tools/playtest_report.gd`, *Reproducibility*) is skipped, since the replay tests already cover it on every PR.

## 5. The solo write-up

**Build:** `ChinCheck-windows-<commit>`  **Played:** YYYY-MM-DD, __ fights

| Question | Answer | Where from |
|---|---|---|
| Does the catch feel right? (Feel) | 1–5 and why | Q1 |
| Does the game teach the catch on its own? (Learnability, test 2) | Well-timed takedowns a fight in Playtest 3; fights with 2+ | Saved fights (`takedowns_by_call` + `takedowns_by_rule`) |
| Do misses and failures explain themselves? (Timing, test 4, Fairness) | Catches from Catch the kick! calls; could you tell why | Saved fights (`perfect_calls`, `calls_by_id`); Q2, Q5 |
| Can you read the fight? (Readability) | What was hard | Q3, notes |
| Do the fighters fight on their own? (Autonomy) | | Q4 |
| Speed (D91) | 2× or 1×, and the catches at each | Q6; saved fights by `normal_rate` |
| Finishes, ground and pound, submissions (D120, D121, D126) | How each fight ended; did the calls do anything | Saved fights (`result`); Q7, Q8 |
| Fun (test 5) | Wanted another? Played one? | Q9, notes |
| Not answered by a solo run | Test 1 and test 4 with blind testers | Run the full kit when there are testers |

**Problems found:** one row each (what happened, the fix, the issue).

**The decision** (a solo run picks one of two; a **go** needs testers):
- **Carry on**: nothing big is broken or confusing. Keep building; play the full kit with testers when there are some.
- **Adjust**: name each fix and its issue, fix them, then play this checklist again.

Your speed pick (Q6) sets normal speed until testers say otherwise (it confirms or changes D9's 2×, D91).
