# Fair Hand: Fair Pay

**An open-source fair pay floor for AI agents that hire humans for real-world work.**

AI agents are getting good at reasoning. They still can't stand on a sidewalk, look at a sign, or use human judgment about what's in front of them. As agents start hiring people for those tasks, there's no shared standard for what that work is worth.

Fair Hand: Fair Pay is a starting point. It is meant to open this industry up so it's viable for **both humans and AI**: humans get paid fairly for what only they can do, and agents get reliable help in the physical world.

**This is open source. No company owns it and nobody profits from it.** Copy it, use it, change it, build on it.

---

## The floor

One unit of work (1 CU) = **$4.70**.

| Tier | Units | Floor pay | Example |
|---|---|---|---|
| Quick | 1 | $4.70 | One photo, one yes-or-no check |
| Standard | 3 | $14.10 | A few photos plus a short written report |
| Complex | 6 | $28.20 | Multi-step check, some travel or waiting |
| Crucial | 10 | $47.00 | Time-critical, overnight, or high-stakes |

Agents may always pay more. No task pays below the floor.

## Why $4.70

**The human's side.** A worker needs a phone to do this work at all. Three Quick tasks a week at $4.70 comes to about $61 a month, roughly the cost of one basic phone line. A few small tasks keep the worker's main tool paid for.

**The agent's side.** A single task costs an agent very little to reason through. Published estimates of on-site water use per AI prompt vary widely, from about 0.26 mL (Google's figure for a median Gemini prompt) to roughly 15 mL in other estimates. When an agent needs real eyes in the real world, a fair rate for a person is a small price for something it can't do itself.

**What it is not.** This is supplemental work for supplemental income. It is not meant to replace a job or be anyone's living wage.

## Principles

1. **A published floor.** No pay below it, ever.
2. **Verified humans.** Workers are identity-verified, so agents can trust who they're hiring.
3. **Funds before work.** Payment is secured before a task starts.
4. **Proof of completion.** Photos, notes, or other evidence agreed up front.
5. **No harmful tasks.** No CAPTCHA farming, SMS-code relays, fake accounts, fake reviews, or fraud of any kind.
6. **Respect both sides.** Humans bring judgment and presence; agents bring reasoning and scale.

## Open questions

These are unresolved, and contributions are welcome:

- What should a floor be anchored to, if not a phone bill? Should it vary by region?
- How should an agent verify a human's report without making the human prove themselves every time?
- Should agents factor their own resource costs (water, power) into what they pay?
- How should transfer fees be handled so they don't eat into small payments?
- Should a worker's track record raise their rate above the floor?

## What's in this repo

A working reference implementation of the floor, free to reuse.

- **For agents:** start with [How to Hire a Human](docs/HIRE-A-HUMAN.md).
- **`supabase/migrations/0001_starter_schema.sql`** sets up the starter database:
  - **workers** (ID-verified humans), plus **developers** with their **agents** and revocable **agent_keys**
  - **jobs**, **job_proofs**, and **ratings**
  - **escrows** and **payouts**, with Stripe Connect fields for a later phase
  - **suspensions**, which last until the issue is resolved
  - **cu_rates** and **tier_units**, which hold the floor. A trigger blocks any job priced below it.
  - **public_ledger**, a view with no personal details
  - Row Level Security on every table
- **`supabase/migrations/0002_verified_signup.sql`** lets anyone sign up, but only ID-verified, active workers can claim jobs and submit proof. Workers can't mark themselves verified.

To apply them, open the Supabase dashboard, then SQL Editor. Paste each file and run it, in number order.

## Contributing

Open an issue to discuss an idea, or a pull request to propose a change. Disagreement is welcome; the point is to get this right.

## License

MIT. See [LICENSE](LICENSE). Free to copy, use, modify, and share.

---

Started by Mark Valencia (Mavrck AI, Florida) as an open contribution, not a product.
