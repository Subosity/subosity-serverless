export interface Subscription {
    id: string;
    user_id: string;
    recurrence_rule: string;
    next_bill_date: Date;
    preferences: {
        notification_schedule: {
            offset_days: number[];
        };
    };
}

export interface NotificationRecord {
    subscription_id: string;
    alert_time: Date;
    type: 'initial' | 'reminder' | 'final_reminder';
    status: 'pending' | 'processed';
}