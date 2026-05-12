# Bugs Have Wavelengths

*A small frame for thinking about which review you should be running next.*

---

## A familiar feeling

You're in review round four. Round one caught twelve issues. Round two caught seven. Round three caught five. This round caught three — but you had to read the diff twice to find any of them, and the last one took an hour. The reviewer is just as sharp as before. The code is in measurably better shape than when you started.

So why does it feel like you're not done?

You probably aren't, in some sense — but the question is harder than "are there more bugs?" The question is whether you can find any of the *remaining* bugs by doing more of what you've been doing. Most of the time the honest answer is no, and it takes a frame to see why.

Here is a frame I've found useful.

## A simple observation

Bugs aren't all equal in how visible they are.

Some are local. A typo. An off-by-one. An unused import. A missing `await`. You spot them on the first read because the bug and the evidence of the bug live in the same line, or two adjacent lines.

Others require holding seven things in your head at once: a cache invariant, a state-machine transition, a piece of platform behaviour, a constraint imposed in a file you haven't opened. You can stare at the offending lines for an hour and miss the bug entirely, because the offending lines are individually fine. The bug is in the *space between* them.

Borrow a word from physics for this. Call it the **wavelength** of the bug — roughly, the length of the inferential chain you have to follow before the bug becomes obvious. Short wavelength: the evidence is right there in the line. Long wavelength: the evidence is distributed across files, sessions, machines, time zones.

Wavelength here isn't quite the physical quantity, but the intuition is close enough to do real work.

## Frequency follows

In physics, wavelength and frequency are inversely related: short wavelength means high frequency. The same holds for bugs.

Short-wavelength bugs are common. The codebase is full of opportunities to typo a variable, invert a condition, miss a null check. You catch a lot of them per pass because there are a lot of them, and each one is cheap to spot.

Long-wavelength bugs are rare per pass. You might find one every other round, if any. They're rare because the conditions they live in (a specific concurrency, a specific input, a specific platform) don't show up often during inspection. But they account for most of the production incidents, because that's the environment where their conditions finally arrive.

This is why "we keep finding fewer bugs but they're nastier" is a real pattern, not a feeling. As you iterate, the cheap-to-find bugs deplete first, leaving a remainder weighted toward the expensive ones.

## Detectors have bandwidth

Here's where the frame starts to earn its keep.

Every tool you use to find bugs has a sensitivity band — a range of wavelengths where it does well, and ranges outside which it can't reach reliably no matter how hard you push it. Briefly:

- **Linters and type checkers** sit at very short wavelength with very high sensitivity. A linter will tell you about every unused import in a million-line codebase. A linter will not tell you that your cache invalidation is wrong.
- **Code review (paper)** covers short to mid. A careful reviewer catches inverted conditions, misplaced awaits, contract drift between adjacent files, sometimes a missing edge case. Paper review struggles with anything requiring whole-system context, and it can't reach defects whose evidence only appears at runtime.
- **Smoke tests and one-shot execution** sit at mid wavelength. They catch platform assumptions, shell-quoting issues, JSON-shape mismatches, "the function this is calling doesn't actually exist" — the bugs paper review systematically misses because they only show themselves under execution. (You write `sha256sum` in a script that's intended to run on macOS. Paper review never sees this. The first execution does, immediately.)
- **Integration tests** cover mid to long. The bugs that emerge from how components compose, or from contracts between processes.
- **Production observability** covers long. The memory leak that shows after three days. The race that fires only at peak load. The bug that only happens for users in time zone X with a non-ASCII display name.

A linter and an observability platform are both bug detectors, but they're tuned to wildly different wavelengths. They'd catch almost no bugs in common. This isn't a deficiency of either tool. It's the shape of the problem.

## Iteration shifts the distribution

Now the consequence.

Each round of a single detector preferentially eliminates the bugs in its band first. So after enough rounds, what's left is biased *away* from that band. The defect count drops monotonically — but the wavelength of remaining defects rises.

Concretely: round four of a paper code review on a system whose remaining bugs have shifted into the "platform-knowledge-required" or "cache-invariant" range will produce fewer findings than round one, and each finding will be either harder to argue for or quietly dependent on something the reviewer happened to already know.

This is the diagnostic move: when defect count drops *and* the class of remaining defects starts to feel different (mechanical → structural → architectural → "we got lucky the reviewer happened to know macOS"), don't run another round of the same detector. **Swap detectors.**

The signal that you've crossed the band boundary is often a single bug: the next one your detector finds, it finds by happenstance — because the reviewer happened to know an external fact, or a particular eyeball-grep got lucky — rather than because the detector was *designed* to find that class. When detection becomes happenstance, the detector is out of band, and the next round of the same kind will mostly miss things rather than find them.

## Wavelength is observer-relative

This is the bit that makes the frame useful for arguments.

A bug's wavelength is not a property of the bug alone. It's a property of (bug × detector). The same `sha256sum doesn't exist on macOS` bug is short-wavelength for a macOS-aware reviewer (instant recognition: the command isn't there, ship it as `shasum -a 256`) and effectively infinite-wavelength for a Linux-only reviewer reading the prose (will never be found by paper review at all, no matter how careful the reading).

This kills a class of mistake: "this defect is hard" usually means "this defect is hard *for the detector we're using*." The corrective move isn't always "try harder." Sometimes it's "use a different detector."

## What the frame predicts

Three corollaries fall out cleanly enough to be worth flagging.

**Mature systems and new systems need different tool portfolios.** Years of bug fixes preferentially eliminate short-wavelength defects. So mature systems have wavelength distributions that have shifted toward the long end. They benefit *more* from observability and integration testing than from linting and typing — relative to where they would have benefited at year one. New systems are in the opposite position. A team's tool investment portfolio should age along with the system, but rarely does, because tool budgets are usually set once and forgotten.

**Constructive interference is a real failure mode.** Two long-wavelength defects can interact into a failure of much higher amplitude than either alone — the cache invariant that's wrong AND the state-machine transition that's wrong, where each is tolerable in isolation but the pair corrupts records. This explains the dissatisfaction of root-cause analyses that name X when really the incident was X *resonating with* Y. The frame doesn't dissolve the dissatisfaction, but it names it: long-wavelength defects that coexist in the same system can interfere, and incidents are sometimes their interference patterns.

**Premature detector optimisation is wasted.** Cultures that chase 100% test coverage but still ship cache-invalidation bugs have over-invested in a short-wavelength detector while the bugs that actually hurt them live at long wavelength. The metric is in the wrong band. Increasing it doesn't reduce production incidents because it doesn't reach the bugs that produce them. The corrective is not "try harder at coverage." It's "build the detector that's tuned to where your bugs actually are."

## Where the frame strains

In honesty: bugs aren't really single-frequency. A null pointer crash is short-wavelength in code-locality but might be long-wavelength in causation (the null arrived from a config change three commits ago in a service two boundaries away). Real defects are more like wavelet packets — narrow in some dimensions, wide in others.

Detection probability isn't always monotonic in wavelength either. A reviewer might be excellent at very short wavelengths and very long ones (architectural review) but unreliable in the middle. Tooling spectra have gaps and resonances of their own.

And forcing continuous metaphors onto discrete categories can mislead. Bug taxonomies are usually clusters, not points on a smooth axis.

The frame is an intuition pump, not a model. Use it for the questions it's good for, and don't ask it to do the work of an empirical study.

## Three questions to ask

What the frame is good for is a small set of decisions that come up constantly:

1. **Is another round of this review worth it?** Has the wavelength of remaining defects shifted out of the detector's band? If yes, swap detectors. If no, keep going.
2. **When I add a test, what wavelength am I trying to detect?** A unit test is a short-wavelength detector. An integration test is mid. A canary deploy is long. Make sure the test you're adding is in the band where the bugs you're worried about actually live.
3. **Does our tooling spectrum match the bug spectrum we actually produce?** If the team's incidents are routinely in the long-wavelength band but the team's tool spend is on linting and typing, the spectrum is mismatched. That's a deliberate decision to make, not an oversight to drift into.

The frame doesn't tell you what to build. It tells you when to stop running the test you've been running and try a different test instead. Most of the time, that's the harder decision.
