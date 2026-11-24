create schema if not exists way;
revoke all on schema way from public, anon, authenticated;
grant usage on schema way to authenticated;
create table way.catalog (
  id integer primary key, title text not null, category text not null, description text not null,
  price numeric(12,2) not null, detail text not null, lat numeric, lng numeric
);
create table way.accounts (uid uuid primary key references auth.users on delete cascade, role text not null check(role in ('demo','admin')));
create table way.profiles (uid uuid references auth.users on delete cascade, space uuid, display_name text not null, primary key(uid,space));
create table way.records (
  id uuid primary key default gen_random_uuid(), owner uuid not null references auth.users on delete cascade,
  space uuid not null, pool uuid not null, item integer references way.catalog, kind text not null,
  status text not null, slot text, payload jsonb not null default '{}', created_at timestamptz not null default now()
);
create unique index on way.records(pool,item,slot) where kind in ('seat','appointment','viewing','assignment') and status <> 'Cancelled';
create unique index on way.records(owner,space,item,kind) where kind in ('favorite','course');
alter table way.catalog enable row level security;
alter table way.accounts enable row level security;
alter table way.profiles enable row level security;
alter table way.records enable row level security;
revoke all on all tables in schema way from public,anon,authenticated;

insert into way.catalog values ('1','Pearl District express','Express','Union Station to the Pearl District.','2.5','09:00','45.5286','-122.6765'),
('2','Waterfront connector','Local','Pioneer Square to Tom McCall Waterfront Park.','2.5','11:30','45.5175','-122.6733'),
('3','Museum loop','Local','Downtown to the Portland Art Museum.','2.5','14:15','45.5163','-122.6832'),
('4','Eastbank evening','Express','Union Station to Eastbank Esplanade.','3','18:45','45.522','-122.665');

create or replace function way.handle(action text, args jsonb, installation uuid)
returns jsonb language plpgsql security definer set search_path='' as $body$
<<handle>>
declare
  uid uuid := auth.uid();
  mode text;
  scope uuid;
  pool_id uuid := '00000000-0000-0000-0000-000000000000';
  product way.catalog%rowtype;
  rec way.records%rowtype;
  target integer;
  slot_key text;
  day date;
  amount numeric := 0;
  qty int;
  line jsonb;
  lines jsonb := '[]';
  info jsonb := '{}';
  label text;
begin
  if uid is null or installation is null then raise exception 'Sign in to continue'; end if;
  select a.role into mode from way.accounts a where a.uid=handle.uid;
  if mode is null and (auth.jwt()->>'email') like '%@demo.mobile.invalid' then raise exception 'Use this app’s demo account'; end if;
  scope := case when mode='demo' then installation else uid end;
  if mode='demo' then if installation=pool_id then raise exception 'Invalid demo installation'; end if; pool_id := installation; end if;
  if action='profile' then
    label := trim(args->>'name');
    if coalesce(length(label),0) not between 1 and 60 then raise exception 'Enter a name of 1–60 characters'; end if;
    insert into way.profiles values(uid,scope,label) on conflict on constraint profiles_pkey do update set display_name=excluded.display_name;
  elsif action='cancel' then
    update way.records r set status='Cancelled' where r.id=(args->>'id')::uuid and r.owner=uid and r.space=scope and r.kind in ('seat','viewing','appointment') and r.status='Confirmed';
    if not found then raise exception 'Reservation no longer available'; end if;
  elsif action not in ('state','availability') then
    
if action='reserve' then
  select * into strict product from way.catalog where id=(args->>'item')::int;
  day := (args->>'day')::date;
  if day is null or day < current_date or day > current_date+30 then raise exception 'Choose a date in the next 30 days'; end if;
  label := args->>'option';
  if label is null or label !~ '^(0[1-9]|1[0-6])$' then raise exception 'Choose a seat'; end if;
  if (day+product.detail::time) at time zone 'America/Los_Angeles' <= now() then raise exception 'This service has departed'; end if;
  slot_key := day::text || ' ' || label;
  insert into way.records(owner,space,pool,item,kind,status,slot,payload) values(uid,scope,pool_id,product.id,'seat','Confirmed',slot_key,jsonb_build_object('day',day,'option',label,'title',product.title));

else raise exception 'Unknown reservation action'; end if;

  end if;
  if action='availability' then
    select coalesce(jsonb_agg(r.slot),'[]') into info from way.records r where r.pool=pool_id and r.item=(args->>'item')::integer and r.status <> 'Cancelled' and r.kind in ('seat','viewing','appointment','assignment');
    return info;
  end if;
  return jsonb_build_object(
    'catalog',(select coalesce(jsonb_agg(to_jsonb(c) order by c.id),'[]') from way.catalog c),
    'records',(select coalesce(jsonb_agg(to_jsonb(r)-'owner'-'space'-'pool' order by r.created_at desc),'[]') from way.records r where (r.owner=uid and r.space=scope) or (mode='admin' and r.pool=pool_id)),
    'name',(select p.display_name from way.profiles p where p.uid=handle.uid and p.space=scope),
    'demo',coalesce(mode='demo',false),'admin',coalesce(mode in ('demo','admin'),false)
  );
exception when unique_violation then raise exception 'Just reserved. Choose another option.';
end $body$;
revoke all on function way.handle(text,jsonb,uuid) from public,anon;
grant execute on function way.handle(text,jsonb,uuid) to authenticated;
create or replace function public.way_workspace(action text,args jsonb,installation uuid)
returns jsonb language sql security invoker set search_path='' as $$
  select way.handle(action,args,installation);
$$;
revoke all on function public.way_workspace(text,jsonb,uuid) from public,anon;
grant execute on function public.way_workspace(text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';

