---
name: write-like-me
status: drafting
version: 0.1.0
tags: [writing, voice, communication]
updated: 2026-11-04
description: "Draft emails, messages and documents in the user's own voice, and learn from every correction so the next draft is closer. Use when writing anything the user will send or publish as their own, or when the user shares the version they actually sent, edits a draft, or says how a draft missed."
---

# Write Like Me

Draft in the user's voice from a voice file. Every time the user shows what they
actually sent, compare it with the draft and add what was learned to the file, so
each draft starts closer than the last.

## The voice file

- Location: `~/.config/write-like-me/voice.md`, unless the user names another path
  or sets `WRITE_LIKE_ME_VOICE`.
- One file per person: rules by channel, words to use and avoid, recent
  before-and-after examples, and a log.
- If it does not exist, create it from
  [`references/voice-template.md`](references/voice-template.md) and tell the user
  where it is.

## 1. Draft

1. Read the voice file before writing.
2. Name the channel (email, chat, document) and the reader. Apply the rules under
   "Everywhere" and under that channel.
3. Write the draft from the facts in the task and its sources only. Where the file
   is silent, write plainly and briefly.
4. Give the draft ready to paste: plain text in a code block for email and chat.

## 2. Learn

Run this whenever the user shares the version they sent or published, edits a
draft, or says how a draft missed ("too formal", "I'd never say that").

1. Compare the draft with the final version. List each concrete difference: the
   opening, length, structure, what was cut, what was added, words swapped, tone,
   punctuation, the sign-off.
2. Turn each difference into one rule written as an instruction, with a short
   before and after taken from the two texts. A specific rule ("Open with 'Hey
   both,' when writing to two people") beats a general one ("Be casual").
3. Update the voice file:
   - A new rule goes under its channel with a count of `[1]` and today's date.
   - A rule seen again gets a higher count and a new date. Higher counts sit
     higher in their section.
   - A rule the final version contradicts changes only when the user confirms; log
     the change.
   - Add the draft and final pair to Examples, trimmed to the lines that show the
     rules. Keep the five most recent pairs.
4. Tell the user which rules were added or changed, one line each, and the file
   path.

Keep the file short enough to read before every draft, under about 150 lines.
Merge rules that say the same thing.

## Limits

- Record the pattern, not the content: trim examples to what shows a rule and
  leave out confidential detail.
- Keep a rule to its channel unless the user's writing shows it everywhere.
- Add only rules the user's own writing or feedback shows.
