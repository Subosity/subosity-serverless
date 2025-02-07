SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

COMMENT ON SCHEMA "public" IS 'standard public schema';

CREATE TYPE "public"."subscription_state" AS ENUM (
    'trial',
    'active',
    'paused',
    'canceled',
    'expired'
);

ALTER TYPE "public"."subscription_state" OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_initial_subscription_history"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO subscription_history (
        subscription_id,
        owner,
        state,
        start_date,
        created_by
    ) VALUES (
        NEW.id,
        NEW.owner,
        NEW.state,
        CURRENT_TIMESTAMP,
        auth.uid()
    );
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."create_initial_subscription_history"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.profiles (user_id, created_at)
    VALUES (NEW.id, NOW());
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."create_profile"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."handle_subscription_state_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Only proceed if state actually changed
    IF OLD.state = NEW.state THEN
        RETURN NEW;
    END IF;

    -- Close the previous state
    UPDATE subscription_history
    SET end_date = CURRENT_TIMESTAMP
    WHERE subscription_id = NEW.id
    AND end_date IS NULL;

    -- Create new state record
    INSERT INTO subscription_history (
        subscription_id,
        owner,
        state,
        start_date,
        created_by
    ) VALUES (
        NEW.id,
        NEW.owner,
        NEW.state,
        CURRENT_TIMESTAMP,
        auth.uid()
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."handle_subscription_state_change"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

CREATE TABLE IF NOT EXISTS "public"."payment_provider" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner" "uuid",
    "name" "text" NOT NULL,
    "description" "text",
    "icon" "text",
    "category" "text" DEFAULT 'Uncategorized'::"text",
    "website" "text",
    "is_default" boolean DEFAULT false,
    "is_public" boolean DEFAULT false,
    "is_pending" boolean DEFAULT true,
    "is_enabled" boolean DEFAULT true
);

ALTER TABLE "public"."payment_provider" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."payment_provider_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_provider_id" "uuid",
    "comment" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."payment_provider_comments" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."preference_system_defaults" (
    "preference_key" "text" NOT NULL,
    "preference_description" "text" NOT NULL,
    "preference_data_type" "text" NOT NULL,
    "available_values" "text"[],
    "preference_value" "text",
    "preference_jsonb" "jsonb" DEFAULT '{}'::"jsonb"
);

ALTER TABLE "public"."preference_system_defaults" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."preferences" (
    "owner" "uuid" NOT NULL,
    "preference_key" "text" NOT NULL,
    "preference_value" "text",
    "preference_jsonb" "jsonb" DEFAULT '{}'::"jsonb"
);

ALTER TABLE "public"."preferences" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."profiles" FORCE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."subscription" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner" "uuid" NOT NULL,
    "subscription_provider_id" "uuid",
    "nickname" "text",
    "start_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "autorenew" boolean DEFAULT false,
    "amount" numeric(10,2),
    "payment_details" "text",
    "notes" "text",
    "state" "public"."subscription_state" DEFAULT 'active'::"public"."subscription_state" NOT NULL,
    "payment_provider_id" "uuid",
    "recurrence_rule" "text",
    "recurrence_rule_ui_friendly" "text"
);

ALTER TABLE "public"."subscription" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."subscription_alerts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subscription_id" "uuid",
    "owner" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "severity" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "sent_at" timestamp without time zone,
    "read_at" timestamp without time zone
);

ALTER TABLE "public"."subscription_alerts" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."subscription_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subscription_id" "uuid",
    "owner" "uuid" NOT NULL,
    "state" "public"."subscription_state" NOT NULL,
    "start_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "end_date" timestamp with time zone,
    "reason" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid" NOT NULL
);

ALTER TABLE "public"."subscription_history" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."subscription_provider" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner" "uuid",
    "name" "text" NOT NULL,
    "description" "text",
    "icon" "text",
    "category" "text" DEFAULT 'Uncategorized'::"text",
    "website" "text",
    "unsubscribe_url" "text",
    "is_default" boolean DEFAULT false,
    "is_public" boolean DEFAULT false,
    "is_pending" boolean DEFAULT true,
    "is_enabled" boolean DEFAULT true
);

ALTER TABLE "public"."subscription_provider" OWNER TO "postgres";

CREATE TABLE IF NOT EXISTS "public"."subscription_provider_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "subscription_provider_id" "uuid",
    "comment" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."subscription_provider_comments" OWNER TO "postgres";

ALTER TABLE ONLY "public"."payment_provider_comments"
    ADD CONSTRAINT "payment_provider_comments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."payment_provider"
    ADD CONSTRAINT "payment_provider_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."preference_system_defaults"
    ADD CONSTRAINT "preference_system_defaults_pkey" PRIMARY KEY ("preference_key");

ALTER TABLE ONLY "public"."preferences"
    ADD CONSTRAINT "preferences_pkey" PRIMARY KEY ("owner", "preference_key");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."subscription_alerts"
    ADD CONSTRAINT "subscription_alerts_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."subscription_history"
    ADD CONSTRAINT "subscription_history_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."subscription"
    ADD CONSTRAINT "subscription_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."subscription_provider_comments"
    ADD CONSTRAINT "subscription_provider_comments_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."subscription_provider"
    ADD CONSTRAINT "subscription_provider_pkey" PRIMARY KEY ("id");

CREATE INDEX "idx_profiles_user_id" ON "public"."profiles" USING "btree" ("user_id");

CREATE INDEX "idx_subscription_history_dates" ON "public"."subscription_history" USING "btree" ("start_date", "end_date");

CREATE INDEX "idx_subscription_history_owner" ON "public"."subscription_history" USING "btree" ("owner");

CREATE INDEX "idx_subscription_history_state" ON "public"."subscription_history" USING "btree" ("state");

CREATE INDEX "idx_subscription_history_subscription_id" ON "public"."subscription_history" USING "btree" ("subscription_id");

CREATE OR REPLACE TRIGGER "create_initial_history" AFTER INSERT ON "public"."subscription" FOR EACH ROW EXECUTE FUNCTION "public"."create_initial_subscription_history"();

CREATE OR REPLACE TRIGGER "handle_state_change" AFTER UPDATE ON "public"."subscription" FOR EACH ROW EXECUTE FUNCTION "public"."handle_subscription_state_change"();

ALTER TABLE ONLY "public"."payment_provider_comments"
    ADD CONSTRAINT "payment_provider_comments_payment_provider_id_fkey" FOREIGN KEY ("payment_provider_id") REFERENCES "public"."payment_provider"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."payment_provider"
    ADD CONSTRAINT "payment_provider_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."preferences"
    ADD CONSTRAINT "preferences_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."preferences"
    ADD CONSTRAINT "preferences_preference_key_fkey" FOREIGN KEY ("preference_key") REFERENCES "public"."preference_system_defaults"("preference_key");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."subscription_alerts"
    ADD CONSTRAINT "subscription_alerts_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."subscription_alerts"
    ADD CONSTRAINT "subscription_alerts_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscription"("id");

ALTER TABLE ONLY "public"."subscription_history"
    ADD CONSTRAINT "subscription_history_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."subscription_history"
    ADD CONSTRAINT "subscription_history_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."subscription_history"
    ADD CONSTRAINT "subscription_history_subscription_id_fkey" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscription"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."subscription"
    ADD CONSTRAINT "subscription_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."subscription"
    ADD CONSTRAINT "subscription_payment_provider_id_fkey" FOREIGN KEY ("payment_provider_id") REFERENCES "public"."payment_provider"("id");

ALTER TABLE ONLY "public"."subscription_provider_comments"
    ADD CONSTRAINT "subscription_provider_comments_subscription_provider_id_fkey" FOREIGN KEY ("subscription_provider_id") REFERENCES "public"."subscription_provider"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."subscription_provider"
    ADD CONSTRAINT "subscription_provider_owner_fkey" FOREIGN KEY ("owner") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."subscription"
    ADD CONSTRAINT "subscription_subscription_provider_id_fkey" FOREIGN KEY ("subscription_provider_id") REFERENCES "public"."subscription_provider"("id");

CREATE POLICY "Allow users to insert their own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));

CREATE POLICY "Allow users to select their own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));

CREATE POLICY "Anyone can view payment provider comments" ON "public"."payment_provider_comments" FOR SELECT USING (true);

CREATE POLICY "Anyone can view subscription provider comments" ON "public"."subscription_provider_comments" FOR SELECT USING (true);

CREATE POLICY "Only admins can delete payment provider comments" ON "public"."payment_provider_comments" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));

CREATE POLICY "Only admins can delete subscription provider comments" ON "public"."subscription_provider_comments" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));

CREATE POLICY "Users can comment on pending payment providers" ON "public"."payment_provider_comments" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."payment_provider"
  WHERE (("payment_provider"."id" = "payment_provider_comments"."payment_provider_id") AND ("payment_provider"."is_pending" = true)))));

CREATE POLICY "Users can comment on pending subscription providers" ON "public"."subscription_provider_comments" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."subscription_provider"
  WHERE (("subscription_provider"."id" = "subscription_provider_comments"."subscription_provider_id") AND ("subscription_provider"."is_pending" = true)))));

CREATE POLICY "Users can delete own payment providers" ON "public"."payment_provider" FOR DELETE USING (("auth"."uid"() = "owner"));

CREATE POLICY "Users can delete own profile" ON "public"."profiles" FOR DELETE USING (("auth"."uid"() = "user_id"));

CREATE POLICY "Users can delete own subscription history" ON "public"."subscription_history" FOR DELETE USING (("owner" = "auth"."uid"()));

CREATE POLICY "Users can insert own payment providers" ON "public"."payment_provider" FOR INSERT WITH CHECK (("auth"."uid"() = "owner"));

CREATE POLICY "Users can insert own subscription history" ON "public"."subscription_history" FOR INSERT WITH CHECK ((("owner" = "auth"."uid"()) AND ("created_by" = "auth"."uid"()) AND ("subscription_id" IN ( SELECT "subscription"."id"
   FROM "public"."subscription"
  WHERE ("subscription"."owner" = "auth"."uid"())))));

CREATE POLICY "Users can update own payment providers" ON "public"."payment_provider" FOR UPDATE USING (("auth"."uid"() = "owner")) WITH CHECK (("auth"."uid"() = "owner"));

CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));

CREATE POLICY "Users can view own payment providers" ON "public"."payment_provider" FOR SELECT USING (("auth"."uid"() = "owner"));

CREATE POLICY "Users can view own subscription history" ON "public"."subscription_history" FOR SELECT USING (("owner" = "auth"."uid"()));

CREATE POLICY "Users can view public payment providers" ON "public"."payment_provider" FOR SELECT USING ((("is_public" = true) OR ("owner" = "auth"."uid"())));

ALTER TABLE "public"."payment_provider" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."payment_provider_comments" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "select_all_profiles" ON "public"."profiles" FOR SELECT USING (("role" = 'admin'::"text"));

CREATE POLICY "select_own_profile" ON "public"."profiles" FOR SELECT USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));

ALTER TABLE "public"."subscription" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."subscription_alerts" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscription_alerts_delete_owned_or_admin_ops" ON "public"."subscription_alerts" FOR DELETE USING ((("owner" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['admin'::"text", 'ops'::"text"])))))));

CREATE POLICY "subscription_alerts_insert_with_owner_or_admin_ops" ON "public"."subscription_alerts" FOR INSERT WITH CHECK ((("owner" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."user_id" = "auth"."uid"()) AND ("profiles"."role" = ANY (ARRAY['admin'::"text", 'ops'::"text"])))))));

CREATE POLICY "subscription_alerts_select_owned" ON "public"."subscription_alerts" FOR SELECT USING (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_alerts_update_owned" ON "public"."subscription_alerts" FOR UPDATE USING (("owner" = "auth"."uid"())) WITH CHECK (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_delete_owned" ON "public"."subscription" FOR DELETE USING (("owner" = "auth"."uid"()));

ALTER TABLE "public"."subscription_history" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscription_insert_with_owner" ON "public"."subscription" FOR INSERT WITH CHECK (("owner" = "auth"."uid"()));

ALTER TABLE "public"."subscription_provider" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."subscription_provider_comments" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscription_provider_delete_owned" ON "public"."subscription_provider" FOR DELETE USING (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_provider_insert_with_owner" ON "public"."subscription_provider" FOR INSERT WITH CHECK (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_provider_select_public_or_owner" ON "public"."subscription_provider" FOR SELECT USING (("is_public" OR ("owner" = "auth"."uid"())));

CREATE POLICY "subscription_provider_update_owned" ON "public"."subscription_provider" FOR UPDATE USING (("owner" = "auth"."uid"())) WITH CHECK (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_select_owned" ON "public"."subscription" FOR SELECT USING (("owner" = "auth"."uid"()));

CREATE POLICY "subscription_update_owned" ON "public"."subscription" FOR UPDATE USING (("owner" = "auth"."uid"())) WITH CHECK (("owner" = "auth"."uid"()));

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

GRANT ALL ON FUNCTION "public"."create_initial_subscription_history"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_initial_subscription_history"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_initial_subscription_history"() TO "service_role";

GRANT ALL ON FUNCTION "public"."create_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_profile"() TO "service_role";

GRANT ALL ON FUNCTION "public"."handle_subscription_state_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_subscription_state_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_subscription_state_change"() TO "service_role";

GRANT ALL ON TABLE "public"."payment_provider" TO "anon";
GRANT ALL ON TABLE "public"."payment_provider" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_provider" TO "service_role";

GRANT ALL ON TABLE "public"."payment_provider_comments" TO "anon";
GRANT ALL ON TABLE "public"."payment_provider_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_provider_comments" TO "service_role";

GRANT ALL ON TABLE "public"."preference_system_defaults" TO "anon";
GRANT ALL ON TABLE "public"."preference_system_defaults" TO "authenticated";
GRANT ALL ON TABLE "public"."preference_system_defaults" TO "service_role";

GRANT ALL ON TABLE "public"."preferences" TO "anon";
GRANT ALL ON TABLE "public"."preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."preferences" TO "service_role";

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";

GRANT ALL ON TABLE "public"."subscription" TO "anon";
GRANT ALL ON TABLE "public"."subscription" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription" TO "service_role";

GRANT ALL ON TABLE "public"."subscription_alerts" TO "anon";
GRANT ALL ON TABLE "public"."subscription_alerts" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_alerts" TO "service_role";

GRANT ALL ON TABLE "public"."subscription_history" TO "anon";
GRANT ALL ON TABLE "public"."subscription_history" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_history" TO "service_role";

GRANT ALL ON TABLE "public"."subscription_provider" TO "anon";
GRANT ALL ON TABLE "public"."subscription_provider" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_provider" TO "service_role";

GRANT ALL ON TABLE "public"."subscription_provider_comments" TO "anon";
GRANT ALL ON TABLE "public"."subscription_provider_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_provider_comments" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";

RESET ALL;
