import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  try {
    console.log("Game Heartbeat Triggered")
    
    // 1. Advance the game rounds
    const { error } = await supabase.rpc('advance_game_rounds')
    
    if (error) throw error

    // 2. We can schedule the next check using a delay or just let pg_cron handle it.
    // For 1-second precision, it's better to use a background worker.
    // But for Supabase, we usually use pg_cron (1 min) or a recursive HTTP call with pg_net.

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})
