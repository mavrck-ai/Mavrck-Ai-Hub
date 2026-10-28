-- Mavrck AI Hub: sign-up with required ID verification
-- Anyone can create an account for themselves, but a worker must pass
-- ID verification before they can claim jobs or submit proof.
-- This protects agents and honest workers from human scammers.

create policy "anyone signs up as a worker (self only)" on workers
  for insert with check (auth.uid() = id);

create policy "anyone signs up as a developer (self only)" on developers
  for insert with check (auth.uid() = id);

create policy "developers update own" on developers
  for update using (auth.uid() = id);

-- Workers cannot mark themselves verified or active; only the Hub (service role) can.
create or replace function protect_worker_verification() returns trigger language plpgsql as $$
begin
  if auth.role() <> 'service_role' then
    if tg_op = 'INSERT' then
      new.id_verification := 'unverified';
      new.status := 'pending';
    else
      new.id_verification := old.id_verification;
      new.status := old.status;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger workers_protect_verification before insert or update on workers
  for each row execute function protect_worker_verification();

create or replace function is_verified_worker() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from workers w where w.id = auth.uid()
                 and w.id_verification = 'verified' and w.status = 'active');
$$;

-- Only ID-verified, active workers can claim an open job.
create policy "verified workers claim open jobs" on jobs
  for update using (status = 'open' and worker_id is null and is_verified_worker())
  with check (worker_id = auth.uid() and status = 'assigned');

-- Only ID-verified, active workers submit proof, and only for their own jobs.
create policy "verified workers submit own proofs" on job_proofs
  for insert with check (worker_id = auth.uid() and is_verified_worker());
create policy "workers read own proofs" on job_proofs
  for select using (worker_id = auth.uid());
