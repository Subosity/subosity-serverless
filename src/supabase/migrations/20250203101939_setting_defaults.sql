ALTER TABLE "public"."funding_source"
ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."funding_source"
ALTER COLUMN "created_at" SET DEFAULT NOW();

ALTER TABLE "public"."funding_source"
ALTER COLUMN "updated_at" SET DEFAULT NOW();