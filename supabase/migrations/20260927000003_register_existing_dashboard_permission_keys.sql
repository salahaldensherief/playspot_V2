BEGIN;
SET LOCAL lock_timeout='5s';
INSERT INTO public.app_permissions(key,name_ar,name_en,category,description_ar,description_en,default_super_admin,default_owner,default_cashier) VALUES
('menu_view','عرض المنيو والأصناف','View Menu & Items','menu','عرض المنيو والأصناف','View Menu & Items',true,true,true),
('extras_update_stock','تعديل كميات المخزون','Update Stock Quantities','menu','تعديل كميات المخزون','Update Stock Quantities',true,true,true),
('shifts_view','عرض سجل الورديات','View Shift History','shifts','عرض سجل الورديات','View Shift History',true,true,false),
('marketing_manage','إدارة التسويق والعروض','Manage Marketing','marketing','إدارة التسويق والعروض','Manage Marketing',true,true,false),
('lounge_toggle_status','تغيير حالة التشغيل','Toggle Open/Closed Status','lounges','تغيير حالة التشغيل','Toggle Open/Closed Status',true,true,true),
('reviews_view','عرض تقييمات العملاء','View Customer Reviews','reviews','عرض تقييمات العملاء','View Customer Reviews',true,true,false),
('tournaments_view','عرض البطولات','View Tournaments','tournaments','عرض البطولات','View Tournaments',true,true,false)
ON CONFLICT (key) DO NOTHING;
COMMIT;
