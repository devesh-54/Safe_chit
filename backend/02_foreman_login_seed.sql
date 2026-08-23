-- =================================================================
-- 👑 Feature 2: Default Foreman (Host) Credentials Seed
-- File: backend/02_foreman_login_seed.sql
-- Run in Supabase SQL Editor to insert default foreman_admin user
-- =================================================================

INSERT INTO public.user_onboardings (
    username,
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
    'foreman_admin',
    'host',
    '9876543210',
    TRUE,
    'foreman@chitguard.in',
    TRUE,
    'Rajesh Kumar (Foreman)',
    '1985-05-15',
    'Male',
    'ABCDE1234F',
    '123456789012',
    TRUE,
    '123 Main Market Street',
    'Chennai',
    'Tamil Nadu',
    '600001',
    '987654321098',
    'SBIN0001234',
    TRUE,
    TRUE
)
ON CONFLICT (username) DO NOTHING;
