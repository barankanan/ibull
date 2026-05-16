-- after  
if auth.uid() <> p_restaurant_id then
    -- also pass if caller is an active waiter in store_sub_admins
    if not exists (SELECT 1 FROM store_sub_admins sa
                   JOIN users u ON lower(trim(u.email)) = lower(trim(sa.email))
                   WHERE sa.store_id = p_restaurant_id
                     AND u.id = auth.uid()
                     AND sa.status = 'active') then
        raise exception 'Bu restoran için işlem yetkiniz yok.'
    end if;
end if;