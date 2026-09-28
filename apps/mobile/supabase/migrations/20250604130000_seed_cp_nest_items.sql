-- Default CP Nest proposal gifts (same as previously shown in the app)
INSERT INTO public.cp_nest_items (id, name, price, image_url, category)
VALUES
  (
    'd1c6237b-3d75-4cad-9762-dced129ec025',
    'Love Card',
    1000,
    'https://wbwvtsnuvenxvetbhupf.supabase.co/storage/v1/object/public/cp_nest_assets/gifts/card.png',
    'card'
  ),
  (
    'c75f5130-8bbb-4b2d-889e-07e397cc4072',
    'Couple Frame',
    3000,
    'https://wbwvtsnuvenxvetbhupf.supabase.co/storage/v1/object/public/cp_nest_assets/gifts/frame.png',
    'frame'
  ),
  (
    'bf30c2c4-26c1-43e0-a34c-09eaa5809caa',
    'Royal Ring',
    5000,
    'https://wbwvtsnuvenxvetbhupf.supabase.co/storage/v1/object/public/cp_nest_assets/gifts/ring.png',
    'ring'
  ),
  (
    '917b6008-fb4b-4907-98a0-2e31368d200d',
    'Eternal Boutique',
    12000,
    'https://wbwvtsnuvenxvetbhupf.supabase.co/storage/v1/object/public/cp_nest_assets/gifts/boutique.png',
    'boutique'
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  price = EXCLUDED.price,
  image_url = EXCLUDED.image_url,
  category = EXCLUDED.category;
