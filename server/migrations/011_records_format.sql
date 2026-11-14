alter table records add column format text not null default 'sealed' check (format in ('sealed', 'plain'));
