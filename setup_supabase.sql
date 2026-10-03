-- =====================================================
-- SETUP DATABASE PORTAL UJIAN
-- Jalankan sekali di Supabase: SQL Editor > New query > Run
-- GANTI 'GANTI_PASSWORD_PANITIA' dengan password mode Panitia
-- (harus sama dengan password yang Anda ketik saat masuk Panitia)
-- =====================================================

create extension if not exists pgcrypto with schema extensions;

-- Data portal (jadwal, tombol ujian, kelas, tema) disimpan di sini
create table if not exists public.portal_config (
  id         text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

-- Password panitia (disimpan sebagai hash, tidak bisa dibaca dari web)
create table if not exists public.portal_secret (
  id      text primary key,
  pw_hash text not null
);

alter table public.portal_config enable row level security;
alter table public.portal_secret enable row level security;

-- Siswa/semua orang boleh MEMBACA. Tidak ada policy tulis,
-- jadi data hanya bisa diubah lewat fungsi simpan_portal di bawah.
drop policy if exists "baca publik" on public.portal_config;
create policy "baca publik" on public.portal_config
  for select to anon, authenticated using (true);

-- Isi / ubah password panitia
insert into public.portal_secret (id, pw_hash)
values ('utama', extensions.crypt('GANTI_PASSWORD_PANITIA', extensions.gen_salt('bf')))
on conflict (id) do update set pw_hash = excluded.pw_hash;

-- Fungsi simpan: hanya berhasil kalau password panitia benar
create or replace function public.simpan_portal(p_pw text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (
    select 1 from public.portal_secret
    where id = 'utama' and pw_hash = crypt(p_pw, pw_hash)
  ) then
    raise exception 'password panitia salah' using errcode = '28000';
  end if;

  insert into public.portal_config (id, data, updated_at)
  values ('utama', p_data, now())
  on conflict (id) do update set data = excluded.data, updated_at = now();
end;
$$;

revoke all on function public.simpan_portal(text, jsonb) from public;
grant execute on function public.simpan_portal(text, jsonb) to anon, authenticated;
