-- Migration for user_tokens table (per funzione send-push-notification)
create table if not exists public.user_tokens (
  user_id uuid references auth.users(id) on delete cascade,
  fcm_token text not null,
  updated_at timestamp with time zone default now(),
  primary key (user_id, fcm_token)
);
