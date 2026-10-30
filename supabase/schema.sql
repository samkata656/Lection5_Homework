-- Orders Processor: run once in Supabase → SQL Editor

-- 1. Vector support for the supplier search (RAG)
create extension if not exists vector;

-- 2. Server-side drafts: the approve step sends only the draft stored here,
--    and the status column prevents sending the same draft twice.
create table if not exists public.order_drafts (
  session_id  text primary key,
  draft       jsonb not null,
  status      text not null default 'pending',  -- pending → sending → sent
  po_number   text,
  updated_at  timestamptz not null default now(),
  sent_at     timestamptz
);
alter table public.order_drafts enable row level security;

-- 3. These two tables are created automatically by n8n:
--    suppliers_rag         → by the RAG loader workflow (first run)
--    orders_chat_histories → by the Postgres Chat Memory node (first chat message)
--    After both exist, run:
-- alter table public.suppliers_rag enable row level security;
-- alter table public.orders_chat_histories enable row level security;
