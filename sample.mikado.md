# Mikado Sample — validate-mikado.sh fixture

Minimal valid graph used to test `validate-mikado.sh`.

Run: `bash {{SKILL_DIR}}/validate-mikado.sh {{SKILL_DIR}}/sample.mikado.md`

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
