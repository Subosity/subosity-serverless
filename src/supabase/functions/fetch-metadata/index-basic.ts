// // supabase/functions/fetch-metadata/index.ts
// import { serve } from 'https://deno.land/x/sift@0.6.0/mod.ts';
// import { DOMParser } from 'https://deno.land/x/deno_dom/deno-dom-wasm.ts';
import { corsHeaders } from '../_shared/cors.js'

console.log(`Function "demo-old" up and running!`)

Deno.serve(async (req) => {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    //const { name } = await req.json()
    const data = {
      message: `Hello there!`
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.log('Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})