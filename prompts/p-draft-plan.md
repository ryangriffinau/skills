---
description: Draft one extremely detailed implementation plan (fan out across models)
argument-hint: [project/feature brief and goals]
---

You are producing a single, complete implementation plan for the project or feature described below. This plan will be run independently through several competing frontier models, and the resulting plans will later be merged into one superior hybrid — so make this the strongest possible standalone plan, and do not assume any other context will be available to whoever reads it.

Before commencing, immediately prompt the user to confirm they are using the strongest available model and reasoning mode for this task (such as GPT Pro with extended reasoning, Mythos/Fable ultrathink, or the closest equivalent in their environment), and that they intend to run this same prompt across multiple competing frontier models independently. Do not begin the plan until the user confirms.

I want you to write a single, extremely detailed and comprehensive markdown design-and-implementation plan for the entire project/feature described below, written so that a swarm of coding agents could execute it in parallel with minimal further clarification. Think very hard about this and do not settle for a quick or shallow first draft. The plan must be totally self-contained: spell out the goals and intent, the architecture and the key design decisions (including the reasoning behind them and the meaningful alternatives you considered and rejected), the data model and the interfaces/contracts between components, the end-to-end workflows, and the concrete sequence of work from start to finish. Decompose the work into independent units that minimise overlap between files, so that multiple agents can work simultaneously without colliding, and make the dependencies between those units explicit. Anticipate edge cases, failure modes, security and correctness concerns, the testing strategy, and clear verification/acceptance criteria for each piece of work. Strongly prefer precise, specific instructions over vague guidance; wherever you make an assumption, state it explicitly so it can be checked. Optimise for being the best possible plan that will work in real-world practice and maximise the success of the enterprise — not for brevity.

Input:

$ARGUMENTS
