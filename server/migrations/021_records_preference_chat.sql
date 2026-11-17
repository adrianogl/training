alter table records drop constraint if exists records_kind_check;
alter table records add constraint records_kind_check check (kind in ('race', 'decision', 'goal', 'trainer', 'narrative', 'preference', 'chat'));
