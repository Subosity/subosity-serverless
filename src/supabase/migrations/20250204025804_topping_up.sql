alter table "public"."funding_source" add column "funding_type" text default 'Credit Card'::text;

alter table "public"."preference_system_defaults" enable row level security;

alter table "public"."preferences" enable row level security;

create policy "Enable read access for all users"
on "public"."preference_system_defaults"
as permissive
for select
to public
using (true);


create policy "Enable delete for users based on user_id"
on "public"."preferences"
as permissive
for delete
to public
using ((( SELECT auth.uid() AS uid) = owner));


create policy "Enable insert for authenticated users only"
on "public"."preferences"
as permissive
for insert
to authenticated
with check (true);


create policy "Enable updates for users own records"
on "public"."preferences"
as permissive
for update
to public
using ((( SELECT auth.uid() AS uid) = owner))
with check ((( SELECT auth.uid() AS uid) = owner));


create policy "Enable users to view their own data only"
on "public"."preferences"
as permissive
for select
to authenticated
using ((( SELECT auth.uid() AS uid) = owner));