create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  display_name text not null default 'Customer' check (length(display_name) <= 40),
  password_hash text not null,
  role text not null default 'customer' check (role in ('customer', 'staff', 'admin')),
  reset_token_hash text,
  reset_expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.sessions (
  id uuid primary key,
  user_id uuid not null references public.users on delete cascade,
  expires_at timestamptz not null
);

create table public.profiles (
  user_id uuid primary key references public.users on delete cascade,
  full_name text,
  phone text,
  address text
);

create table public.products (
  id bigint generated always as identity primary key,
  name text not null,
  price_cents int not null check (price_cents >= 0)
);

create table public.reviews (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products,
  author text not null,
  body text not null check (length(body) <= 2000)
);

create table public.orders (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users,
  product_id bigint not null references public.products,
  quantity int not null check (quantity between 1 and 20),
  total_cents int not null check (total_cents >= 0),
  status text not null
);

create table public.uploads (
  name text primary key,
  user_id uuid not null references public.users on delete cascade,
  created_at timestamptz not null default now()
);

create table public.refund_requests (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders,
  user_id uuid not null references public.users,
  reason text not null,
  status text not null check (status in ('pending_review', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

-- The API connects with the owner role and is not subject to these policies.
-- The browser only holds the anon key: RLS is enabled everywhere and only the catalogue is readable.
alter table public.users enable row level security;
alter table public.sessions enable row level security;
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.reviews enable row level security;
alter table public.orders enable row level security;
alter table public.uploads enable row level security;
alter table public.refund_requests enable row level security;

create policy "catalogue is public" on public.products for select to anon, authenticated using (true);
