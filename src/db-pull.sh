#!/bin/bash

echo "[*] Running 'npx supabase db pull'..."

source ./.env
npx supabase db pull --db-url $SUPABASE_DB_URL --debug
