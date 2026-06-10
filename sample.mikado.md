# Mikado Sample — validate-mikado.sh fixture

Minimal valid graph used to test `validate-mikado.sh`. The `discovered-by`
SHAs are fictional, so the git-history checks must be skipped with `--no-git`
(never use that flag on a real graph).

Run: `bash {{SKILL_DIR}}/validate-mikado.sh --no-git {{SKILL_DIR}}/sample.mikado.md` — expected exit 0.

The graph is wrapped in a fenced block so GitHub renders it verbatim; the
validator ignores fence and prose lines.

```text
[ ] Goal: Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server
│ [ ] {N1} Replace direct SmtpClient calls in BillingService with NotificationGateway calls (src/services/BillingService.ts:11)
│   [discovered-by: d2e6f501a130dcaf3798353f04553002faee5bcf]
│   [parent-error: src/services/BillingService.ts:11: TS2304 Cannot find name 'NotificationGateway']
│ │ [ ] {N2} Create NotificationGateway interface with notifyInvoiceIssued and notifyPaymentOverdue (src/notifications/NotificationGateway.ts)
│ │   [discovered-by: d2e6f501a130dcaf3798353f04553002faee5bcf]
│ │   [parent-error: src/services/BillingService.ts:5: TS2304 Cannot find name 'NotificationGateway']
```
