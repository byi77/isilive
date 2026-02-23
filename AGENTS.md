# AGENTS

## Mandatory Rule Contract Source

- Read `RULES_LOGIC.md` before implementing runtime behavior changes.
- Treat every rule block with `Status: active` as a hard contract.
- If code changes affect an active rule, update deterministic tests and rule-to-test mappings in the same change.
- `RULES_LOGIC.md` is maintained in German; preserve German wording in that file.
- Keep `RULES_LOGIC.md` append-only in user entry order (no forced sorting/reordering of rule blocks).
- Allow duplicate draft ideas temporarily; surface duplicate summary text as warnings and clarify/merge only with user confirmation.
- After every change to `RULES_LOGIC.md`, review each new/changed sentence, rewrite it into precise machine-checkable intent, and ask the user follow-up questions if meaning is ambiguous.

## Mandatory Validation

- Run `lua tools/validate_usecases.lua` before finalizing.
- `tools/validate_usecases.lua` includes rules-logic validation and deterministic runtime scenario validation.
- If validation fails, do not proceed until the failure is resolved.
