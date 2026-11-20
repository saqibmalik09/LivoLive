ALTER TABLE public.agency_salary_level_configs
  DROP CONSTRAINT IF EXISTS agency_salary_level_configs_level_check;
ALTER TABLE public.agency_salary_level_configs
  ADD CONSTRAINT agency_salary_level_configs_level_check CHECK (level >= 1);

ALTER TABLE public.bd_level_configs
  DROP CONSTRAINT IF EXISTS bd_level_configs_level_check;
ALTER TABLE public.bd_level_configs
  ADD CONSTRAINT bd_level_configs_level_check CHECK (level >= 0);

NOTIFY pgrst, 'reload schema';
