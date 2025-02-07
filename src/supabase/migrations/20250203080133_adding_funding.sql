CREATE TABLE "public"."funding_source" (
    "id" uuid PRIMARY KEY NOT NULL,
    "name" text NOT NULL,
    "description" text NOT NULL DEFAULT '',
    "notes" text,
    "payment_provider_id" UUID NOT NULL REFERENCES "public"."payment_provider" ("id"),
    "owner" UUID NOT NULL REFERENCES auth.users(id),
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL
);

-- Enable RLS on the funding_source table
ALTER TABLE "public"."funding_source" ENABLE ROW LEVEL SECURITY;

-- Create policy to allow owners to view their own records
CREATE POLICY "Allow owners to view their own records"
    ON "public"."funding_source"
    FOR SELECT
    USING ("owner" = auth.uid());

-- Create policy to allow owners to insert their own records
CREATE POLICY "Allow owners to insert their own records"
    ON "public"."funding_source"
    FOR INSERT
    WITH CHECK ("owner" = auth.uid());

-- Create policy to allow owners to update their own records
CREATE POLICY "Allow owners to update their own records"
    ON "public"."funding_source"
    FOR UPDATE
    USING ("owner" = auth.uid());

-- Create policy to allow owners to delete their own records
CREATE POLICY "Allow owners to delete their own records"
    ON "public"."funding_source"
    FOR DELETE
    USING ("owner" = auth.uid());

-- Apply the policies
ALTER TABLE "public"."funding_source" FORCE ROW LEVEL SECURITY;
