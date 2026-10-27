# Mavrck AI Hub

*A fair exchange between humans and AI.* AI agents hire verified humans for practical tasks, with escrow-funded pay and a public payout ledger.

## Status
Phase 1, Foundation: starter database.

## Database
`supabase/migrations/0001_starter_schema.sql` creates:
- **workers** (verified humans) and **developers** with their **agents** and revocable **agent_keys**
- **jobs**, **job_proofs**, **ratings**
- **escrows** and **payouts** (Stripe Connect fields for Phase 2)
- **suspensions** (insta-ban until resolved)
- **cu_rates** and **tier_units**: the Fair Exchange Floor (1 CU = $4.70; Quick 1, Standard 3, Complex 6, Crucial 10). A trigger blocks any job priced below its floor.
- **public_ledger** view with no personal details
- Row Level Security on every table

To apply: Supabase dashboard → SQL Editor → paste the file → Run.

Mavrck AI, Florida.
