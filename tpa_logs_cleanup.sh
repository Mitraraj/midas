#!/bin/bash

###Please use correct database credential before running.
psql -U postgres -d tpa -p 5438 <<'SQL'
DELETE FROM tpa_logs WHERE created_at < NOW() - INTERVAL '30 days';
VACUUM (FULL, ANALYZE) tpa_logs;
SELECT 
    table_schema,
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_schema) || '.' || quote_ident(table_name))) AS total_size
FROM information_schema.tables
WHERE table_name = 'tpa_logs';
SQL
