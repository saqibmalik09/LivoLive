-- Allow charm level reward rows without uploaded badge image_url.
ALTER TABLE public.charm_level_assets
  ALTER COLUMN image_url DROP NOT NULL;
