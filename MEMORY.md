# MEMORY.md — How the agent remembers

## The one rule of state
`memory/history.json` is the ONLY thing that persists between runs. Each weekly
run is otherwise stateless: search results and the composed message are
discarded when the process exits. The repo IS the database — there is no server,
no external store. Read the file at the start of a run, write it at the end.

## File shape
```json
{
  "themes": {
    "<theme-id>": {
      "last_run": "2026-05-26T03:30:00Z",
      "sent": [
        {
          "fp": "url:https://lab.com/post-x",
          "title": "Lab X ships model Y",
          "url": "https://lab.com/post-x",
          "source_type": "permalink",
          "date": "2026-05-24",
          "sent_at": "2026-05-26T03:30:00Z"
        }
      ]
    }
  }
}
```
- `last_run` — ISO-8601 UTC of the previous run for that theme.
- `sent` — every item already delivered, keyed by `fp` (fingerprint).
- Missing or corrupt file → treat as `{"themes": {}}` (everything is new).

## Fingerprints (the dedup key)
- `permalink` / `permalink_feed` sources (news mode):
  `fp = "url:" + normalized_url`
  (lowercase host, strip tracking query params like `utm_*`, strip trailing `/`).
  These URLs are stable, so the URL identifies the content.
- `living` sources (X timelines, news homepages):
  `fp = "txt:" + sha1(normalized_title + "|" + date)`.
  The URL is intentionally IGNORED — a living page keeps one URL while its
  content changes daily. Identity comes from the headline + date instead.
- `events` mode themes:
  `fp = "evt:" + sha1(normalized_title + "|" + date + "|" + venue)`.
  An event is one real-world happening; name + date + venue identify it so the
  same event isn't re-announced every week until it passes. Event `sent` entries
  also store `venue`.

## "Is this item included?"
- **news** themes — an item is new only if BOTH: its `fp` is NOT already in
  `sent`, AND its `date` is after `last_run` (null passes) and within
  `defaults.recency_days` of now. This is why daily-updating sources don't break:
  the same `living` URL reappears weekly, but only headlines we haven't
  fingerprinted-and-dated before count as new.
- **events** themes — an event is included if its `fp` is NOT already in `sent`
  AND its event `date` is in the future, within `event_window_days`. Events look
  FORWARD (what's coming up), not backward (what changed since last_run).

## Writing state back (only for items that were sent successfully)
1. Append each sent item to its theme's `sent` (with `sent_at` = run start;
   events also store `venue`).
2. Set `last_run` to the run start time for EVERY theme in the config — even
   themes that produced nothing this week (they were still checked).
3. Prune stale `sent` entries: news items whose `sent_at` is >60 days old, and
   events whose event `date` is already in the past. Keeps the file bounded.
4. Write back pretty-printed.

If an item's send failed, do NOT record that item — leaving it out of history
makes the next run retry it.
