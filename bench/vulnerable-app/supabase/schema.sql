create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  password_hash text not null,
  role text not null default 'customer',
  reset_token text,
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
  body text not null
);

create table public.orders (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users,
  product_id bigint not null references public.products,
  quantity int not null,
  total_cents int not null,
  status text not null
);

alter table public.products enable row level security;
create policy "catalogue is public" on public.products for select using (true);

alter table public.profiles enable row level security;
create policy "profiles are readable" on public.profiles for select using (true);
create policy "profiles are editable" on public.profiles for update using (true);
