#!/bin/bash

echo "[*] Running 'npx supabase db push'..."

source ./.env
npx supabase db push --db-url $SUPABASE_DB_URL --debug
