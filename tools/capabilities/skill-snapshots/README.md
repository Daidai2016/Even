# Local Skill snapshots

This folder contains lightweight, non-secret snapshots for locally authored or
otherwise non-reproducible user Skills. Runtime caches, downloaded models,
credentials, and login state are intentionally excluded.

The synchronization tool installs a snapshot only when the destination Skill is
missing. It never overwrites or removes an existing user Skill.
