// TypeScript
import { Subscription, NotificationRecord } from './types.ts';
import { Logger } from '../../_shared/logger.ts';

export async function processNotifications(supabase: any, subscriptions: Subscription[]): Promise<number> {
  const logger = new Logger('processNotifications');
  let processedCount = 0;
  
  for (const subscription of subscriptions) {
    // Step 1: Calculate next notification date.
    // For a real implementation, parse the RRULE from subscription.recurrence_rule.
    // For now we'll use the next_bill_date as the base date.
    const nextBillDate = new Date(subscription.next_bill_date);
    
    // Step 2: Check that notification preferences exist.
    if (!subscription.preferences || !subscription.preferences.notification_schedule) {
      logger.info(`Subscription ${subscription.id} missing notification preferences.`);
      continue;
    }
    
    const offsets = subscription.preferences.notification_schedule.offset_days;
    
    // Process each offset as a separate notification date.
    for (const offset of offsets) {
      // Step 3: Calculate alert time.
      const alertTime = new Date(nextBillDate);
      alertTime.setDate(alertTime.getDate() - offset);
      
      // Step 4: Check for an existing notification at the same alert time.
      const { data: existing, error } = await supabase
        .from('notifications')
        .select('id')
        .eq('subscription_id', subscription.id)
        .eq('alert_time', alertTime.toISOString())
        .limit(1)
        .maybeSingle();
      
      if (error) {
        logger.error(`Error checking notifications for subscription ${subscription.id}`, error);
        continue;
      }
      
      if (existing) {
        logger.info(`Notification exists for subscription ${subscription.id} at ${alertTime.toISOString()}`);
        continue;
      }
      
      // Determine notification type.
      let type: 'initial' | 'reminder' | 'final_reminder' = 'reminder';
      if (offset === Math.max(...offsets)) {
        type = 'initial';
      } else if (offset === Math.min(...offsets)) {
        type = 'final_reminder';
      }
      
      // Step 5: Insert a new notification.
      const notification: NotificationRecord = {
        subscription_id: subscription.id,
        alert_time: alertTime,
        type,
        status: 'pending'
      };
      
      const { error: insertError } = await supabase
        .from('notifications')
        .insert({
          subscription_id: notification.subscription_id,
          alert_time: notification.alert_time.toISOString(),
          type: notification.type,
          status: notification.status
        });
      
      if (insertError) {
        logger.error(`Error inserting notification for subscription ${subscription.id}`, insertError);
        continue;
      }
      
      processedCount++;
      logger.info(`Inserted notification for subscription ${subscription.id} at ${alertTime.toISOString()}`);
    }
  }
  
  return processedCount;
}