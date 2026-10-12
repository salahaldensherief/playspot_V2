# Permanent catalogue removal without deleting sales history

Dashboard previously used `is_active=false` for both disabling and deleting combos and upsell rules. Reads returned inactive rows, so a deleted item reappeared and could be enabled again.

Migration `20261011133002_canteen_catalogue_deletion_tombstones.sql` adds a nullable server-timestamped `deleted_at`, prevents mutation of archived records, and exposes the authenticated `archive_canteen_catalogue_item(kind,id)` RPC. It checks eligible identity and canonical `menu_manage_items` permission in the item's branch, locks the item, and treats exact repeat archive calls as success without changing the timestamp. Archiving a combo disables related suggestions while retaining all rows and sales references. Client/system direct DELETE grants are revoked.

Dashboard reads must filter `deleted_at IS NULL` and use the archive RPC for delete. Ordinary inactive records stay editable and visible. A successful database migration must precede deployment of that Dashboard change; do not apply it through legacy Dashboard SQL. This migration has only been applied locally, not to the hosted project.

Six native PostgreSQL regression scenarios cover disabled versus archived state, persistence on reload, repeat calls, blocked reactivation, preserved sale references, branch/explicit-deny/inactive/banned/anonymous boundaries, invalid requests, and narrow grants. The migration also compiled successfully against the restored local Supabase schema.
