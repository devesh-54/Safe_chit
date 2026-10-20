-- =================================================================
-- 👤 Feature 6: Default Subscriber (Member) Credentials Seed
-- File: backend/06_member_login_seed.sql
-- Run in Supabase SQL Editor to insert default member_demo user
-- =================================================================

INSERT INTO public.user_onboardings (
    username,
    password,
    role,
    mobile_number,
    is_mobile_verified,
    email,
    is_email_verified,
    full_name,
    date_of_birth,
    gender,
    pan_number,
    aadhaar_number,
    is_gov_id_verified,
    perm_address,
    perm_city,
    perm_state,
    perm_pin_code,
    bank_account_number,
    bank_ifsc,
    is_bank_verified,
    has_consented
) VALUES (
    'member_demo',
    'member123',
    'member',
    '9876512345',
    TRUE,
    'suresh.raina@chitguard.in',
    TRUE,
    'Suresh Raina (Subscriber)',
    '1990-08-20',
    'Male',
    'XYZPR5678K',
    '987654321099',
    TRUE,
    '456 Indiranagar 100ft Road',
    'Bengaluru',
    'Karnataka',
    '560038',
    '123456789012',
    'HDFC0001234',
    TRUE,
    TRUE
)
ON CONFLICT (username) DO NOTHING;
