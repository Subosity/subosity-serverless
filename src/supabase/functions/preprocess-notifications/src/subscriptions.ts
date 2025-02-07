// TypeScript
//import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";
import { Logger } from '../../_shared/logger.ts';
import { Subscription } from './types.ts';
import { getNextOccurrence } from './recurrenceUtils.ts';

export async function fetchActiveSubscriptions(supabase: any) {
  const logger = new Logger('fetchActiveSubscriptions');
  
  try {
    logger.info('Fetching active subscriptions');
    
    const { data, error } = await supabase
      .from('subscriptions')
      .select(`
        id,
        user_id,
        recurrence_rule,
        preferences
      `)

    if (error) throw error;
    
    logger.info(`Found ${data.length} active subscriptions`);

    // For each subscription, calculate the next occurrence using the recurrence_rule.
    const subscriptions = data.map((subscription: any) => {
      const nextOccurrence = getNextOccurrence(subscription.recurrence_rule);
      return {
        ...subscription,
        // Reassign next_bill_date to nextOccurrence for backward compatibility in processing.
        next_bill_date: nextOccurrence,
      } as Subscription;
    });
    
    return subscriptions;
  } catch (error) {
    logger.error('Failed to fetch subscriptions', error as Error);
    throw error;
  }
}