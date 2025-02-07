INSERT INTO "public"."preference_system_defaults" (
    "preference_key", "preference_description", "preference_data_type", 
    "available_values", "preference_value", "preference_jsonb") 
VALUES (
    'Theme', 'Gets or sets the theme used for this application: Light, Dark, or follow the theme of the current device.', 
    'choice', '{"Auto","Light","Dark"}', 'Auto', '{}');

INSERT INTO "public"."preference_system_defaults" (
    "preference_key", "preference_description", "preference_data_type",
    "available_values", "preference_value", "preference_jsonb")
VALUES (
    'Notifications', 'Notification settings for subscriptions.', 
    'json', null, null, 
    '{"trial": {"schedule": [{"type": "trial_expiring", "channels": ["email", "push"], "offset_days": -7}, {"type": "final_trial_reminder", "channels": ["email", "push", "sms"], "offset_days": -1}]}, "digest": {"rrule": "FREQ=MONTHLY;INTERVAL=1;BYDAY=1FR,3FR", "enabled": true, "channels": ["email"]}, "enabled": true, "schedule": [{"type": "initial", "channels": ["email"], "offset_days": -30}, {"type": "reminder", "channels": ["email"], "offset_days": -14}, {"type": "final_reminder", "channels": ["email", "push"], "offset_days": -7}, {"type": "last_chance", "channels": ["email", "push", "sms"], "offset_days": -1}], "digest_only": true, "quiet_hours": {"end": "07:00", "start": "22:00"}}');