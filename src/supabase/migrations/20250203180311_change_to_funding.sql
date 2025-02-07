DO $$
DECLARE
    notice text;
    log_messages text[] := ARRAY[]::text[];
BEGIN

BEGIN
    log_messages := array_append(log_messages, 'Starting subscription funding source migration...');
    
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'funding_source') THEN
        RAISE EXCEPTION 'Required table funding_source does not exist. Please run the funding_source migration first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'subscription' 
        AND column_name = 'payment_provider_id'
    ) THEN
        log_messages := array_append(log_messages, 'Migration already applied - payment_provider_id column does not exist');
        RAISE INFO '%', array_to_string(log_messages, E'\n');
        RETURN;
    END IF;

    -- Store counts for logging
    WITH counts AS (
        SELECT 
            (SELECT COUNT(*) FROM public.subscription_history) as history_count,
            (SELECT COUNT(*) FROM public.subscription_alerts) as alerts_count,
            (SELECT COUNT(*) FROM public.subscription) as subs_count
    )
    SELECT 
        format('Will delete: %s history records, %s alerts, %s subscriptions', 
            history_count, alerts_count, subs_count)
    FROM counts
    INTO notice;
    
    log_messages := array_append(log_messages, notice);

    BEGIN
        DELETE FROM public.subscription_history;
        DELETE FROM public.subscription_alerts;
        DELETE FROM public.subscription;
        log_messages := array_append(log_messages, 'Removed dependent records successfully');

        ALTER TABLE public.subscription 
        DROP CONSTRAINT IF EXISTS subscription_payment_provider_id_fkey;
        log_messages := array_append(log_messages, 'Dropped foreign key constraint');

        ALTER TABLE public.subscription
        DROP COLUMN IF EXISTS payment_provider_id,
        DROP COLUMN IF EXISTS payment_details;
        log_messages := array_append(log_messages, 'Dropped old columns');

        IF NOT EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'subscription' 
            AND column_name = 'funding_source_id'
        ) THEN
            ALTER TABLE public.subscription
            ADD COLUMN funding_source_id uuid REFERENCES public.funding_source(id);
            log_messages := array_append(log_messages, 'Added new funding_source_id column');
        END IF;

        log_messages := array_append(log_messages, 'Migration completed successfully');
        
    EXCEPTION WHEN OTHERS THEN
        log_messages := array_append(log_messages, 'Error during migration steps: ' || SQLERRM);
        RAISE INFO '%', array_to_string(log_messages, E'\n');
        RAISE;
    END;

EXCEPTION WHEN OTHERS THEN
    log_messages := array_append(log_messages, 'Migration failed: ' || SQLERRM);
    RAISE INFO '%', array_to_string(log_messages, E'\n');
    RAISE;
END;

-- Output all messages at the end
RAISE INFO E'\n=== Migration Log ===\n%\n==================', array_to_string(log_messages, E'\n');

END $$;