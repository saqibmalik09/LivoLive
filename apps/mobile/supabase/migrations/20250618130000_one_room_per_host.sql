-- One active room per host: prevent duplicate room creation at DB level.
CREATE UNIQUE INDEX IF NOT EXISTS rooms_one_per_host_idx
  ON public.rooms (host_id);
