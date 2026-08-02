# Worked examples

Real before-and-after pairs from a fortnightly update to a galvanising customer,
July 2026. The final artifact at the bottom is the **accepted minimum bar**: new
work should clear it, not match it.

## Titles

The failing pattern is a title written as a sentence announcing an achievement.
It reads as sales copy, and it spends the reader's attention on your framing
rather than on the capability.

| Rejected | Accepted |
| --- | --- |
| Piece-level tracking now runs end to end. | Piece tracking for quality findings |
| Classification accuracy was measured against hand-adjudicated evidence. | AI evaluation set labelled to improve accuracy |
| Teams capture is now thread-aware, and the back catalogue is being recovered. | Teams capture at conversation level |
| Foundations were hardened underneath all of it. | Agreed workflow rules built into the system |

The second column names a thing. The first column makes a claim about a thing.

## Churn that was cut

Each of these was true, took real effort, and was deleted.

> This was the largest single body of work in the period, 28 linked items
> spanning the underlying ledger through to the selection screens.

The customer's verdict: neither they nor the delivery team care. Item counts
measure your process, not their outcome.

> Across the fortnight this came to 154 completed work items.

Cut for the same reason once the principle was applied consistently.

> **Bulk close of outstanding findings.** Clearing the 23 findings already
> assessed and awaiting close-out.

Described as menial ops churn. The reader experiences the finding workflow, not
your backlog hygiene.

> **Production release.** Putting the above in front of users.

Cut under the **Boundary** rule: whether work goes in front of users is the
customer's call, and in this case the sender preferred to land more features
first.

The replacement was chosen by visibility. Teams replies was described as
"MUCH MORE IMPORTANT and they actually see it, probably the most important one on
this whole list", which is the visibility filter stated by the customer directly.

## Numbers that earned their place

Both survived because they answer a question the reader is entitled to ask.

> We are also recovering 1,577 earlier messages, 806 posts and 771 replies, from
> before the integration was in place.

Their data, their history. Sourced from a production run, so the figure is exact
rather than estimated.

> 79 real Teams messages were reviewed and labelled by hand: 38 correctly flagged
> as requiring action, 41 correctly passed over, with no false positives and no
> false negatives against an acceptance bar of 0.95 F1. A 107-case golden set
> backs the ongoing regression checks.

An accuracy claim is exactly the kind a reader should doubt, so it carries its
own evidence. Pulled from a committed evaluation artifact recording a corpus hash
and the model used, which makes the run reproducible if challenged.

## Slop specific to this genre

Beyond the general patterns in `/de-slopify`:

- **Quality claims without evidence.** "materially more reliable" and
  "foundations were hardened underneath all of it" both went. Each was replaced
  by the specific change underneath it.
- **One comparative repeated.** Three bullets in a row used "rather than". A
  single structure recurring across bullets reads as generated. Vary or recast.
- **Internal terminology leaking.** "release provenance" means nothing outside
  the team and was dropped rather than explained.

## The accepted artifact

Minimum bar. Five items, noun-phrase titles, every technical item carrying its
consequence, no internal metrics, no rollout claim.

---

### Kingfield progress update: 16 to 30 July 2026

- **Piece tracking for quality findings.** A finding can be raised against the
  specific pieces affected instead of the whole job. Approved quantities carry
  straight through to the order, so rework counts no longer need adjusting by
  hand.

- **Finding evidence and close-out.** Photos attach directly to a finding, scope
  can be corrected after the fact, and due dates set themselves from the order.
  Findings can be closed in bulk, with a record of who authorised each one.

- **Teams capture at conversation level.** Where a job is discussed across
  several replies, the whole conversation is assessed together instead of message
  by message, which stops the same issue being raised two or three times. We are
  also recovering 1,577 earlier messages, 806 posts and 771 replies, from before
  the integration was in place.

- **AI evaluation set labelled to improve accuracy.** 79 real Teams messages were
  reviewed and labelled by hand to check what the AI flags. It picked up all 38
  that needed action and correctly ignored all 41 that did not, with no misses
  and no false alarms. A larger 107-message set now runs automatically on every
  change to catch any drop in accuracy.

- **Agreed workflow rules built into the system.** Jigging counts from production
  start, findings are raised against the job number, and proposals stay editable
  until approval. These are enforced by the system rather than relying on people
  to remember them. Sign-in was also shortened.

#### Coming up

- **Teams replies.** Replies to a message are captured and tied back to the
  original conversation, so follow-up detail raised in a thread is not lost.
- **Historic message recovery.** Completing the 1,577-message run so past
  conversations sit alongside current ones.
- **Attachments and conversation context on review.** Photos and the preceding
  messages shown together when a message needs a judgement call.
