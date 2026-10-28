# Playtest script (host)

> Follows the onboarding order (`07` §1 steps 4–9, `07` §3) so every tester learns the calls in the same order: three call keys,
> then the read call against the Kicker, then a drilled rule with the full call bar. Decisions: D91, D118.
> About 30–40 minutes a tester. Have [`feedback-form.md`](feedback-form.md) ready and a notes sheet for each tester.
> No testers? Play [`solo-checklist.md`](solo-checklist.md) yourself instead (D127).

## 0. Before the session

- [ ] The newest Windows build from **Actions → Playtest build** on `main` ([`README.md`](README.md) §1), unzipped, opens to
      the setup screen.
- [ ] Give each tester a number in the order they play (T1, T2, …). **Odd** numbers play fight 2 at **2× first**, then 1×;
      **even** numbers play it at **1× first**, then 2×. That way the second go isn't always at the same speed (D91).
- [ ] Remote testers (Discord): they share their screen and talk; you take notes. They send their saved fights at the end.
- [ ] Note the build's commit (the zip's name) on the notes sheet.

## 1. What to say at the start (read it out, about a minute)

> "This is a very early test of a fighting coach game. You don't control the fighter: he fights on his own, and you're in
> his corner shouting advice. He might listen, he might not, and it takes a moment to reach him. There are four short fights,
> each with a tip at the start. Please think out loud the whole time: what you're looking at, what you're trying to do, what
> confuses you. If something doesn't make sense, that's the game's fault, not yours. I'll mostly stay quiet so I can see what
> the game teaches on its own."

**Don't** explain the calls, the tells, or how the catch-kick works beyond what the tips say. Test 1 (`10` §2) is that testers
can explain *why* it worked; that only counts if the game taught it. If a tester is stuck for more than a minute, you may point
at the tip again or say "try slow motion (Space)". Write down every time you help.

## 2. Setup screen

Ask the tester to type their name (or their T-number) in **Your name**, then pick **Playtest 1** in the **Playtest** list.
Leave **Difficulty** on Normal and the other toggles as they are. Set **Speed** to 2× (fight 1 is always 2×).

## 3. The fights

| # | Playtest step | Speed | What it teaches (`07` §1) | Watch for |
|---|---|---|---|---|
| 1 | **Playtest 1: your first calls** (Wrestler vs Boxer; Pressure, Circle out, Takedown, and Ground and pound! on top, which shares key 1; Finish it! (1) and Defend the sub! (6) in a submission hold, D126) | 2× | Watching the fight, speed controls, three call keys, the voice meter | Do they find the call bar and hotkeys? Do they notice calls take a moment (the ring over the fighter) and can be ignored ("nah")? Do they run out of voice? Once on top, do they press 1 for Ground and pound!, and do they watch the health bars drop? If the Boxer guillotines a shot (rare), do they find Defend the sub! (6)? This fight often ends early (see [`write-up-template.md`](write-up-template.md) §2b): note whether a stoppage surprises them |
| 2a | **Playtest 2: catch the kick** (Wrestler vs Kicker; adds Catch the kick! on Q; tell cue on) | Odd: 2×. Even: 1× | The read call, the tell cue, the perfect-call flourish | Do they spot the glow before the kick? Do they press Q early (a read waits for the kick) or late? Their face and words at the first perfect catch: that's the moment the game is built around. When the Kicker locks a triangle or armbar from his back, do they read the danger meter and press 6 (Defend the sub!)? |
| 2b | **Playtest 2 again** at the other speed: on the result screen press **Change setup**, switch **Speed**, pick Playtest 2, Start | Odd: 1×. Even: 2× | Same fight, other speed (D91) | Do they time the catch better or worse? Do they say which speed felt better without being asked? |
| 3 | **Playtest 3: a drilled rule** (Wrestler vs Kicker; rule Catch & shoot at 80%; all calls) | Ask: "Which speed do you want?" and note the answer | Drilled rules firing on their own, the plan panel, the full call bar, the ground calls (Get up, Survive) | Do they notice the rule fire without them? Do they still make calls or just watch? Do they use Get up / Survive on the ground? |

After 2a, use **Change setup** for 2b as above. After 2b, the result screen's **Next: Playtest 3** button starts fight 3 at
the speed fight 2b was played; if the tester wants the other speed, use **Change setup** instead and pick Playtest 3.

Between rounds the game stops at the bell and shows the round summary with the rule slots. Let the tester read it and press
on; don't explain it.

If a fight ends early (a knockout, or the tester throws the towel), go on to the next one. A tester may play a fight again
if they ask ("Fight again"); note it, it counts towards test 5 (wanting another fight).

### What to write down during each fight

- Every time they **say why** a takedown worked or failed, in their words (tests 1 and 4).
- Every time they **name** range, position, what a fighter is doing, or an opening ("he's on the fence", "he's going to kick")
  (Readability).
- How each fight ended (decision, knockout, the referee stopping it, the towel) and whether the tester saw it coming
  (health and the referee, D120).
- Moments of confusion, and anything they try that the game doesn't do.
- Every time you helped.

## 4. After the fights (5 minutes, before the form)

Ask these out loud and write the answers word for word; they're the core of tests 1 and 4, so don't lead:

1. "In fight 2 or 3, a takedown off a kick worked. Why did it work?"
2. "Did a takedown ever fail? Why do you think it failed?"
3. "Do you want to play another fight?" (If yes, let them; note which one they picked.)

Then hand over the [feedback form](feedback-form.md).

## 5. Collecting the saved fights

On the result screen press **Open saved fights** (or open `%APPDATA%\Godot\app_userdata\Chin Check\fights`). Take every
`.json` file in it. Put all testers' files in one folder for the report ([`README.md`](README.md) §3). The files keep the
tester's name, the speed and step, and the fight's full replay.

## 6. After the session

Run the report, fill in [`write-up-template.md`](write-up-template.md), and decide go / adjust / rethink.
