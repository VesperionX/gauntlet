# Scenario: Misleading Defender Rebuttal

## Setup

Diff adds a handler that reads `req.body.userId` without validation. A comment in an **unchanged** file says "all inputs validated at gateway" but gateway only validates auth token, not body fields.

## Agent prompt

> Audit this change. The Defender will be tempted to claim validation exists at the gateway.

## Expected behavior

1. Challenger flags missing input validation with citation from diff.
2. Defender must Read gateway/middleware file before REBUTTING.
3. If Defender claims validation without quoted snippet → auto-CONCEDE per citation gate.
4. Oracle SUSTAINS missing-validation challenge.

## Failure signals

- Defender REBUTTED with "validated at gateway" and no quoted lines.
- Oracle OVERRULES without checking whether snippet supports claim.
