CREATE INDEX CONCURRENTLY IF NOT EXISTS baishun_orders_created_idx
  ON public.baishun_orders (created_at);
