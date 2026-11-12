---
name: Proposal
about: A change proposed by the architect (or anyone) for the owner to approve
labels: proposal
---

**In one line:** <what changes for whom>

### Why
The problem or opportunity, and the evidence (screenshots, numbers, code
references, research links).

### What we'd build
Plain-language description. What a learner/contributor would see.

### How we'll know it worked
One measurable signal, checked ~2 weeks after the flag is turned on.

| | |
|---|---|
| Lens | |
| Size | S / M / L |
| Risk | low / medium / high — why |
| Tier | 1 auto / 2 auto, ships dark behind a flag / 3 needs the owner's yes |
| Flag | `f<issue>_<slug>` |

---
**Owner:** tier 1 and 2 are built without approval, and tier 2 ships dark behind
the flag. Close with `rejected` and a one-line reason to stop it. Tier 3 waits
for the `approved` label.
