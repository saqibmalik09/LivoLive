-- Hot tab feature cards below banner (admin-managed media).

CREATE TABLE IF NOT EXISTS public.home_hot_cards_config (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  carousel_1_url text NOT NULL DEFAULT '',
  carousel_1_media_type text NOT NULL DEFAULT 'image',
  carousel_1_link text NOT NULL DEFAULT 'game',
  carousel_2_url text NOT NULL DEFAULT '',
  carousel_2_media_type text NOT NULL DEFAULT 'image',
  carousel_2_link text NOT NULL DEFAULT 'cp',
  carousel_3_url text NOT NULL DEFAULT '',
  carousel_3_media_type text NOT NULL DEFAULT 'image',
  carousel_3_link text NOT NULL DEFAULT 'charm',
  party_card_url text NOT NULL DEFAULT '',
  party_card_media_type text NOT NULL DEFAULT 'image',
  music_card_url text NOT NULL DEFAULT '',
  music_card_media_type text NOT NULL DEFAULT 'image',
  carousel_interval_ms int NOT NULL DEFAULT 4000,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT home_hot_cards_carousel_1_media_check
    CHECK (carousel_1_media_type IN ('image', 'svga', 'video')),
  CONSTRAINT home_hot_cards_carousel_2_media_check
    CHECK (carousel_2_media_type IN ('image', 'svga', 'video')),
  CONSTRAINT home_hot_cards_carousel_3_media_check
    CHECK (carousel_3_media_type IN ('image', 'svga', 'video')),
  CONSTRAINT home_hot_cards_party_media_check
    CHECK (party_card_media_type IN ('image', 'svga', 'video')),
  CONSTRAINT home_hot_cards_music_media_check
    CHECK (music_card_media_type IN ('image', 'svga', 'video')),
  CONSTRAINT home_hot_cards_carousel_1_link_check
    CHECK (carousel_1_link IN ('game', 'cp', 'charm')),
  CONSTRAINT home_hot_cards_carousel_2_link_check
    CHECK (carousel_2_link IN ('game', 'cp', 'charm')),
  CONSTRAINT home_hot_cards_carousel_3_link_check
    CHECK (carousel_3_link IN ('game', 'cp', 'charm'))
);

ALTER TABLE public.home_hot_cards_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read home hot cards config" ON public.home_hot_cards_config;
CREATE POLICY "Public read home hot cards config"
  ON public.home_hot_cards_config
  FOR SELECT
  TO public
  USING (true);

INSERT INTO public.home_hot_cards_config (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;
