# Peer Review — the step that makes this more than "ask 5 times"

This is the core of Karpathy's insight. Without it you just have five parallel answers; with it the council surfaces what no single advisor could see.

## Anonymization rules
1. Collect all advisor responses (the 5 core + any guest seats — usually 5–7).
2. Assign letters A, B, C… with the advisor→letter mapping **randomized** every session (don't always map Contrarian→A). Positional and identity bias both matter.
3. **The guest specialist is anonymized like everyone else.** This is the load-bearing anti-overweighting guard: reviewers judge the guest's claims on merit with no authority cue, so a domain expert can't win on credentials.
4. Record the mapping privately — hidden from reviewers, revealed in the saved transcript.
5. Reviewers see only the lettered responses, never which advisor wrote which. Run one reviewer per response (extend the template below to as many letters as there are responses).

## Run 5 reviewers in parallel
Spawn 5 reviewer sub-agents in a single batched message. Each sees the framed question and all 5 anonymized responses, and answers the same three questions.

## Reviewer prompt template

```
You are reviewing the outputs of a review council. Five advisors independently
answered this question:

---
[framed question]
---

Here are their anonymized responses:

**Response A:**
[response A]

**Response B:**
[response B]

**Response C:**
[response C]

**Response D:**
[response D]

**Response E:**
[response E]

Answer these three questions. Be specific. Reference responses by letter.

1. Which response is the strongest? Why?
2. Which response has the biggest blind spot? What is it missing?
3. What did ALL five responses miss that the council should consider?

Keep your review under 200 words. Be direct.
```

## Why question 3 matters most
"What did all five miss?" is the highest-value output of the whole council. When five perspectives sit side by side, the *gaps between them* reveal what nobody thought to mention. Make sure the chairman weights this heavily — cross-cutting misses caught here often become the actual verdict.
