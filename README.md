# Orders Processor – Lection 5 homework

An AI automation for a fictional computer hardware shop (**samkobuilds.hardware**). An employee describes a supplier order in a chat (optionally with a photo). An AI agent finds the supplier in a RAG database, asks follow-up questions if needed and returns an email draft. The email is sent and logged to Google Sheets **only** after the employee clicks "Изпрати имейла".

- **Live demo:** https://samkata656.github.io/orders-processor/ (login sent privately)
- **Frontend code:** https://github.com/samkata656/orders-processor

## How it works

```
Browser (GitHub Pages) ── POST + Basic Auth ──► n8n Webhook ──► Switch (action)
   ping     → "pong" (login check)
   message  → Guardrails (jailbreak check) → AI Agent (+ supplier RAG, chat memory)
              → draft saved in Supabase → reply / draft card to the page
   approve  → load + lock the stored draft → Gmail → mark sent → log PO in Google Sheets
   other    → "Невалидна заявка"
Any error → L5_error workflow → Google Sheets error log + alert email
```

| Spec requirement | Solution |
| --- | --- |
| Communication interface | Custom page on GitHub Pages → n8n Webhook with Basic Auth |
| RAG with suppliers | Supabase pgvector table `suppliers_rag`, Gemini embeddings |
| Ask on missing / duplicate / unknown supplier | System prompt rules + `supplier_directory` tool |
| Weekday + date | 14-day calendar injected into the system prompt |
| Image of the item | Photo passed to the agent and attached to the email |
| Send only after confirmation | A button, not chat text. The browser only says "send"; the draft comes from the database |
| Error handler + empty output | Retry loop (3 attempts), then Stop and Error → `L5_error` (log + email) |
| Jailbreak protection + log | Guardrails node (keywords + AI check) → `jailbreak log` sheet |

## Repo contents

| Path | What |
| --- | --- |
| `n8n/L5_Main.json` | Main workflow |
| `n8n/L5_error.json` | Error workflow |
| `n8n/RAG_loader.json` | Loads the suppliers into the vector database |
| `supabase/schema.sql` | Database setup |
| `data/suppliers.csv` | 12 test suppliers (all emails `@example.com`) |
| `data/purchase_orders_*.csv` | Column headers for the 3 log tabs |

## How to run

**You need:** an n8n instance, a Supabase project, a Google account, and API keys for Anthropic, OpenAI and Google Gemini.

1. **Supabase:** run `supabase/schema.sql` in the SQL Editor.
2. **Google Sheets:**
   - Import `data/suppliers.csv` into a new sheet ("suppliers").
   - Create a sheet "purchase orders" with 3 tabs named `Po log`, `error log` and `jailbreak log`. Row 1 of each tab = the headers from the matching `data/purchase_orders_*.csv`.
3. **n8n credentials:** Anthropic, OpenAI, Google Gemini, Postgres (Supabase → Connect → session pooler), Gmail OAuth2, Google Sheets OAuth2, and Basic Auth (the login for the page).
4. **Import the 3 workflows** from `n8n/` and connect your credentials in every node with a warning.
5. **Point the nodes to your own data:**
   - Every Google Sheets node → your sheets and tabs.
   - `L5_error` → `Notify` node → your email address.
   - `L5_Main` → Settings → Error workflow → `L5_error`.
6. **Load the suppliers:** open `RAG generating` and click Execute workflow once (12 rows appear in `suppliers_rag`). The unconnected "Embeddings OpenAI" and "Token Splitter" nodes are unused.
7. **Publish** `L5_Main` and `L5_error`.
8. **Frontend:** fork the frontend repo, set `WEBHOOK_URL` in `src/config.ts` to your production webhook URL and deploy to GitHub Pages. In the `Webhook` node set **Allowed Origins** to your Pages address (e.g. `https://yourname.github.io`), then publish again.
9. **Lock the tables:** after the first chat message, run the two commented lines at the end of `schema.sql`.

**Quick test:** "Напиши имейл на Филип и заяви 20 SSD диска 1TB с доставка в петък. Искай писмено потвърждение." The agent should ask which of the two Filips you mean.

## Known limitations

- One shared login, no per-user audit trail.
- If the agent output is retried, an attached photo is not re-sent to the model.
- Supplier updates need a manual re-run of the loader (re-running duplicates rows; clear the table first).
- Emails go through a personal Gmail account (sending limits).
- Execution logs store the Basic Auth header; enable execution redaction for real use.
