-- ginzburg_food.payment

create or replace function ginzburg_food.check_payment_amount()
returns trigger
language plpgsql
as $$
declare
    v_total_amount numeric(10,2);
begin
    select o.total_amount
    into v_total_amount
    from ginzburg_food."order" o
    where o.order_id = new.order_id;

    if v_total_amount is distinct from new.amount then
        raise exception 'Payment amount must equal order total amount';
    end if;

    return new;
end;
$$;

create or replace trigger payment_amount_check
before insert or update of order_id, amount
on ginzburg_food.payment
for each row
execute function ginzburg_food.check_payment_amount();

-- ginzburg_food.order_structure

create or replace function ginzburg_food.increase_product_quantity()
returns trigger
language plpgsql
as $$
begin
    if new.quantity <= 0 then
        raise exception 'Order structure quantity must be greater than zero';
    end if;

    update ginzburg_food.order_structure
    set quantity = quantity + new.quantity
    where order_id = new.order_id
      and product_id = new.product_id;

    if found then
        return null;
    end if;

    return new;
end;
$$;

create or replace trigger order_structure_merge
before insert
on ginzburg_food.order_structure
for each row
execute function ginzburg_food.increase_product_quantity();

-- ginzburg_food.review

create or replace function ginzburg_food.rating_change()
returns trigger
language plpgsql
as $$
begin
    if tg_op in ('DELETE', 'UPDATE') then
        if old.entity_type = 'блюдо' then
            update ginzburg_food.product
            set rating = (
                select round(avg(r.rating), 2)
                from ginzburg_food.review r
                where r.entity_type = 'блюдо'
                  and r.entity_id = old.entity_id
            )
            where product_id = old.entity_id;
        elsif old.entity_type = 'ресторан' then
            update ginzburg_food.restaurant
            set rating = (
                select round(avg(r.rating), 2)
                from ginzburg_food.review r
                where r.entity_type = 'ресторан'
                  and r.entity_id = old.entity_id
            )
            where restaurant_id = old.entity_id;
        end if;
    end if;

    if tg_op in ('INSERT', 'UPDATE') then
        if new.entity_type = 'блюдо' then
            update ginzburg_food.product
            set rating = (
                select round(avg(r.rating), 2)
                from ginzburg_food.review r
                where r.entity_type = 'блюдо'
                  and r.entity_id = new.entity_id
            )
            where product_id = new.entity_id;
        elsif new.entity_type = 'ресторан' then
            update ginzburg_food.restaurant
            set rating = (
                select round(avg(r.rating), 2)
                from ginzburg_food.review r
                where r.entity_type = 'ресторан'
                  and r.entity_id = new.entity_id
            )
            where restaurant_id = new.entity_id;
        end if;
    end if;

    return null;
end;
$$;

create or replace trigger review_rating_change
after insert or update or delete
on ginzburg_food.review
for each row
execute function ginzburg_food.rating_change();
