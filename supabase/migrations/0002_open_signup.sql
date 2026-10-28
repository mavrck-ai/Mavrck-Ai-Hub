-- Mavrck AI Hub: open sign-up (no ID documents required)
-- Anyone can create a worker or developer account for themselves.
-- ID verification stays optional ('unverified' by default) and is never required to join or take jobs.

alter table workers alter column status set default 'active';

create policy "anyone signs up as a worker (self only)" on workers
  for insert with check (auth.uid() = id);

create policy "anyone signs up as a developer (self only)" on developers
  for insert with check (auth.uid() = id);

create policy "developers update own" on developers
  for update using (auth.uid() = id);

-- Workers can claim an open job for themselves.
create policy "workers claim open jobs" on jobs
  for update using (status = 'open' and worker_id is null)
  with check (worker_id = auth.uid() and status = 'assigned');

-- Workers submit proof for their own jobs.
create policy "workers submit own proofs" on job_proofs
  for insert with check (worker_id = auth.uid());
create policy "workers read own proofs" on job_proofs
  for select using (worker_id = auth.uid());
