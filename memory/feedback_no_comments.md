---
name: No comments during refactoring
description: Don't add doc comments or inline comments when doing architectural refactoring
type: feedback
---

Don't add comments or doc comments to code during refactoring passes.

**Why:** User explicitly said "no comment needed for further refactoring."

**How to apply:** When migrating features to clean architecture (domain/data/presentation layers), write the code without any `///` doc comments or `//` inline comments. Only add comments if the logic is genuinely non-obvious and unrelated to the refactor structure.
