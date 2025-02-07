// Import dependencies and initialize services
// --------------------------------------------
// - Import Supabase client and types
// - Import utility functions and types
// - Initialize logger
// - Setup Supabase client with service role key (bypasses RLS)

// Define main handler function
// --------------------------------------------
// export const handler = async (event) => {
//   try {
//     1. Initialize services and constants
//     2. Fetch active subscriptions
//     3. Process each subscription
//     4. Return success response
//   } catch (error) {
//     Handle and log errors
//   }
// }

// Subscription Processing Logic
// --------------------------------------------
// For each subscription:
// 1. Parse RRULE and calculate next renewals
// 2. Check user notification preferences
// 3. Calculate notification dates based on preferences
// 4. Check for existing notifications
// 5. Insert new notifications if needed

// Error Handling and Logging
// --------------------------------------------
// - Log start/end of processing
// - Log any errors with full context
// - Return appropriate HTTP responses
// - Include processing statistics in response

// Types (to be moved to types.ts)
// --------------------------------------------
// interface Subscription {...}
// interface NotificationPreference {...}
// interface NotificationRecord {...}

// TypeScript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";
import { Logger } from '../_shared/logger.ts';
import { fetchActiveSubscriptions } from './src/subscriptions.ts';
import { processNotifications } from './src/notifications.ts';

const logger = new Logger('preprocessNotifications');

Deno.serve((req) => {
  const { pathname } = new URL(req.url);

  // Healthcheck endpoint
  if (pathname.endsWith("/healthcheck")) {
    logger.info('HealthCheck: Verifying health of "preprocess-notifications" service');
    return new Response(JSON.stringify({
      status: "ok",
      service: "preprocess-notifications",
      version: Deno.env.get('FUNCTION_VERSION') || "unknown"
    }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  // Regular processing
  try {
    logger.info('Starting notification preprocessing');

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    return fetchActiveSubscriptions(supabase)
      .then((subscriptions) => processNotifications(supabase, subscriptions))
      .then((processedCount) => {
        logger.info(`Successfully processed ${processedCount} notifications`);
        return new Response(JSON.stringify({ success: true, processed: processedCount }), {
          headers: { 'Content-Type': 'application/json' },
        });
      })
      .catch((error) => {
        logger.error('Failed to process notifications', error as Error);
        return new Response(JSON.stringify({ success: false, error: error.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      });
  } catch (error) {
    logger.error('Failed to process notifications', error as Error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});