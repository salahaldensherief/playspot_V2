BEGIN;

-- Global admin catalogs: keep public/authenticated read policies separate from writes.
DROP POLICY IF EXISTS activity_types_write ON public.activity_types;
CREATE POLICY activity_types_insert
ON public.activity_types FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin());
CREATE POLICY activity_types_update
ON public.activity_types FOR UPDATE TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());
CREATE POLICY activity_types_delete
ON public.activity_types FOR DELETE TO authenticated
USING (public.is_super_admin());

DROP POLICY IF EXISTS categories_write_policy ON public.categories;
CREATE POLICY categories_insert_policy
ON public.categories FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin());
CREATE POLICY categories_update_policy
ON public.categories FOR UPDATE TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());
CREATE POLICY categories_delete_policy
ON public.categories FOR DELETE TO authenticated
USING (public.is_super_admin());

DROP POLICY IF EXISTS cities_write ON public.cities;
CREATE POLICY cities_insert
ON public.cities FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin());
CREATE POLICY cities_update
ON public.cities FOR UPDATE TO authenticated
USING (public.is_super_admin())
WITH CHECK (public.is_super_admin());
CREATE POLICY cities_delete
ON public.cities FOR DELETE TO authenticated
USING (public.is_super_admin());

-- Pricing: use fully-qualified outer-row references to prevent cross-lounge IDs.
DROP POLICY IF EXISTS pricing_rules_write ON public.pricing_rules;

CREATE POLICY pricing_rules_insert
ON public.pricing_rules FOR INSERT TO authenticated
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(pricing_rules.lounge_id,'pricing_manage')
  )
  AND (
    pricing_rules.room_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.rooms AS room_scope
      WHERE room_scope.id = pricing_rules.room_id
        AND room_scope.lounge_id = pricing_rules.lounge_id
    )
  )
  AND (
    pricing_rules.space_type_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.space_types AS st
      WHERE st.id = pricing_rules.space_type_id
    )
  )
);

CREATE POLICY pricing_rules_update
ON public.pricing_rules FOR UPDATE TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(pricing_rules.lounge_id,'pricing_manage')
)
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(pricing_rules.lounge_id,'pricing_manage')
  )
  AND (
    pricing_rules.room_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.rooms AS room_scope
      WHERE room_scope.id = pricing_rules.room_id
        AND room_scope.lounge_id = pricing_rules.lounge_id
    )
  )
  AND (
    pricing_rules.space_type_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.space_types AS st
      WHERE st.id = pricing_rules.space_type_id
    )
  )
);

CREATE POLICY pricing_rules_delete
ON public.pricing_rules FOR DELETE TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(pricing_rules.lounge_id,'pricing_manage')
);

-- Combo components: separate read from mutation policies.
DROP POLICY IF EXISTS canteen_combo_items_write ON public.canteen_combo_items;

CREATE POLICY canteen_combo_items_insert
ON public.canteen_combo_items FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    JOIN public.extras AS e
      ON e.id = canteen_combo_items.extra_id
    WHERE c.id = canteen_combo_items.combo_id
      AND e.lounge_id = c.lounge_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
);

CREATE POLICY canteen_combo_items_update
ON public.canteen_combo_items FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    WHERE c.id = canteen_combo_items.combo_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    JOIN public.extras AS e
      ON e.id = canteen_combo_items.extra_id
    WHERE c.id = canteen_combo_items.combo_id
      AND e.lounge_id = c.lounge_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
);

CREATE POLICY canteen_combo_items_delete
ON public.canteen_combo_items FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.canteen_combos AS c
    WHERE c.id = canteen_combo_items.combo_id
      AND (
        public.is_super_admin()
        OR public.has_lounge_permission(c.lounge_id,'menu_manage_items')
      )
  )
);

-- Upsell: qualify outer lounge_id so suggested items cannot cross lounge boundaries.
DROP POLICY IF EXISTS upsell_rules_write ON public.upsell_rules;

CREATE POLICY upsell_rules_insert
ON public.upsell_rules FOR INSERT TO authenticated
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(upsell_rules.lounge_id,'menu_manage_items')
  )
  AND (
    upsell_rules.suggest_extra_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.extras AS extra_scope
      WHERE extra_scope.id = upsell_rules.suggest_extra_id
        AND extra_scope.lounge_id = upsell_rules.lounge_id
    )
  )
  AND (
    upsell_rules.suggest_combo_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.canteen_combos AS combo_scope
      WHERE combo_scope.id = upsell_rules.suggest_combo_id
        AND combo_scope.lounge_id = upsell_rules.lounge_id
    )
  )
);

CREATE POLICY upsell_rules_update
ON public.upsell_rules FOR UPDATE TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(upsell_rules.lounge_id,'menu_manage_items')
)
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(upsell_rules.lounge_id,'menu_manage_items')
  )
  AND (
    upsell_rules.suggest_extra_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.extras AS extra_scope
      WHERE extra_scope.id = upsell_rules.suggest_extra_id
        AND extra_scope.lounge_id = upsell_rules.lounge_id
    )
  )
  AND (
    upsell_rules.suggest_combo_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.canteen_combos AS combo_scope
      WHERE combo_scope.id = upsell_rules.suggest_combo_id
        AND combo_scope.lounge_id = upsell_rules.lounge_id
    )
  )
);

CREATE POLICY upsell_rules_delete
ON public.upsell_rules FOR DELETE TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(upsell_rules.lounge_id,'menu_manage_items')
);

COMMIT;
