# Mikado Method — Fil Rouge: Complete Worked Example

**Goal:** Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server

This file is the reference worked example for `SKILL.md`. It covers:
1. Goal coverage check
2. Pre-exploration audit
3. Tree evolution with pattern proposals per cycle
4. Validation before execution
5. Execution of a leaf (TDD — Java / TypeScript / Python)
6. Anti-pattern: false leaf
7. Team workflow

---

## 1. Goal Coverage Check

Direct children of the Goal, once all `[x]`:
1. `Replace direct SmtpClient calls in BillingService with NotificationGateway calls` → billing logic no longer knows the notification channel ✓
2. `Remove now-unused SmtpClient field from BillingService` → no SMTP artifact remains in billing ✓

Both together make the Goal's business statement true. ✓

---

## 2. Pre-Exploration Audit

```bash
git grep -nw "NotificationGateway\|SmtpNotificationGateway\|SmtpClient" -- 'tests/**' 'src/**'
```

Result: `tests/billing_service_test.ts:29` instantiates `SmtpClient` directly in a fixture → hidden dependency,
recorded as `{N6}` so the naive attempts don't miss it (it enters the tree in cycle 2, under `{N1}`).

---

## 3. Tree Evolution with Per-Cycle Pattern Proposals

### After goal definition (no exploration yet)

```text
[ ] Goal: Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server
```

---

### Exploration cycle 1 — naive attempt on Goal (HEAD: a1b2c3d)

**Attempt:** call `gateway.notifyInvoiceIssued(invoice)` in `BillingService.issueInvoice()`.

**Errors captured:**
```
src/services/BillingService.ts:11  TS2304 Cannot find name 'NotificationGateway'
src/services/BillingService.ts:14  TS2339 Property 'gateway' does not exist
```

**Gate 2 — Pattern proposal (cycle 1):**
> "These errors suggest the **Ports & Adapters** pattern: define a `NotificationGateway` port owned
> by the billing domain, implemented by an SMTP adapter and injected into `BillingService`.
> A) Apply  B) Use a different approach"

User selects A. Nodes added. Tree committed.

```text
[ ] Goal: Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server
│ [ ] {N1} Replace direct SmtpClient calls in BillingService with NotificationGateway calls
│   [discovered-by: a1b2c3d]
│   [parent-error: src/services/BillingService.ts:11: TS2304 Cannot find name 'NotificationGateway']
│ [ ] {N2} Remove now-unused SmtpClient field from BillingService (cleanup)
│   requires: {N1}
│   [discovered-by: a1b2c3d]
│   [parent-error: src/services/BillingService.ts:3: SmtpClient field will be orphaned]
```

> **Note on `{N2}`:** removing the field before `{N1}` is done would break compilation —
> `BillingService` still calls it. The `requires: {N1}` cross-reference encodes that order
> in the graph itself; a comment like "(do this last)" would not survive validation or
> protect an executor from picking `{N2}` first.

---

### Exploration cycle 2 — naive attempt on {N1} (HEAD: b2c3d4e)

**Attempt:** inject `gateway: NotificationGateway` in the constructor, call `gateway.notifyInvoiceIssued()`.

**Errors captured:**
```
src/services/BillingService.ts:5  TS2304 Cannot find name 'NotificationGateway'
src/di/container.ts:22            Error: No binding found for NotificationGateway
tests/billing_service_test.ts:29  TS2345 SmtpClient fixture no longer matches constructor
```

No new pattern implied (Ports & Adapters already confirmed). Nodes added directly, including
the hidden test dependency `{N6}` found by the pre-exploration audit.

```text
[ ] Goal: Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server
│ [ ] {N1} Replace direct SmtpClient calls in BillingService with NotificationGateway calls
│   [discovered-by: a1b2c3d]
│   [parent-error: src/services/BillingService.ts:11: TS2304 Cannot find name 'NotificationGateway']
│ │ [ ] {N3} Update BillingService constructor to accept NotificationGateway
│ │   requires: {N5}
│ │   [discovered-by: b2c3d4e]
│ │   [parent-error: src/services/BillingService.ts:5: TS2304 Cannot find name 'NotificationGateway']
│ │ │ [ ] {N5} Create NotificationGateway interface (notifyInvoiceIssued + notifyPaymentOverdue)
│ │ │   [discovered-by: b2c3d4e]
│ │ │   [parent-error: src/services/BillingService.ts:5: TS2304 Cannot find name 'NotificationGateway']
│ │ [ ] {N4} Register NotificationGateway → SmtpNotificationGateway in DI container
│ │   requires: {N5}, {N7}
│ │   [discovered-by: b2c3d4e]
│ │   [parent-error: src/di/container.ts:22: No binding found for NotificationGateway]
│ │ [ ] {N6} Replace direct SmtpClient fixture in billing tests with a NotificationGateway stub
│ │   requires: {N5}
│ │   [discovered-by: b2c3d4e]
│ │   [parent-error: tests/billing_service_test.ts:29: TS2345 SmtpClient fixture no longer matches constructor]
│ [ ] {N2} Remove now-unused SmtpClient field from BillingService (cleanup)
│   requires: {N1}
│   [discovered-by: a1b2c3d]
│   [parent-error: src/services/BillingService.ts:3: SmtpClient field will be orphaned]
```

---

### Exploration cycle 3 — naive attempt on {N4} (HEAD: c3d4e5f)

**Attempt:** bind `NotificationGateway` to `SmtpNotificationGateway` in `src/di/container.ts`.

**Errors captured:**
```
src/di/container.ts:22                          TS2304 Cannot find name 'SmtpNotificationGateway'
src/notifications/SmtpNotificationGateway.ts:31 TS2304 Cannot find name 'NotificationFailedError'
```

The adapter does not exist yet, and its method bodies need an error type to raise when SMTP
delivery fails. Two nodes added under `{N4}`:

```text
│ │ [ ] {N4} Register NotificationGateway → SmtpNotificationGateway in DI container
│ │   requires: {N5}, {N7}
│ │   [discovered-by: b2c3d4e]
│ │   [parent-error: src/di/container.ts:22: No binding found for NotificationGateway]
│ │ │ [ ] {N7} Implement SmtpNotificationGateway (SmtpClient via constructor + method bodies)
│ │ │   requires: {N5}, {N8}
│ │ │   [discovered-by: c3d4e5f]
│ │ │   [parent-error: src/di/container.ts:22: TS2304 Cannot find name 'SmtpNotificationGateway']
│ │ │ │ [ ] {N8} Create NotificationFailedError class
│ │ │ │   [discovered-by: c3d4e5f]
│ │ │ │   [parent-error: src/notifications/SmtpNotificationGateway.ts:31: TS2304 Cannot find name 'NotificationFailedError']
```

No new nodes emerge from further attempts — exploration is complete, tree is stable.

> **DAG note:** `{N5}` is a shared prerequisite of `{N3}`, `{N4}`, `{N6}`, and `{N7}`.
> One `{N5}` node, one `[x]` to mark. No duplication.

---

## 4. Validation before Execution

```bash
bash {{SKILL_DIR}}/validate-mikado.sh docs/mikado/notification-gateway.mikado.md
# Smoke test with bundled sample: bash {{SKILL_DIR}}/validate-mikado.sh {{SKILL_DIR}}/sample.mikado.md
```

Expected: all nodes have `discovered-by` + `parent-error`, all `requires:` IDs resolve,
no cycles, child SHAs ≥ parent SHAs. Exit 0.

---

## 5. True Leaves

| Node | File to create/modify | Parallelisable? |
|---|---|---|
| `{N5}` Create NotificationGateway interface | `src/notifications/NotificationGateway.*` | Yes |
| `{N8}` Create NotificationFailedError | `src/notifications/NotificationFailedError.*` | Yes |

`{N6}` and `{N7}` unlock as soon as `{N5}` (and `{N8}` for `{N7}`) are `[x]`.

Full execution order: `{N5}`, `{N8}` → `{N6}`, `{N7}` → `{N3}`, `{N4}` → `{N1}` → `{N2}`.

---

## 6. Execution of Leaf {N5} — Create NotificationGateway Interface

### Java

```java
// RED — src/test/java/notifications/NotificationGatewayTest.java
@Test
void shouldDefineInterfaceMethods() {
    NotificationGateway gateway = mock(NotificationGateway.class);
    gateway.notifyInvoiceIssued(new Invoice());    // COMPILE ERROR until interface exists
    gateway.notifyPaymentOverdue(new Invoice());
}

// GREEN — src/main/java/notifications/NotificationGateway.java
public interface NotificationGateway {
    void notifyInvoiceIssued(Invoice invoice);
    void notifyPaymentOverdue(Invoice invoice);
}
// COMMIT: "feat: create NotificationGateway interface (notifyInvoiceIssued + notifyPaymentOverdue)"
```

### TypeScript

```typescript
// RED — src/notifications/__tests__/NotificationGateway.test.ts
it('defines notifyInvoiceIssued and notifyPaymentOverdue', () => {
  const gateway = {} as NotificationGateway;        // TS error until interface exists
  const fn: (invoice: Invoice) => Promise<void> = gateway.notifyInvoiceIssued;
  expect(fn).toBeDefined();
});

// GREEN — src/notifications/NotificationGateway.ts
export interface NotificationGateway {
  notifyInvoiceIssued(invoice: Invoice): Promise<void>;
  notifyPaymentOverdue(invoice: Invoice): Promise<void>;
}
// COMMIT: "feat: create NotificationGateway interface (notifyInvoiceIssued + notifyPaymentOverdue)"
```

### Python

```python
# RED — tests/notifications/test_notification_gateway.py
from src.notifications.notification_gateway import NotificationGateway

def test_defines_notify_invoice_issued():
    assert hasattr(NotificationGateway, 'notify_invoice_issued')   # AttributeError until defined

# GREEN — src/notifications/notification_gateway.py
from typing import Protocol
class NotificationGateway(Protocol):
    def notify_invoice_issued(self, invoice: Invoice) -> None: ...
    def notify_payment_overdue(self, invoice: Invoice) -> None: ...

# COMMIT: "feat: create NotificationGateway protocol (notify_invoice_issued + notify_payment_overdue)"
```

**Before committing:** mark `{N5}` as `[x]` in `.mikado.md`, run `validate-mikado.sh`, verify exit 0.

---

## 7. Anti-pattern — False Leaf

Attempting `{N7} Implement SmtpNotificationGateway` before `{N8}` is `[x]`:

```
src/notifications/SmtpNotificationGateway.ts:31  TS2304 Cannot find name 'NotificationFailedError'
```

→ `{N7}` is not a true leaf. Revert. The tree already encodes `{N7} requires: {N5}, {N8}`.
Implement `{N8}` first.

The same trap exists higher up: `{N2}` sits at depth 1 with no children, but its
`requires: {N1}` makes it the **last** node to execute, not the first.

---

## 8. Mikado in a Team

### Branch convention
- One branch per leaf: `mikado/leaf/<kebab-node-name>`
- Tree updates on a shared branch `mikado/tree` via lightweight PR
- Example: `mikado/leaf/create-notification-gateway-interface`

### Parallel execution
Initial true leaves are independent:
```text
│ │ │ [ ] {N5} Create NotificationGateway interface    ← Developer A
│ │ │ │ [ ] {N8} Create NotificationFailedError        ← Developer B
```
As soon as `{N5}` is merged, `{N6}` (test fixture stub) unlocks for a third developer.

### Pull Requests
- One PR per leaf — small, atomic, easy to review
- PR title mirrors the node: `feat: create NotificationGateway interface (notifyInvoiceIssued + notifyPaymentOverdue)`
- Merge to main only when tests are green

### Handling merge conflicts
If two leaf branches touch the same file:
1. Treat the conflict as a new implicit dependency.
2. Add a coordination node above both conflicting leaves.
3. Revert both branches to their pre-leaf state.
4. Implement the coordination node first, then retry the leaves.

### Rules
- **One developer per active leaf.** First commit wins. Coordinate via the tree file.
- The `.mikado.md` is the single source of truth. Update it before switching context.
