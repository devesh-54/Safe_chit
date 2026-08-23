# 🗄️ ChitGuard Supabase Database Scripts

This directory contains modular SQL scripts categorized by feature for clean execution in the **Supabase Dashboard → SQL Editor**.

---

## 📁 Modular SQL Files Breakdown

| File Name | Purpose | When to Run |
| :--- | :--- | :--- |
| [`01_user_onboardings.sql`](file:///C:/Users/ashwi/OneDrive/Desktop/python/safechit/Safe_chit/backend/01_user_onboardings.sql) | User Identity, Onboarding Flow, PAN/Aadhaar & Unique Username Index | Initial Setup for User Registrations |
| [`02_foreman_login_seed.sql`](file:///C:/Users/ashwi/OneDrive/Desktop/python/safechit/Safe_chit/backend/02_foreman_login_seed.sql) | Default Foreman Admin Credentials (`foreman_admin` / `foreman123`) | Testing Foreman Login |
| [`03_chit_groups_and_join_requests.sql`](file:///C:/Users/ashwi/OneDrive/Desktop/python/safechit/Safe_chit/backend/03_chit_groups_and_join_requests.sql) | Chit Groups table (with 6-digit Join Code index) & Member Join Requests table | Group Creation & 6-Digit Join Code Flow |
| [`04_waitlist.sql`](file:///C:/Users/ashwi/OneDrive/Desktop/python/safechit/Safe_chit/backend/04_waitlist.sql) | Landing Page Waitlist Phone/Email Capture Table | Landing Page Capture |

---

## 🚀 Execution Instructions:
1. Open your [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **SQL Editor → New Query**.
3. Copy and run the desired feature SQL file above.
