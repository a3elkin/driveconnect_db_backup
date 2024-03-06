--
-- PostgreSQL database dump
--

-- Dumped from database version 11.5 (Debian 11.5-1.pgdg90+1)
-- Dumped by pg_dump version 16.0

-- Started on 2024-03-06 18:09:06

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 14 (class 2615 OID 16407)
-- Name: aggregator_api; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA aggregator_api;


ALTER SCHEMA aggregator_api OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 16408)
-- Name: api; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA api;


ALTER SCHEMA api OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 16409)
-- Name: assignment; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA assignment;


ALTER SCHEMA assignment OWNER TO postgres;

--
-- TOC entry 12 (class 2615 OID 16410)
-- Name: data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA data;


ALTER SCHEMA data OWNER TO postgres;

--
-- TOC entry 4817 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA data; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA data IS 'only data ';


--
-- TOC entry 13 (class 2615 OID 16412)
-- Name: sysdata; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA sysdata;


ALTER SCHEMA sysdata OWNER TO postgres;

--
-- TOC entry 17 (class 2615 OID 16413)
-- Name: winapp; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA winapp;


ALTER SCHEMA winapp OWNER TO postgres;

--
-- TOC entry 482 (class 1255 OID 16451)
-- Name: add_bad_ga_by_client_token(integer, text, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.add_bad_ga_by_client_token(client_id_ integer, token_ text, address_ text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается через API по токену клиента.
Добавление плохого адреса.
*/
DECLARE address_id bigint default -1;
BEGIN

if token_ <> (select cl.token from data.clients cl where cl.id=client_id_) then
 return -1;
end if;

insert into data.google_addresses(id,client_id,address)
        values(nextval('data.google_addresses_id_seq'),client_id_,trim(address_))
  	    on conflict do nothing																		   
		returning id into address_id;

return coalesce(address_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
END

$$;


ALTER FUNCTION aggregator_api.add_bad_ga_by_client_token(client_id_ integer, token_ text, address_ text) OWNER TO postgres;

--
-- TOC entry 490 (class 1255 OID 16452)
-- Name: add_driver_device(integer, text, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.add_driver_device(driver_id_ integer, device_id_ text, device_name_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Добавление девайса водителя.
Если такой девайс уже есть, то не добавляет.Возвращает id записи.
*/

DECLARE record_id integer default 0;

begin

select d.id from data.driver_devices d where d.driver_id=driver_id_ and d.device_id=UPPER(device_id_) 
 INTO record_id;

if coalesce(record_id,0)>0 then 
 return record_id;
end if;

insert into data.driver_devices(id,driver_id,device_id,device_name,add_datetime) 
values(nextval('data.driver_devices_id_seq'),driver_id_,UPPER(device_id_),device_name_,CURRENT_TIMESTAMP)
on conflict do nothing
returning id into record_id;

return record_id;

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;

end

$$;


ALTER FUNCTION aggregator_api.add_driver_device(driver_id_ integer, device_id_ text, device_name_ text) OWNER TO postgres;

--
-- TOC entry 491 (class 1255 OID 16453)
-- Name: add_ga_by_client_token(integer, text, text, text, numeric, numeric); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.add_ga_by_client_token(client_id_ integer, token_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается через API по токену клиента.
Добавление гугл-адреса.
*/

BEGIN

address_id = -1; 
original_id = NULL;

if token_ <> (select cl.token from data.clients cl where cl.id=client_id_) then
 return;
end if;

if not exists(select 1 from data.google_addresses ga where ga.client_id=client_id_ and trim(upper(ga.address))=trim(upper(address_))) then
 begin							
    select gor.id from data.google_originals gor where upper(google_address_)=upper(gor.address)
	into original_id;

	if original_id is null then
      insert into data.google_originals(id,address,latitude,longitude)
 	  values(nextval('data.google_originals_id_seq'),google_address_,latitude_,longitude_)
	  on conflict do nothing																		   
	  returning id into original_id;
    end if;		
																				   
	if original_id is null then
		return;
	else
      insert into data.google_addresses(id,client_id,address,google_original)
	              values(nextval('data.google_addresses_id_seq'),client_id_,trim(address_),original_id)
		  		  returning id into address_id;
     end if;
 end;
else
	select ga.id,ga.google_original from data.google_addresses ga where ga.client_id=client_id_ and trim(upper(ga.address))=trim(upper(address_)) 
	into address_id, original_id;
end if;

address_id = coalesce(address_id,-1);

RETURN;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
END

$$;


ALTER FUNCTION aggregator_api.add_ga_by_client_token(client_id_ integer, token_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) OWNER TO postgres;

--
-- TOC entry 492 (class 1255 OID 16454)
-- Name: available_pay(integer, text, integer, integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.available_pay(dispatcher_id_ integer, token_ text, driver_id_ integer, days_without_pay_ integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается агрегатором.
Просмотр возможного платежа для водителя по токену диспетчера.
*/

DECLARE available_sum numeric default 0;
DECLARE rest_sum numeric;
DECLARE bdate timestamp without time zone;
DECLARE bsum numeric;
DECLARE docs jsonb[] DEFAULT NULL;
DECLARE dsum numeric;
DECLARE curr_date date;
BEGIN

if not exists(select d.id from data.dispatchers d where d.id=dispatcher_id_ and d.token=token_) then 
 return '{}'::jsonb;
end if; 
if coalesce((select d.dispatcher_id from data.drivers d where d.id=driver_id_),0)<>dispatcher_id_ then
 return '{}'::jsonb;
end if;

curr_date = CURRENT_TIMESTAMP::date;
available_sum = coalesce((SELECT sum(summa) FROM data.orders o where o.driver_id=driver_id_ and o.status_id>=120 and (curr_date - coalesce(o.doc_date,o.from_time::date))>days_without_pay_),0)
              - coalesce((SELECT sum(oc.summa) FROM data.order_costs oc left join data.orders o on oc.order_id=o.id where o.driver_id=driver_id_ and (curr_date - coalesce(o.doc_date,o.from_time::date))>days_without_pay_),0)
			  - coalesce((SELECT sum(summa) FROM data.feedback f where f.driver_id=driver_id_ and not f.paid is null and not coalesce(f.is_deleted,false)),0)
			  + coalesce((SELECT sum(summa) FROM data.addsums a where a.driver_id=driver_id_ and a.summa>0  and not coalesce(a.is_deleted,false) and (curr_date - a.operdate::date)>days_without_pay_),0)
			  + coalesce((SELECT sum(summa) FROM data.addsums a where a.driver_id=driver_id_ and a.summa<0  and not coalesce(a.is_deleted,false) and (curr_date - a.operdate::date)>days_without_pay_),0);

rest_sum = available_sum;

 
for bdate,bsum in 
 with bs as
 (
   select balance.doc_date b_date, sum(balance.summa) b_sum from (
     select coalesce(o.doc_date,o.from_time::date) doc_date, o.summa from data.orders o where o.driver_id=driver_id_ and o.status_id>=120 and (curr_date - coalesce(o.doc_date,o.from_time::date))>days_without_pay_
      union all
     select coalesce(o.doc_date,o.from_time::date) doc_date, oc.summa from data.order_costs oc left join data.orders o on oc.order_id=o.id left join data.cost_types ct on ct.id=oc.cost_id where o.driver_id=driver_id_ and (curr_date - coalesce(o.doc_date,o.from_time::date))>days_without_pay_
      union all
--     select f.paid::date doc_date, f.summa from data.feedback f where f.driver_id=driver_id_ and not f.paid is null and not coalesce(f.is_deleted,false)
--      union all
     select p.operdate::date doc_date, p.summa from data.addsums p where p.driver_id=driver_id_ and p.summa>0 and not coalesce(p.is_deleted,false) and (curr_date - p.operdate::date)>days_without_pay_
      union all
     select m.operdate::date doc_date, m.summa from data.addsums m where m.driver_id=driver_id_ and m.summa<0 and not coalesce(m.is_deleted,false) and (curr_date - m.operdate::date)>days_without_pay_
     	) as balance group by b_date order by b_date
  ) 
 select bs.b_date, bs.b_sum from bs order by 1 desc
  loop
  
   if rest_sum>0 then

      if bsum>rest_sum then
	   dsum = rest_sum;
	  else
	   dsum = bsum;
	  end if; 
	
      if docs is null then
	   docs = ARRAY[jsonb_build_object('date', bdate::date) || jsonb_build_object('sum', dsum)];
	  else 
	   docs = array_append(docs,jsonb_build_object('date', bdate::date) || jsonb_build_object('sum', dsum));
	  end if;
    rest_sum = rest_sum - bsum;
   end if;   
  end loop;

  RETURN jsonb_build_object('availableSum', available_sum) || jsonb_build_object('dates', docs);
END

$$;


ALTER FUNCTION aggregator_api.available_pay(dispatcher_id_ integer, token_ text, driver_id_ integer, days_without_pay_ integer) OWNER TO postgres;

--
-- TOC entry 493 (class 1255 OID 16455)
-- Name: calc_commission(date, numeric, numeric); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.calc_commission(date_ date, latitude_ numeric, longitude_ numeric, OUT stavka numeric, OUT name text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE addkoeff NUMERIC default null;

begin

select ac.name,ac.percent from data.agg_commission ac 
 where ac.begin_date=(select max(ac2.begin_date) from data.agg_commission ac2 where ac2.begin_date<=date_)
 into name,stavka;

name = coalesce(name,'');
stavka = coalesce(stavka,0);

select max(ar.koeff) from data.agg_regions ar
 where point(latitude_,longitude_) <@ ar.region 
 into addkoeff;

stavka = (stavka * coalesce(addkoeff,1))::numeric(12,2) ;

return;

--EXCEPTION
--WHEN OTHERS THEN 
--  RETURN;
end

$$;


ALTER FUNCTION aggregator_api.calc_commission(date_ date, latitude_ numeric, longitude_ numeric, OUT stavka numeric, OUT name text) OWNER TO postgres;

--
-- TOC entry 494 (class 1255 OID 16456)
-- Name: change_active_region(integer, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.change_active_region(region_id_ integer, region_active_ boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Изменение активности региона.
Возвращает boolean.
*/
begin

update data.agg_regions set is_active=region_active_ where id=region_id_;	   
 
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
  
end

$$;


ALTER FUNCTION aggregator_api.change_active_region(region_id_ integer, region_active_ boolean) OWNER TO postgres;

--
-- TOC entry 495 (class 1255 OID 16457)
-- Name: create_driver(character varying, character varying, character varying, character varying, character varying, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.create_driver(driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_contact_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Добавление водителя.
Возвращает либо id, либо -1.
*/
DECLARE driver_id integer default -1;

begin

  insert into data.drivers (id,login,name,second_name,family_name,pass,is_active,level_id,dispatcher_id,contact)
         values (nextval('data.drivers_id_seq'),driver_login_,driver_name_,driver_second_name_,driver_family_name_,driver_pass_,true,1,null,driver_contact_) 
		 returning id into driver_id;

return coalesce(driver_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.create_driver(driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_contact_ text) OWNER TO postgres;

--
-- TOC entry 496 (class 1255 OID 16458)
-- Name: create_feedback(integer, text, integer, integer, timestamp without time zone, real, date, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.create_feedback(dispatcher_id_ integer, token_ text, driver_id_ integer, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, paid_ date, commentary_ text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается через API диспетчера.
Добавление платежа.
Возвращает либо id, либо -1.
*/

DECLARE fact_feedback_id bigint default 0;
DECLARE action_text text;

begin

if not exists(select d.id from data.dispatchers d where d.id=dispatcher_id_ and d.token=token_) then 
 return -1;
end if;

if coalesce((select d.dispatcher_id from data.drivers d where d.id=driver_id_),0)<>dispatcher_id_ then
 return -1;
end if;

/* Создание*/
action_text = 'Create API';
	
insert into data.feedback(id,dispatcher_id,driver_id,opernumber,operdate,summa,paid,commentary)
values(nextval('data.feedback_id_seq'),dispatcher_id_,driver_id_,opernumber_,operdate_,summa_,paid_,commentary_)
returning id into fact_feedback_id;

insert into data.finances_log(id,payment_id,dispatcher_id,datetime,action_string)
values (nextval('data.finances_log_id_seq'),fact_feedback_id,dispatcher_id_,CURRENT_TIMESTAMP,action_text) 
on conflict do nothing;

return fact_feedback_id;

end

$$;


ALTER FUNCTION aggregator_api.create_feedback(dispatcher_id_ integer, token_ text, driver_id_ integer, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, paid_ date, commentary_ text) OWNER TO postgres;

--
-- TOC entry 497 (class 1255 OID 16459)
-- Name: create_order(integer, character varying, character varying, character varying, numeric, numeric, timestamp without time zone, character varying, character varying, character varying, numeric, numeric, integer, integer, integer, real, integer, character varying, jsonb); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.create_order(client_id_ integer, client_code_ character varying, order_title_ character varying, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, client_summa_ numeric, driver_summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, checkpoints_ jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается через API агрегатора.
Создание нового заказа. Статус - 10 или 20.
Возвращает либо id, либо -1.
*/

DECLARE nw_order_id bigint default -1;
DECLARE checkpoints_count integer;

declare ch_to_addr_name text;
declare ch_to_addr_latitude real;
declare ch_to_addr_longitude real;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;
declare ch_distance_to real;
declare ch_duration_to integer;
declare ch_to_time_to timestamp without time zone;

declare calc_status_id integer default 0;
declare calc_free_sum boolean default false;

declare route_checkpoint_duration integer default 0;
declare route_load_duration integer default 0;

begin

if client_summa_>0 then
 begin
  calc_status_id = 20;
  calc_free_sum = true;
 end; 
else
 begin
  calc_status_id = 10;
  calc_free_sum = false;
 end;
end if;

 checkpoints_count = jsonb_array_length(checkpoints_);
  

 insert into data.orders (id,order_time,order_title,from_addr_name,from_addr_latitude,from_addr_longitude,from_time,from_kontakt_name,from_kontakt_phone,from_notes,summa,client_summa,driver_id,dispatcher_id,client_dispatcher_id,client_id,client_code,status_id,carclass_id,hours,distance,duration,duration_calc,visible,notes,free_sum)
         values (nextval('data.orders_id_seq'),CURRENT_TIMESTAMP,order_title_,from_addr_name_,from_addr_latitude_,from_addr_longitude_,from_time_,from_kontakt_name_,from_kontakt_phone_,from_notes_,driver_summa_,client_summa_,null,dispatcher_id_,dispatcher_id_,client_id_,client_code_,calc_status_id,carclass_id_,hours_,distance_,duration_,(duration_+checkpoints_count*route_checkpoint_duration+route_load_duration),true,notes_,calc_free_sum) 
		 returning id into nw_order_id;

  /* add history */
  insert into data.order_history (id,client_id,order_title,from_name,summa,latitude,longitude) 
		  values (nextval('data.order_history_id_seq'),client_id_,order_title_,from_addr_name_,summa_,from_addr_latitude_,from_addr_longitude_) 
          on conflict do nothing;

  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_addr_name = cast(checkpoints_->i->>'address' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'latitude' as real);
    ch_to_addr_longitude = cast(checkpoints_->i->>'longitude' as real);
    ch_kontakt_name = cast(checkpoints_->i->>'contact' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'phone' as text);
    ch_notes = cast(checkpoints_->i->>'notes' as text);
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);

    insert into data.checkpoints (id,order_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),nw_order_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 ch_distance_to,
			 ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

insert into data.order_log(id,order_id,client_id,datetime,status_new,action_string)
values (nextval('data.order_log_id_seq'),nw_order_id,client_id_,CURRENT_TIMESTAMP,calc_status_id,'Create') 
on conflict do nothing;

return coalesce(nw_order_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.create_order(client_id_ integer, client_code_ character varying, order_title_ character varying, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, client_summa_ numeric, driver_summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, checkpoints_ jsonb) OWNER TO postgres;

--
-- TOC entry 498 (class 1255 OID 16460)
-- Name: create_order_by_client_token(integer, text, character varying, integer, character varying, numeric, numeric, timestamp without time zone, date, character varying, character varying, character varying, numeric, integer, integer, integer, real, integer, character varying, numeric, jsonb, boolean, character varying); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.create_order_by_client_token(client_id_ integer, token_ text, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, pallets_count_ numeric, checkpoints_ jsonb, draft boolean, client_code_ character varying) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается через API агрегатора.
Создание нового заказа. Статус - 20/30.
Возвращает либо id, либо -1.
*/

DECLARE create_time timestamp without time zone;
DECLARE nw_order_id bigint default -1;
DECLARE checkpoints_count integer;

declare ch_to_point_id integer;
declare ch_to_addr_name text;
declare ch_to_addr_latitude numeric;
declare ch_to_addr_longitude numeric;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;
declare ch_distance_to real;
declare ch_duration_to integer;
declare ch_to_time_to timestamp without time zone;

declare calc_status_id integer default 0;
declare driver_summa numeric;
declare perc numeric default 0;
declare route_checkpoint_duration integer default 0;
declare route_load_duration integer default 0;
declare int_num integer;

begin

if token_ <> (select cl.token from data.clients cl where cl.id=client_id_) then
 return -1;
end if;

create_time = now()::timestamp(0);

checkpoints_count = jsonb_array_length(checkpoints_);
  
  select o.perc_agg,o.route_checkpoint_duration,o.route_load_duration from laravel.mab_aggregator_options o where o.id=1 
   into perc,route_checkpoint_duration,route_load_duration;
   
--   int_num = summa_ * (100-perc)/100;/* /10;
--   int_num = int_num*10;*/
   driver_summa = summa_;
   
  insert into data.orders (id,order_time,order_title,point_id,from_addr_name,from_addr_latitude,from_addr_longitude,from_time,doc_date,from_kontakt_name,from_kontakt_phone,from_notes,client_summa,summa,driver_id,dispatcher_id,client_dispatcher_id,client_id,status_id,carclass_id,hours,distance,duration,duration_calc,visible,notes,pallets_count,free_sum,client_code)
         values (nextval('data.orders_id_seq'),create_time,order_title_,case from_point_id_ when 0 then null else from_point_id_ end,from_addr_name_,from_addr_latitude_,from_addr_longitude_,from_time_,doc_date_,from_kontakt_name_,from_kontakt_phone_,from_notes_,summa_,driver_summa,null,dispatcher_id_,dispatcher_id_,client_id_,case draft when true then 20 else 30 end,carclass_id_,hours_,distance_,duration_,(duration_+checkpoints_count*route_checkpoint_duration+route_load_duration),true,notes_,pallets_count_,true,client_code_) 
		 returning id into nw_order_id;

  /* add history */
  insert into data.order_history (id,client_id,order_title,point_id,from_name,summa,latitude,longitude) 
		  values (nextval('data.order_history_id_seq'),client_id_,order_title_,case from_point_id_ when 0 then null else from_point_id_ end,from_addr_name_,summa_,from_addr_latitude_,from_addr_longitude_) 
          on conflict do nothing;

  
  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_point_id = cast(checkpoints_->i->>'to_point_id' as integer);
	if ch_to_point_id = 0 then
	 ch_to_point_id = null;
	end if;
    ch_to_addr_name = cast(checkpoints_->i->>'to_addr_name' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'to_addr_latitude' as numeric);
    ch_to_addr_longitude = cast(checkpoints_->i->>'to_addr_longitude' as numeric);
    ch_kontakt_name = cast(checkpoints_->i->>'kontakt_name' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'kontakt_phone' as text);
    ch_notes = cast(checkpoints_->i->>'to_notes' as text);
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);

    insert into data.checkpoints (id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),nw_order_id,
			 ch_to_point_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 ch_distance_to,
			 ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,point_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_point_id,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

insert into data.order_log(id,order_id,client_id,datetime,status_new,action_string)
values (nextval('data.order_log_id_seq'),nw_order_id,client_id_,CURRENT_TIMESTAMP,case draft when true then 20 else 30 end,'Create') 
on conflict do nothing;

return coalesce(nw_order_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.create_order_by_client_token(client_id_ integer, token_ text, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, pallets_count_ numeric, checkpoints_ jsonb, draft boolean, client_code_ character varying) OWNER TO postgres;

--
-- TOC entry 499 (class 1255 OID 16462)
-- Name: create_point_by_client_token(integer, text, character varying, character varying, character varying, text, boolean, bigint, jsonb); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.create_point_by_client_token(client_id_ integer, token_ text, code_ character varying, name_ character varying, address_ character varying, description_ text, visible_ boolean, original_id_ bigint, additional_ jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается через API агрегатора.
Создание новой точки.
Возвращает либо id, либо -1.
*/

DECLARE nw_point_id integer default -1;
DECLARE additional_count integer;

declare i integer;
declare add_latitude numeric;
declare add_longitude numeric;

begin

if token_ <> (select cl.token from data.clients cl where cl.id=client_id_) then
 return -1;
end if;

additional_count = jsonb_array_length(additional_);
  
  insert into data.client_points (id,client_id,name,address,code,description,visible,google_original)
         values (nextval('data.client_points_id_seq'),client_id_,name_,address_,code_,description_,visible_,original_id_) 
		 returning id into nw_point_id;
   
  
  FOR i IN 0..(additional_count-1) LOOP
   begin
    add_latitude = cast(additional_->i->>'latitude' as numeric);
    add_longitude = cast(additional_->i->>'longitude' as numeric);

    insert into data.client_point_coordinates (id,point_id,latitude,longitude)  
	  values(nextval('data.client_point_coordinates_id_seq'),nw_point_id,add_latitude,add_longitude);
	 
	end; /* for */ 
  END LOOP;

return coalesce(nw_point_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.create_point_by_client_token(client_id_ integer, token_ text, code_ character varying, name_ character varying, address_ character varying, description_ text, visible_ boolean, original_id_ bigint, additional_ jsonb) OWNER TO postgres;

--
-- TOC entry 500 (class 1255 OID 16463)
-- Name: del_client(integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.del_client(client_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

DELETE FROM data.clients where id=client_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION aggregator_api.del_client(client_id_ integer) OWNER TO postgres;

--
-- TOC entry 501 (class 1255 OID 16464)
-- Name: del_comission(integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.del_comission(id_ integer, OUT success boolean, OUT error text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Редактирование/добавление комиссии.
Возвращает либо true/false + текст ошибки.
*/

DECLARE b_date date;

begin

success = false;

select begin_date from data.agg_commission where id=id_ into b_date;

  if (select max(begin_date) from data.agg_commission where id<>id_) >= b_date then
    begin
	 error = 'There are records with bigger date!';
	 return;
	end;
   end if;	
   
  delete from data.agg_commission where id=id_;  
  success = true;	 

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION aggregator_api.del_comission(id_ integer, OUT success boolean, OUT error text) OWNER TO postgres;

--
-- TOC entry 502 (class 1255 OID 16465)
-- Name: del_dispatcher(integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.del_dispatcher(del_dispatcher_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

DELETE FROM data.dispatchers where id=del_dispatcher_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION aggregator_api.del_dispatcher(del_dispatcher_id_ integer) OWNER TO postgres;

--
-- TOC entry 503 (class 1255 OID 16466)
-- Name: del_google_address(bigint); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.del_google_address(address_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается агрегатором.
Удаление гугл-адреса.
Возвращает либо true, либо false.
*/
begin

delete from data.google_addresses where id=address_id_;

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$$;


ALTER FUNCTION aggregator_api.del_google_address(address_id_ bigint) OWNER TO postgres;

--
-- TOC entry 504 (class 1255 OID 16467)
-- Name: dispatcher_exists(integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.dispatcher_exists(dispatcher_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

return exists(select 1 from data.dispatchers where id=dispatcher_id_);

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION aggregator_api.dispatcher_exists(dispatcher_id_ integer) OWNER TO postgres;

--
-- TOC entry 505 (class 1255 OID 16468)
-- Name: driver_forgot_password(text, character varying); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.driver_forgot_password(hash text, loginin character varying, OUT driver_id integer, OUT reset_code character varying, OUT reset_time timestamp without time zone, OUT result_code integer) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызов функции "забыл пароль".
Возвращается посланный код и результат функции. 
*/

BEGIN

driver_id = 0;
result_code = 0;
reset_code = '';
reset_time = null;

if not sysdata.check_signing(hash) then
 return;
end if;

result_code = -1;
update data.drivers set 
 reset_password_code = substring(md5(random()::text) from 3 for 6),
 reset_password_time = CURRENT_TIMESTAMP::timestamp(0)
where upper(login) = upper(loginin)
returning id,reset_password_code,reset_password_time,1
into driver_id,reset_code,reset_time,result_code;

result_code = coalesce(result_code,-1);

END;

$$;


ALTER FUNCTION aggregator_api.driver_forgot_password(hash text, loginin character varying, OUT driver_id integer, OUT reset_code character varying, OUT reset_time timestamp without time zone, OUT result_code integer) OWNER TO postgres;

--
-- TOC entry 507 (class 1255 OID 16469)
-- Name: edit_client(integer, character varying, character varying, character varying, integer, character varying, numeric, numeric, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.edit_client(client_id_ integer, client_name_ character varying, client_email_ character varying, client_pass_ character varying, client_def_dispatcher_ integer, client_def_load_ character varying, client_def_load_lat_ numeric, client_def_load_lng_ numeric, client_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Редактирование/добавление клиента.
Возвращает либо id, либо -1.
*/
DECLARE client_id integer default -1;

begin

/*
if coalesce(client_def_dispatcher_,0)<1 then
 client_def_dispatcher_ = null;
end if;
*/

if coalesce(client_id_,0)>0 then
 begin
 
  update data.clients set name=client_name_,
                   email=client_email_,
	               password=client_pass_,
				   default_dispatcher_id=client_def_dispatcher_, 
				   default_load_address=client_def_load_,
				   default_load_latitude=client_def_load_lat_,
				   default_load_longitude=client_def_load_lng_,
                   is_active=client_is_active_
	 where id=client_id_
	 returning id into client_id;	   
	 
 end;
else
 begin
 
  insert into data.clients (id,name,email,password,default_dispatcher_id,default_load_address,default_load_latitude,default_load_longitude,is_active,token)
         values (nextval('data.clients_id_seq'),client_name_,client_email_,client_pass_,client_def_dispatcher_,client_def_load_,client_def_load_lat_,client_def_load_lng_,client_is_active_,sysdata.gen_random_uuid()) 
		 returning id into client_id;
		 
 end;
end if;

return coalesce(client_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.edit_client(client_id_ integer, client_name_ character varying, client_email_ character varying, client_pass_ character varying, client_def_dispatcher_ integer, client_def_load_ character varying, client_def_load_lat_ numeric, client_def_load_lng_ numeric, client_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 508 (class 1255 OID 16470)
-- Name: edit_comission(integer, date, numeric, text, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.edit_comission(id_ integer, begin_date_ date, percent_ numeric, name_ text, description_ text, OUT commission_id integer, OUT error text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Редактирование/добавление комиссии.
Возвращает либо id, либо -1 + текст ошибки.
*/

begin

commission_id = -1;

if coalesce(id_,0)>0 then --edit
 begin
  if (select max(begin_date) from data.agg_commission where id<>id_) >= begin_date_ then
    begin
	 error = 'Invalid begin date!';
	 return;
	end;
   end if;	
   
  update data.agg_commission set begin_date = begin_date_,
                   percent = percent_,
                   name = name_,
	               description = description_
	 where id=id_;
  
  commission_id = id_;	 
 end;
else
 begin
  if (select max(begin_date) from data.agg_commission) >= begin_date_ then
    begin
	 error = 'Invalid begin date!';
	 return;
	end;
   end if;	
 
  insert into data.agg_commission (id,begin_date,percent,name,description)
         values (nextval('data.agg_commission_id_seq'),begin_date_,percent_,name_,description_) 
		 returning id into commission_id;		 
 end;
end if;

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION aggregator_api.edit_comission(id_ integer, begin_date_ date, percent_ numeric, name_ text, description_ text, OUT commission_id integer, OUT error text) OWNER TO postgres;

--
-- TOC entry 509 (class 1255 OID 16471)
-- Name: edit_dispatcher(integer, character varying, character varying, character varying, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.edit_dispatcher(dispatcher_edit_id_ integer, dispatcher_name_ character varying, dispatcher_login_ character varying, dispatcher_pass_ character varying, dispatcher_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Редактирование данных диспетчера.
Возвращает либо id, либо -1.
*/
DECLARE dispatcher_id integer default -1;

begin

   if coalesce(dispatcher_edit_id_,0)<1 then
     insert into data.dispatchers (id,login,pass,name,is_active,token) 
                            values (nextval('data.dispatchers_id_seq'),dispatcher_login_,dispatcher_pass_,dispatcher_name_,dispatcher_is_active_,sysdata.gen_random_uuid())
		   				    returning id into dispatcher_id;
   else
      update data.dispatchers set name=dispatcher_name_,
				   login=dispatcher_login_,
				   pass=dispatcher_pass_,
				   is_active=dispatcher_is_active_
	   where id=dispatcher_edit_id_
	   returning id into dispatcher_id;	   
	end if;   

return coalesce(dispatcher_id,-1);

end

$$;


ALTER FUNCTION aggregator_api.edit_dispatcher(dispatcher_edit_id_ integer, dispatcher_name_ character varying, dispatcher_login_ character varying, dispatcher_pass_ character varying, dispatcher_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 510 (class 1255 OID 16472)
-- Name: edit_order_by_client_token(integer, text, bigint, character varying, character varying, integer, character varying, numeric, numeric, timestamp without time zone, date, character varying, character varying, character varying, numeric, integer, integer, integer, real, integer, character varying, numeric, jsonb, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.edit_order_by_client_token(client_id_ integer, token_ text, order_id_ bigint, order_code_ character varying, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, pallets_count_ numeric, checkpoints_ jsonb, draft boolean, OUT edit_order_id bigint, OUT success boolean, OUT error_text text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается через API агрегатора.
Редактирование заказа. 
Возвращает success (true/false) и error_text.
*/

DECLARE edit_duration_calc integer;
DECLARE checkpoints_count integer;

declare ch_to_point_id integer;
declare ch_to_addr_name text;
declare ch_to_addr_latitude numeric;
declare ch_to_addr_longitude numeric;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;
declare ch_distance_to real;
declare ch_duration_to integer;
declare ch_to_time_to timestamp without time zone;

declare current_status_id integer default 0;
declare calc_status_id integer default 0;
declare driver_summa numeric default null;
declare perc numeric default 0;
declare route_checkpoint_duration integer default 0;
declare route_load_duration integer default 0;
declare int_num integer;

begin

success = false;
if token_ <> (select cl.token from data.clients cl where cl.id=client_id_) then
 begin
  error_text = 'Invalid token!'
  return;
 end; 
end if;

if order_id_=0 then
  select o.id,o.status_id from data.orders o where o.client_id=client_id_ and o.client_code=order_code_ for update 
  into edit_order_id, current_status_id;
else  
  select o.id,o.status_id from data.orders o where o.client_id=client_id_ and o.id=order_id_ for update
  into edit_order_id, current_status_id;
end if; 

if coalesce(edit_order_id,-1)<0 then
 begin
  error_text = 'Order is not found!';
  return;
 end; 
end if;

if current_status_id>=110 then
 begin
  error_text = 'Order is executing!';
  return;
 end; 
end if; 

if dispatcher_id_ is not null and current_status_id>30 then
 begin
  error_text = 'Cannot change dispatcher!';
  return;
 end; 
end if; 

if draft and current_status_id>30 then
 begin
  error_text = 'Cannot change order status to draft!';
  return;
 end; 
end if; 

if dispatcher_id_ is not null and 
   current_status_id=30 and 
   exists(select 1 from data.dispatcher_selected_orders dso where dso.order_id=edit_order_id) then
   begin
     error_text = 'Cannot change dispatcher!';
     return;
   end;
end if; 

if draft and 
   current_status_id=30 and 
   exists(select 1 from data.dispatcher_selected_orders dso where dso.order_id=edit_order_id) then
   begin
     error_text = 'Cannot change order status to draft!';
     return;
   end;
end if; 

if draft then
 calc_status_id = 20;
else 
 calc_status_id = current_status_id;
end if; 

if checkpoints_ is not null then
 checkpoints_count = jsonb_array_length(checkpoints_);
else 
 checkpoints_count = 0;
end if;

if summa_ is not null then
 begin
  select o.perc_agg,o.route_checkpoint_duration,o.route_load_duration from laravel.mab_aggregator_options o where o.id=1 
   into perc,route_checkpoint_duration,route_load_duration;
   
--   int_num = summa_ * (100-perc)/100;/* /10;
--   int_num = int_num*10;*/
   driver_summa = summa_;
 end;
end if; 

if duration_ is null then
  edit_duration_calc = null;
else  
  edit_duration_calc = duration_+checkpoints_count*route_checkpoint_duration+route_load_duration;
end if;  

  update data.orders set order_title = coalesce(order_title_,order_title),
  					point_id = case from_point_id_ when 0 then null else coalesce(from_point_id_, point_id) end,
					from_addr_name = coalesce(from_addr_name_, from_addr_name),
					from_addr_latitude = coalesce(from_addr_latitude_, from_addr_latitude),
					from_addr_longitude = coalesce(from_addr_longitude_, from_addr_longitude),
					from_time = coalesce(from_time_, from_time),
					doc_date = coalesce(doc_date_, doc_date),
					from_kontakt_name = coalesce(from_kontakt_name_, from_kontakt_name),
					from_kontakt_phone = coalesce(from_kontakt_phone_, from_kontakt_phone),
					from_notes = coalesce(from_notes_, from_notes),
					client_summa = coalesce(summa_, client_summa),
					summa = coalesce(driver_summa, summa),
					dispatcher_id = coalesce(dispatcher_id_, dispatcher_id),
					client_dispatcher_id = coalesce(dispatcher_id_, client_dispatcher_id),
					status_id = calc_status_id,
					carclass_id = coalesce(carclass_id_, carclass_id),
					hours = case when checkpoints_count>0 then null else coalesce(hours_, hours) end,
					distance = coalesce(distance_, distance),
					duration = coalesce(duration_, duration),
					duration_calc = coalesce(edit_duration_calc, duration_calc),
					notes = coalesce(notes_, notes),
					pallets_count = coalesce(pallets_count_, pallets_count)
  where id=edit_order_id;
  

  if hours_ is not null or checkpoints_ is not null then
    delete from data.checkpoints ch where ch.order_id = edit_order_id;
  end if;
  
  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_point_id = cast(checkpoints_->i->>'to_point_id' as integer);
	if ch_to_point_id = 0 then
	 ch_to_point_id = null;
	end if;
    ch_to_addr_name = cast(checkpoints_->i->>'to_addr_name' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'to_addr_latitude' as numeric);
    ch_to_addr_longitude = cast(checkpoints_->i->>'to_addr_longitude' as numeric);
    ch_kontakt_name = cast(checkpoints_->i->>'kontakt_name' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'kontakt_phone' as text);
    ch_notes = cast(checkpoints_->i->>'to_notes' as text);
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);

    insert into data.checkpoints (id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),edit_order_id,
			 ch_to_point_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 ch_distance_to,
			 ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,point_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_point_id,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

insert into data.order_log(id,order_id,client_id,datetime,status_new,action_string)
values (nextval('data.order_log_id_seq'),edit_order_id,client_id_,CURRENT_TIMESTAMP,calc_status_id,'Edit') 
on conflict do nothing;

success = 1;
return;

end

$$;


ALTER FUNCTION aggregator_api.edit_order_by_client_token(client_id_ integer, token_ text, order_id_ bigint, order_code_ character varying, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, pallets_count_ numeric, checkpoints_ jsonb, draft boolean, OUT edit_order_id bigint, OUT success boolean, OUT error_text text) OWNER TO postgres;

--
-- TOC entry 511 (class 1255 OID 16474)
-- Name: edit_region(integer, text, numeric, text, boolean, polygon); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.edit_region(id_ integer, name_ text, koeff_ numeric, description_ text, is_active_ boolean, region_ polygon, OUT region_id integer, OUT error text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Редактирование/добавление региона.
Возвращает либо id, либо -1 + текст ошибки.
*/

begin

region_id = -1;

if coalesce(id_,0)>0 then --edit
 begin
  update data.agg_regions set koeff = koeff_,
                   region = region_,
                   name = name_,
	               description = description_,
				   is_active = is_active_
	 where id=id_;
  
  region_id = id_;	 
 end;
else
  insert into data.agg_regions (id,name,koeff,description,is_active,region)
         values (nextval('data.agg_regions_id_seq'),name_,koeff_,description_,is_active_,region_) 
		 returning id into region_id;		 
end if;

return;

--EXCEPTION
--WHEN OTHERS THEN 
--  RETURN;

end

$$;


ALTER FUNCTION aggregator_api.edit_region(id_ integer, name_ text, koeff_ numeric, description_ text, is_active_ boolean, region_ polygon, OUT region_id integer, OUT error text) OWNER TO postgres;

--
-- TOC entry 512 (class 1255 OID 16475)
-- Name: get_client_by_id(integer); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_client_by_id(id_ integer) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается аггрегатором.
Просмотр клиента по id.
*/

DECLARE client_data text default NULL;
BEGIN

select cast(json_build_object(
	     'name',cl.name,
		 'email',cl.email,
	 	 'default_load_address',cl.default_load_address,
	 	 'default_load_latitude',cl.default_load_latitude,
	 	 'default_load_longitude',cl.default_load_longitude,	 
		 'is_active',cl.is_active,
	     'default_dispatcher_id',cl.default_dispatcher_id) as text)
 from data.clients cl
 where cl.id=id_ into client_data;

 RETURN client_data;
 
END

$$;


ALTER FUNCTION aggregator_api.get_client_by_id(id_ integer) OWNER TO postgres;

--
-- TOC entry 513 (class 1255 OID 16476)
-- Name: get_client_by_token(character varying); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_client_by_token(token_ character varying) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается аггрегатором.
Просмотр клиента по токену.
*/

DECLARE client_data text default NULL;
BEGIN


select cast(json_build_object(
		 'id',cl.id,
	     'name',cl.name,
		 'email',cl.email,
	 	 'default_load_address',cl.default_load_address,
	 	 'default_load_latitude',cl.default_load_latitude,
	 	 'default_load_longitude',cl.default_load_longitude,	 
		 'is_active',cl.is_active,
	     'default_dispatcher_id',cl.default_dispatcher_id) as text)
 from data.clients cl
 where cl.token=token_ into client_data;

 RETURN client_data;
 
END

$$;


ALTER FUNCTION aggregator_api.get_client_by_token(token_ character varying) OWNER TO postgres;

--
-- TOC entry 506 (class 1255 OID 16477)
-- Name: get_dispatcher_by_token(character varying); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_dispatcher_by_token(token_ character varying) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается аггрегатором.
Просмотр диспетчера по токену.
*/

DECLARE dispatcher_data text default NULL;
BEGIN

select cast(json_build_object(
		 'id',d.id,
	     'name',d.name,
		 'is_active',d.is_active) as text)
 from data.dispatchers d
 where d.token=token_ into dispatcher_data;

 RETURN dispatcher_data;
 
END

$$;


ALTER FUNCTION aggregator_api.get_dispatcher_by_token(token_ character varying) OWNER TO postgres;

--
-- TOC entry 514 (class 1255 OID 16478)
-- Name: get_ga_by_client_token(integer, text, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_ga_by_client_token(client_id_ integer, token_ text, address_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается через API по токену клиента.
Просмотр в кэше по адресу.
*/

BEGIN

return (select json_build_object(
		 'address_id',ga.id,
	     'point_id',cp.id,
	     'point_code',cp.code,
	     'original_id',ga.google_original,
	     'latitude',coalesce(gm.latitude,gor.latitude),
	     'longitude',coalesce(gm.longitude,gor.longitude))
 from data.google_addresses ga
 left join data.google_originals gor on ga.google_original=gor.id	
 left join data.google_modifiers gm on gm.original_id=gor.id and gm.client_id=ga.client_id
 left join data.clients cl ON cl.id=ga.client_id
 left join data.client_points cp on cp.google_original=gor.id and cp.client_id=client_id_
 where ga.client_id=client_id_ and cl.token=token_ and trim(upper(address_))=trim(upper(ga.address)) LIMIT 1);

END

$$;


ALTER FUNCTION aggregator_api.get_ga_by_client_token(client_id_ integer, token_ text, address_ text) OWNER TO postgres;

--
-- TOC entry 515 (class 1255 OID 16479)
-- Name: get_google_address(text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_google_address(address_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Просмотр координат кэшированных по адресу.
*/

BEGIN

return (select json_build_object(
		 'address_id',ga.id,
	     'latitude',gor.latitude,
	     'longitude',gor.longitude)
 from data.google_addresses ga
 left join data.google_originals gor on ga.google_original=gor.id	
 where upper(address_)=upper(ga.address));

END

$$;


ALTER FUNCTION aggregator_api.get_google_address(address_ text) OWNER TO postgres;

--
-- TOC entry 516 (class 1255 OID 16480)
-- Name: get_order(bigint); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_order(order_id_ bigint, OUT json_data text, OUT json_checkpoints text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается аггрегатором.
Просмотр заказа.
*/
BEGIN

select json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'from_time',o.from_time,
		 'point_id',o.point_id,
		 'point_name',p.name,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
		 'from_addr_longitude',o.from_addr_longitude,
	     'from_kontakt_name',o.from_kontakt_name,
	     'from_kontakt_phone',o.from_kontakt_phone,
	     'from_notes',o.from_notes,
	     'summa',o.summa,
		 'dispatcher_id',o.dispatcher_id,
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'paytype_id',coalesce(o.paytype_id,0),
		 'hours',coalesce(o.hours,0),
		 'client_id',o.client_id,
		 'client_dispatcher_id',o.client_dispatcher_id,
		 'client_code',o.client_code,
		 'client_summa',o.client_summa,
		 'driver_car_attribs',o.driver_car_attribs,
		 'is_deleted',o.is_deleted,
		 'del_time',o.del_time,
		 'distance',o.distance,
		 'duration',o.duration,
		 'duration_calc',o.duration_calc,
		 'notes',o.notes,
		 'visible',o.visible)
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join data.drivers d on d.id=o.driver_id
  where o.id=order_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'order_id',c.order_id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'notes',c.notes,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = order_id_
		  ORDER BY c.position_in_order) )
		  into json_checkpoints;

END

$$;


ALTER FUNCTION aggregator_api.get_order(order_id_ bigint, OUT json_data text, OUT json_checkpoints text) OWNER TO postgres;

--
-- TOC entry 517 (class 1255 OID 16481)
-- Name: get_order_by_code(integer, character varying); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.get_order_by_code(client_id_ integer, client_code_ character varying, OUT json_data text, OUT json_checkpoints text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается аггрегатором.
Просмотр документа по коду клиента.
*/
DECLARE _order_id_ BIGINT DEFAULT NULL;
BEGIN

select o.id,
       json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'from_time',o.from_time,
		 'point_id',o.point_id,
		 'point_name',p.name,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
		 'from_addr_longitude',o.from_addr_longitude,
	     'from_kontakt_name',o.from_kontakt_name,
	     'from_kontakt_phone',o.from_kontakt_phone,
	     'from_notes',o.from_notes,
	     'summa',o.summa,
		 'dispatcher_id',o.dispatcher_id,
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'paytype_id',coalesce(o.paytype_id,0),
		 'hours',coalesce(o.hours,0),
		 'client_id',o.client_id,
		 'client_dispatcher_id',o.client_dispatcher_id,
		 'client_code',o.client_code,
		 'client_summa',o.client_summa,
		 'driver_car_attribs',o.driver_car_attribs,
		 'is_deleted',o.is_deleted,
		 'del_time',o.del_time,
		 'distance',o.distance,
		 'duration',o.duration,
		 'duration_calc',o.duration_calc,
		 'notes',o.notes,
		 'visible',o.visible)
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join data.drivers d on d.id=o.driver_id
  where o.client_id=client_id_ and o.client_code=client_code_ 
  into _order_id_,json_data;

if coalesce(_order_id_,0)>0 then
  select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'order_id',c.order_id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'notes',c.notes,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = _order_id_
		  ORDER BY c.position_in_order) )
		  into json_checkpoints;
end if;
 
END

$$;


ALTER FUNCTION aggregator_api.get_order_by_code(client_id_ integer, client_code_ character varying, OUT json_data text, OUT json_checkpoints text) OWNER TO postgres;

--
-- TOC entry 518 (class 1255 OID 16482)
-- Name: set_client_active(integer, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.set_client_active(client_id_ integer, client_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Установка активности клиента.
Возврат id или -1.
*/
DECLARE client_id integer DEFAULT 0;

BEGIN 

update data.clients set is_active=client_is_active_ 
  where id=client_id_
  returning id into client_id;

RETURN coalesce(client_id,0);
END

$$;


ALTER FUNCTION aggregator_api.set_client_active(client_id_ integer, client_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 519 (class 1255 OID 16483)
-- Name: set_dispatcher_active(integer, boolean); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.set_dispatcher_active(dispatcher_id_ integer, dispatcher_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Установка активности диспетчера.
Возврат id или -1.
*/
DECLARE dispatcher_id integer DEFAULT 0;

BEGIN 

update data.dispatchers set is_active=dispatcher_is_active_ 
  where id=dispatcher_id_
  returning id into dispatcher_id;

RETURN coalesce(dispatcher_id,0);
END

$$;


ALTER FUNCTION aggregator_api.set_dispatcher_active(dispatcher_id_ integer, dispatcher_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 520 (class 1255 OID 16484)
-- Name: view_clients(); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_clients() RETURNS TABLE(id integer, name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

RETURN QUERY
select 
 cl.id,
 cl.name
 from data.clients cl
 order by cl.name;

END 
$$;


ALTER FUNCTION aggregator_api.view_clients() OWNER TO postgres;

--
-- TOC entry 521 (class 1255 OID 16485)
-- Name: view_commissions(); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_commissions() RETURNS TABLE(id integer, begin_date date, percent numeric, name text, description text, last_date boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

RETURN QUERY
select 
 ac.id,
 ac.begin_date,
 ac.percent,
 ac.name,
 ac.description,
 case ac.begin_date when (select max(ac2.begin_date) from data.agg_commission ac2) then true else false end
 from data.agg_commission ac
 order by ac.begin_date;

END 

$$;


ALTER FUNCTION aggregator_api.view_commissions() OWNER TO postgres;

--
-- TOC entry 522 (class 1255 OID 16486)
-- Name: view_dispatchers(); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_dispatchers() RETURNS TABLE(id integer, name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

RETURN QUERY
select 
 d.id,
 d.name
 from data.dispatchers d
 order by d.name;

END 

$$;


ALTER FUNCTION aggregator_api.view_dispatchers() OWNER TO postgres;

--
-- TOC entry 523 (class 1255 OID 16487)
-- Name: view_drivers_by_token(integer, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_drivers_by_token(dispatcher_id_ integer, token_ text) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, is_active boolean, date_of_birth date)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается агрегатором.
Просмотр водителей по токену диспетчера.
*/

BEGIN

        RETURN QUERY  
	      SELECT d.id,
          d.name,
	      d.second_name,
	      d.family_name,
          d.is_active,
          d.date_of_birth
         FROM data.drivers d
         LEFT JOIN data.dispatchers dsp ON d.dispatcher_id = dsp.id
         WHERE d.dispatcher_id=dispatcher_id_ and dsp.token=token_;
END

$$;


ALTER FUNCTION aggregator_api.view_drivers_by_token(dispatcher_id_ integer, token_ text) OWNER TO postgres;

--
-- TOC entry 524 (class 1255 OID 16488)
-- Name: view_orders(); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_orders() RETURNS TABLE(id bigint, order_time timestamp without time zone, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, client_summa numeric, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, dispatcher_name character varying, carclass_id integer, carclass_name character varying, paytype_id integer, paytype_name character varying, is_deleted boolean, distance real, duration integer, visible boolean, notes character varying, order_title character varying, client_id integer, client_name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается аггрегатором.
Просмотр всех заказов по всем диспетчерам.
*/

BEGIN

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.from_time,
	o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.client_summa,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	disp.name as dispatcher_name,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.paytype_id,
	coalesce(pt.name,'Любой'),
	o.is_deleted,
	o.distance,
	o.duration,
	o.visible,
    o.notes,
	o.order_title,
	o.client_id,
	cl.name		  
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.dispatchers disp ON disp.id=o.dispatcher_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
   LEFT JOIN sysdata."SYS_PAYTYPES" pt ON pt.id=o.paytype_id
  WHERE (not coalesce(o.is_deleted,false));
  
END

$$;


ALTER FUNCTION aggregator_api.view_orders() OWNER TO postgres;

--
-- TOC entry 525 (class 1255 OID 16489)
-- Name: view_orders_by_client_token(integer, text, date, date); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_orders_by_client_token(client_id_ integer, token_ text, date1 date, date2 date) RETURNS TABLE(id bigint, order_time timestamp without time zone, order_title character varying, from_time timestamp without time zone, point_code character varying, point_name character varying, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, from_kontakt_name character varying, from_kontakt_phone character varying, from_notes character varying, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, dispatcher_name character varying, carclass_id integer, carclass_name character varying, distance real, duration integer, duration_calc integer, visible boolean, notes character varying, checkpoints json, driver_car_attribs jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается через API по токену клиента.
Просмотр всех заказов по клиенту.
*/

BEGIN

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.order_title,	
	o.from_time,
	pt.code,
	coalesce(pt.name,''),
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
	o.from_kontakt_name,
	o.from_kontakt_phone,
	o.from_notes,
    o.client_summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	disp.name,
	o.carclass_id,
	cc.name,
	o.distance,
	o.duration,
	o.duration_calc,
	o.visible,
    o.notes,
	(select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_point_code',p.code,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'to_notes',c.notes,
									   'visited_status',coalesce(c.visited_status,false),
									   'visited_time',c.visited_time,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'position_in_order',c.position_in_order)
          FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = o.id
		  ORDER BY c.position_in_order))
	),
	o.driver_car_attribs
	
   FROM data.orders o
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.dispatchers disp ON disp.id=o.dispatcher_id
   LEFT JOIN data.client_points pt on pt.id=o.point_id						  
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
  WHERE (o.client_id = client_id_ and cl.token=token_ 
		 and o.from_time::date>=date1 and o.from_time::date<=date2
		 and not coalesce(o.is_deleted, false));
  
END

$$;


ALTER FUNCTION aggregator_api.view_orders_by_client_token(client_id_ integer, token_ text, date1 date, date2 date) OWNER TO postgres;

--
-- TOC entry 526 (class 1255 OID 16490)
-- Name: view_points_by_client_token(integer, text); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_points_by_client_token(client_id_ integer, token_ text) RETURNS TABLE(id integer, code character varying, name character varying, address character varying, google_original bigint, latitude numeric, longitude numeric, description text, visible boolean, additional json)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается через апи по токену клиента.
Просмотр всех мест.
*/

BEGIN

 RETURN QUERY  
	SELECT cp.id,
	cp.code,
	cp.name,
	cp.address,	
	cp.google_original,
    gor.latitude,
    gor.longitude,
    cp.description,
	coalesce(cp.visible,true),
	(select array_to_json(ARRAY( SELECT json_build_object('latitude',cpc.latitude,
									   'longitude',cpc.longitude)
           FROM data.client_point_coordinates cpc
          WHERE cpc.point_id = cp.id
		  ORDER BY cpc.id)))
   FROM data.client_points cp
   LEFT JOIN data.google_originals gor on gor.id=cp.google_original
   LEFT JOIN data.clients cl on cl.id=cp.client_id
  WHERE (cp.client_id = client_id_ and cl.token=token_);
  
END

$$;


ALTER FUNCTION aggregator_api.view_points_by_client_token(client_id_ integer, token_ text) OWNER TO postgres;

--
-- TOC entry 527 (class 1255 OID 16491)
-- Name: view_regions(); Type: FUNCTION; Schema: aggregator_api; Owner: postgres
--

CREATE FUNCTION aggregator_api.view_regions() RETURNS TABLE(id integer, region polygon, koeff numeric, name text, description text, is_active boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

RETURN QUERY
select 
 ar.id,
 ar.region,
 ar.koeff,
 ar.name,
 ar.description,
 ar.is_active
 from data.agg_regions ar;

END 

$$;


ALTER FUNCTION aggregator_api.view_regions() OWNER TO postgres;

--
-- TOC entry 528 (class 1255 OID 16492)
-- Name: add_to_log(integer, integer, integer, text, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.add_to_log(driver_id_ integer, dispatcher_id_ integer, client_id_ integer, pass_ text, action_ text, ip_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем/диспетчером/клиентом.
Добавляет данные в лог.
*/
DECLARE ok boolean;
begin

return false;

ok = false;
if coalesce(driver_id_,0)>0 then
 begin
  ok = true; 
  if sysdata.check_id_driver(driver_id_,pass_)<1 then
   return false;
  end if; 
 end; 
end if; 

if not ok and coalesce(dispatcher_id_,0)>0 then
 begin
   ok = true; 
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
     return false;
    end if; 	
  end;	
end if;

if not ok and coalesce(client_id_,0)>0 then
 begin
   ok = true; 
   if sysdata.check_id_client(client_id_,pass_)<1 then
     return false;
    end if; 	
  end;	
end if;

if not ok then 
 return false;
end if; 

if driver_id_ = 0 then
  driver_id_ = null;
end if;
if dispatcher_id_ = 0 then
  dispatcher_id_ = null;
end if;
if client_id_ = 0 then
  client_id_ = null;
end if;

insert into data.log (id,datetime,driver_id,dispatcher_id,client_id,ip,user_action) values (nextval('data.log_id_seq'),CURRENT_TIMESTAMP,driver_id_,dispatcher_id_,client_id_,ip_,action_);

return true;
end

$$;


ALTER FUNCTION api.add_to_log(driver_id_ integer, dispatcher_id_ integer, client_id_ integer, pass_ text, action_ text, ip_ text) OWNER TO postgres;

--
-- TOC entry 530 (class 1255 OID 16493)
-- Name: bak_driver_available_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.bak_driver_available_orders(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, from_addr_name character varying, from_addr_latitude real, from_addr_longitude real, to_addr_names character varying[], summa numeric, status_id integer, driver_id integer, dispatcher_id integer, notes character varying, order_title character varying, order_time timestamp without time zone, current_distance real)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Новые, доступные для взятия заказы и свои выполняемые.
Есть проверка на наличие машины нужного класса, и паузы в показе для разных уровней водителей.
Проверяется, не отклонен ли этот заказ водителем раньше.
*/
DECLARE driver_latitude real default 0;
DECLARE driver_longitude real default 0;
DECLARE cars_array integer[];
DECLARE driver_level_id integer default 0;
DECLARE min_btw_levels integer default 0;
DECLARE max_level integer default 0;
DECLARE calc_minutes integer;
DECLARE driver_dispatcher_id integer default 0;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 select dcl.latitude, dcl.longitude from data.driver_current_locations dcl where dcl.driver_id=driver_id_ 
 into driver_latitude,driver_longitude;

 select ARRAY( SELECT sc.id FROM data.driver_cars dc, sysdata."SYS_CARCLASSES" sc, sysdata."SYS_CARTYPES" st WHERE dc.driver_id = driver_id_ and dc.cartype_id=st.id and st.class_id=sc.id) 
 into cars_array;
 
 select d.level_id,d.dispatcher_id from data.drivers d where d.id = driver_id_ 
  into driver_level_id,driver_dispatcher_id;
 select max(dl.id) from sysdata."SYS_DRIVERLEVELS" dl 
  into max_level;
 select sp.param_value_integer from sysdata."SYS_PARAMS" sp where sp.param_name='MIN_BTW_LEVELS' 
  into min_btw_levels;

 calc_minutes = min_btw_levels*(max_level-driver_level_id);
 
 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    ARRAY( SELECT c.to_addr_name
           FROM data.checkpoints c
          WHERE c.order_id = o.id) AS to_addr_names,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
    COALESCE(o.driver_id,0) as driver_id,
    o.dispatcher_id,
    o.notes,
	o.order_title,
	o.order_time,
    sysdata.get_distance(o.from_addr_latitude, driver_latitude, o.from_addr_longitude, driver_longitude) AS current_distance
   FROM data.orders o
  WHERE (coalesce(o.status_id,0) in (30,40,50,60,110) ) 
	AND NOT EXISTS(select 1 from data.orders_rejecting orj where orj.order_id=o.id and orj.driver_id=driver_id_)
	AND ((CURRENT_TIMESTAMP::timestamp without time zone) > (o.order_time+cast((cast(calc_minutes as text)||' min') as interval)) )
	AND (o.carclass_id is null or array_position(cars_array , o.carclass_id) IS NOT NULL)
	AND (sysdata.order4driver(o.id,driver_id_,driver_dispatcher_id));
  
END

$$;


ALTER FUNCTION api.bak_driver_available_orders(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 531 (class 1255 OID 16494)
-- Name: change_driver_pass_by_code(text, integer, character varying, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.change_driver_pass_by_code(hash text, driver_id_ integer, code_ character varying, pass_ character varying, OUT hashed_pass character varying, OUT driver_login character varying, OUT result_code integer) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
/*
Замена пароля водителя по коду из email.
Возвращается код ошибки.
*/

BEGIN

result_code = 1;
if not sysdata.check_signing(hash) then
 return;
end if;

driver_login = '';
select d.login from data.drivers d where d.id=driver_id_ and d.reset_password_code=code_ and (d.reset_password_time+interval '1 hour')>CURRENT_TIMESTAMP
into driver_login;

if coalesce(driver_login,'') <> '' then
  begin
	hashed_pass = replace(sysdata.crypt(pass_, sysdata.gen_salt('md5')),'$2a$','$2y$');
	update data.drivers set pass = hashed_pass where id = driver_id_;
	update laravel.backend_users set password = hashed_pass where role_id = 6 and linked_id = driver_id_;
	result_code = 0;
  end;
else
 result_code = 10;
end if; 

return;

END;

$_$;


ALTER FUNCTION api.change_driver_pass_by_code(hash text, driver_id_ integer, code_ character varying, pass_ character varying, OUT hashed_pass character varying, OUT driver_login character varying, OUT result_code integer) OWNER TO postgres;

--
-- TOC entry 532 (class 1255 OID 16495)
-- Name: check_login_client(text, character varying, character varying, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.check_login_client(hash text, loginin character varying, passin character varying, hashed_pass boolean DEFAULT true, OUT client_id integer, OUT client_pass character varying) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$/*
Проверка логина/пароля клиента.
Возвращается id и хэш пароля. Либо 0 и ''
*/

BEGIN

client_id = 0;
client_pass = '';

if not sysdata.check_signing(hash) then
 return;
end if;

if hashed_pass then
 begin
  passin = replace(passin,'$2y$','$2a$');
   select cl.id,cl.pass from data.clients cl 
    where cl.login=loginin and replace(cl.pass,'$2y$','$2a$')=passin and cl.is_active=true into client_id,client_pass;
 end;	
else  
 select cl.id,cl.pass from data.clients cl
  where cl.login=loginin and sysdata.crypt(passin,replace(cl.pass,'$2y$','$2a$'))=replace(cl.pass,'$2y$','$2a$') and cl.is_active=true into client_id,client_pass;
end if;

client_id = coalesce(client_id,0);
client_pass = coalesce(client_pass,'');

END;

$_$;


ALTER FUNCTION api.check_login_client(hash text, loginin character varying, passin character varying, hashed_pass boolean, OUT client_id integer, OUT client_pass character varying) OWNER TO postgres;

--
-- TOC entry 533 (class 1255 OID 16496)
-- Name: check_login_dispatcher(text, character varying, character varying, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.check_login_dispatcher(hash text, loginin character varying, passin character varying, hashed_pass boolean DEFAULT true, OUT dispatcher_id integer, OUT dispatcher_pass character varying) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$/*
Проверка логина/пароля диспетчера.
Возвращается id и хэш пароля. Либо 0 и ''
*/

BEGIN

dispatcher_id = 0;
dispatcher_pass = '';

if not sysdata.check_signing(hash) then
 return;
end if;

if hashed_pass then
 begin
  passin = replace(passin,'$2y$','$2a$');
   select d.id,d.pass from data.dispatchers d 
    where d.login=loginin and replace(d.pass,'$2y$','$2a$')=passin and d.is_active=true into dispatcher_id,dispatcher_pass;
 end;	
else  
 select d.id,d.pass from data.dispatchers d 
  where d.login=loginin and sysdata.crypt(passin,replace(d.pass,'$2y$','$2a$'))=replace(d.pass,'$2y$','$2a$') and d.is_active=true into dispatcher_id,dispatcher_pass;
end if;

dispatcher_id = coalesce(dispatcher_id,0);
dispatcher_pass = coalesce(dispatcher_pass,'');

END;

$_$;


ALTER FUNCTION api.check_login_dispatcher(hash text, loginin character varying, passin character varying, hashed_pass boolean, OUT dispatcher_id integer, OUT dispatcher_pass character varying) OWNER TO postgres;

--
-- TOC entry 534 (class 1255 OID 16497)
-- Name: check_login_driver(text, character varying, character varying, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.check_login_driver(hash text, loginin character varying, passin character varying, hashed_pass boolean DEFAULT true, OUT driver_id integer, OUT driver_pass character varying, OUT driver_options text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$/*
Проверка логина/пароля водителя.
Возвращается id и хэш пароля. Либо 0 и ''
*/

BEGIN

driver_id = 0;
driver_pass = '';

if not sysdata.check_signing(hash) then
 return;
end if;

if hashed_pass then
 begin
  passin = replace(passin,'$2y$','$2a$');
   select d.id,d.pass from data.drivers d 
    where d.login=loginin and replace(d.pass,'$2y$','$2a$')=passin and d.is_active=true into driver_id,driver_pass;
 end;	
else  
 select d.id,d.pass from data.drivers d 
  where d.login=loginin and sysdata.crypt(passin,replace(d.pass,'$2y$','$2a$'))=replace(d.pass,'$2y$','$2a$') and d.is_active=true into driver_id,driver_pass;
end if;

driver_id = coalesce(driver_id,0);
driver_pass = coalesce(driver_pass,'');
/*
select json_build_object(
		 'param_name',sp.param_name,
	     'param_value',case 
	                        when sp.param_value_string is not null then cast(sp.param_value_string as character varying)
							when sp.param_value_integer is not null then cast(sp.param_value_integer as character varying)
							when sp.param_value_real is not null then cast(sp.param_value_real as character varying)
						end
          ) from sysdata."SYS_PARAMS" sp 
		 where sp.param_name in ('RADIUS_TO_CHECKPOINT','MINUTES_FOR FINISH_HOURS_ORDER','MINUTES_TO_CONFIRM_ORDER')
into driver_options;
*/

select array_to_json(ARRAY( SELECT json_build_object(
		 'param_name',sp.param_name,
	     'param_value',case 
	                        when sp.param_value_string is not null then cast(sp.param_value_string as character varying)
							when sp.param_value_integer is not null then cast(sp.param_value_integer as character varying)
							when sp.param_value_real is not null then cast(sp.param_value_real as character varying)
						end
          ) from sysdata."SYS_PARAMS" sp 
		    where sp.param_name in ('RADIUS_TO_CHECKPOINT','MINUTES_FOR FINISH_HOURS_ORDER','MINUTES_TO_CONFIRM_ORDER')
		))
into driver_options;


END;

$_$;


ALTER FUNCTION api.check_login_driver(hash text, loginin character varying, passin character varying, hashed_pass boolean, OUT driver_id integer, OUT driver_pass character varying, OUT driver_options text) OWNER TO postgres;

--
-- TOC entry 535 (class 1255 OID 16498)
-- Name: client_add_bad_ga(integer, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_add_bad_ga(client_id_ integer, pass_ text, address_ text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Добавление плохого адреса.
*/
DECLARE address_id bigint default -1;
BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

insert into data.google_addresses(id,client_id,address)
        values(nextval('data.google_addresses_id_seq'),client_id_,trim(address_))
  	    on conflict do nothing																		   
		returning id into address_id;

return coalesce(address_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
END

$$;


ALTER FUNCTION api.client_add_bad_ga(client_id_ integer, pass_ text, address_ text) OWNER TO postgres;

--
-- TOC entry 536 (class 1255 OID 16499)
-- Name: client_add_ga(integer, text, text, text, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_add_ga(client_id_ integer, pass_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Добавление гугл-адреса.
*/

BEGIN

address_id = -1; 
original_id = NULL;

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

if not exists(select 1 from data.google_addresses ga where ga.client_id=client_id_ and trim(upper(ga.address))=trim(upper(address_))) then
 begin							
    select gor.id from data.google_originals gor where upper(google_address_)=upper(gor.address)
	into original_id;

	if original_id is null then
      insert into data.google_originals(id,address,latitude,longitude)
 	  values(nextval('data.google_originals_id_seq'),google_address_,latitude_,longitude_)
	  on conflict do nothing																		   
	  returning id into original_id;
    end if;		
																				   
	if original_id is null then
		return;
	else
      insert into data.google_addresses(id,client_id,address,google_original)
	              values(nextval('data.google_addresses_id_seq'),client_id_,trim(address_),original_id)
		  		  returning id into address_id;
     end if;
 end;
else
	select ga.id,ga.google_original from data.google_addresses ga where ga.client_id=client_id_ and trim(upper(ga.address))=trim(upper(address_)) 
	into address_id, original_id;
end if;

address_id = coalesce(address_id,-1);

RETURN;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
END

$$;


ALTER FUNCTION api.client_add_ga(client_id_ integer, pass_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) OWNER TO postgres;

--
-- TOC entry 537 (class 1255 OID 16500)
-- Name: client_change_active_route(integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_change_active_route(client_id_ integer, pass_ text, route_id_ integer, route_active_ boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Изменение активности маршрута.
Возвращает boolean.
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

update data.routes set active=route_active_ where id=route_id_ and client_id=client_id_;	   
 
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
  
end

$$;


ALTER FUNCTION api.client_change_active_route(client_id_ integer, pass_ text, route_id_ integer, route_active_ boolean) OWNER TO postgres;

--
-- TOC entry 538 (class 1255 OID 16501)
-- Name: client_copy_order(integer, text, bigint, timestamp without time zone); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_copy_order(client_id_ integer, pass_ text, from_order_id_ bigint, order_time_ timestamp without time zone) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Создание нового заказа из другого. Статус - 20.
Возвращает либо id, либо -1.
*/

DECLARE nw_order_id bigint default -1;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

if client_id_ <> (select o.client_id from data.orders o where o.id=from_order_id_ limit 1) then
 return -1;
end if; 

if order_time_ is null then
 order_time_ = now()::timestamp(0);
end if;
  
  insert into data.orders (id,order_time,order_title,point_id,from_addr_name,from_addr_latitude,from_addr_longitude,from_time,from_kontakt_name,from_kontakt_phone,from_notes,client_summa,summa,driver_id,dispatcher_id,client_dispatcher_id,client_id,status_id,carclass_id,hours,distance,duration,duration_calc,visible,notes)
         select nextval('data.orders_id_seq'),order_time_,o.order_title,o.point_id,o.from_addr_name,o.from_addr_latitude,o.from_addr_longitude,order_time_,o.from_kontakt_name,o.from_kontakt_phone,o.from_notes,o.client_summa,o.summa,null,o.client_dispatcher_id,o.client_dispatcher_id,client_id_,20,o.carclass_id,o.hours,o.distance,o.duration,o.duration_calc,o.visible,o.notes 
		  from data.orders o where o.id=from_order_id_
		 returning id into nw_order_id;

  insert into data.checkpoints(id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)
         select nextval('data.checkpoints_id_seq'),nw_order_id,ch.to_point_id,ch.to_addr_name,ch.to_addr_latitude,ch.to_addr_longitude,ch.to_time_to,ch.kontakt_name,ch.kontakt_phone,ch.notes,ch.distance_to,ch.duration_to,ch.position_in_order
		  from data.checkpoints ch
		 where ch.order_id=from_order_id_;

insert into data.order_log(id,order_id,client_id,datetime,status_new,action_string)
values (nextval('data.order_log_id_seq'),nw_order_id,client_id_,CURRENT_TIMESTAMP,20,'Copy from '||from_order_id_) 
on conflict do nothing;


return coalesce(nw_order_id,-1);

end

$$;


ALTER FUNCTION api.client_copy_order(client_id_ integer, pass_ text, from_order_id_ bigint, order_time_ timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 539 (class 1255 OID 16502)
-- Name: client_create_order(integer, text, timestamp without time zone, character varying, integer, character varying, numeric, numeric, timestamp without time zone, date, character varying, character varying, character varying, numeric, integer, integer, integer, real, integer, character varying, boolean, jsonb, boolean, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_create_order(client_id_ integer, pass_ text, order_time_ timestamp without time zone, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, visible_ boolean, checkpoints_ jsonb, free_sum_ boolean, draft boolean) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Создание нового заказа. Статус - 20/30.
Возвращает либо id, либо -1.
*/

DECLARE nw_order_id bigint default -1;
DECLARE checkpoints_count integer;

declare ch_to_point_id integer;
declare ch_to_addr_name text;
declare ch_to_addr_latitude numeric;
declare ch_to_addr_longitude numeric;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;
declare ch_distance_to real;
declare ch_duration_to integer;
declare ch_to_time_to timestamp without time zone;

declare calc_status_id integer default 0;
declare driver_summa numeric;
declare perc numeric default 0;
declare route_checkpoint_duration integer default 0;
declare route_load_duration integer default 0;
declare int_num integer;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

if order_time_ is null then
 order_time_ = now()::timestamp(0);
end if;

checkpoints_count = jsonb_array_length(checkpoints_);
  
  select o.perc_agg,o.route_checkpoint_duration,o.route_load_duration from laravel.mab_aggregator_options o where o.id=1 
   into perc,route_checkpoint_duration,route_load_duration;
   
--   int_num = summa_ * (100-perc)/100;/* /10;
--   int_num = int_num*10;*/
   driver_summa = summa_;
   
  insert into data.orders (id,order_time,order_title,point_id,from_addr_name,from_addr_latitude,from_addr_longitude,from_time,doc_date,from_kontakt_name,from_kontakt_phone,from_notes,client_summa,summa,driver_id,dispatcher_id,client_dispatcher_id,client_id,status_id,carclass_id,hours,distance,duration,duration_calc,visible,notes,free_sum)
         values (nextval('data.orders_id_seq'),order_time_,order_title_,case from_point_id_ when 0 then null else from_point_id_ end,from_addr_name_,from_addr_latitude_,from_addr_longitude_,from_time_,doc_date_,from_kontakt_name_,from_kontakt_phone_,from_notes_,summa_,driver_summa,null,dispatcher_id_,dispatcher_id_,client_id_,case draft when true then 20 else 30 end,carclass_id_,hours_,distance_,duration_,(duration_+checkpoints_count*route_checkpoint_duration+route_load_duration),visible_,notes_,free_sum_) 
		 returning id into nw_order_id;

  /* add history */
  insert into data.order_history (id,client_id,order_title,point_id,from_name,summa,latitude,longitude) 
		  values (nextval('data.order_history_id_seq'),client_id_,order_title_,case from_point_id_ when 0 then null else from_point_id_ end,from_addr_name_,summa_,from_addr_latitude_,from_addr_longitude_) 
          on conflict do nothing;

  
  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_point_id = cast(checkpoints_->i->>'to_point_id' as integer);
	if ch_to_point_id = 0 then
	 ch_to_point_id = null;
	end if;
    ch_to_addr_name = cast(checkpoints_->i->>'to_addr_name' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'to_addr_latitude' as numeric);
    ch_to_addr_longitude = cast(checkpoints_->i->>'to_addr_longitude' as numeric);
    ch_kontakt_name = cast(checkpoints_->i->>'kontakt_name' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'kontakt_phone' as text);
    ch_notes = cast(checkpoints_->i->>'to_notes' as text);
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);

    insert into data.checkpoints (id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),nw_order_id,
			 ch_to_point_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 ch_distance_to,
			 ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,point_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_point_id,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

insert into data.order_log(id,order_id,client_id,datetime,status_new,action_string)
values (nextval('data.order_log_id_seq'),nw_order_id,client_id_,CURRENT_TIMESTAMP,30,'Create') 
on conflict do nothing;

return coalesce(nw_order_id,-1);

end

$$;


ALTER FUNCTION api.client_create_order(client_id_ integer, pass_ text, order_time_ timestamp without time zone, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, visible_ boolean, checkpoints_ jsonb, free_sum_ boolean, draft boolean) OWNER TO postgres;

--
-- TOC entry 540 (class 1255 OID 16504)
-- Name: client_del_ga(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_del_ga(client_id_ integer, pass_ text, address_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Удаление своего гугл-адреса.
Возвращает либо true, либо false.
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.google_addresses where id=address_id_ and client_id=client_id_) then
 begin
  delete from data.google_addresses where id=address_id_ and client_id=client_id_;
  return true;
 end;
end if; 

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$$;


ALTER FUNCTION api.client_del_ga(client_id_ integer, pass_ text, address_id_ bigint) OWNER TO postgres;

--
-- TOC entry 541 (class 1255 OID 16505)
-- Name: client_del_point(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_del_point(client_id_ integer, pass_ text, point_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Удаление точки.
Возвращает либо true/false
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.client_points cp where cp.client_id=client_id_ and cp.id=point_id_) then
 begin
  delete from data.client_points where id=point_id_;
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
end

$$;


ALTER FUNCTION api.client_del_point(client_id_ integer, pass_ text, point_id_ integer) OWNER TO postgres;

--
-- TOC entry 542 (class 1255 OID 16506)
-- Name: client_del_point_coordinate(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_del_point_coordinate(client_id_ integer, pass_ text, coord_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Удаление координат.
Возвращает либо true/false
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.client_point_coordinates cpc where cpc.id=coord_id_ and client_id_=(select cp.client_id from data.client_points cp where cp.id=cpc.point_id)) then
 begin
  delete from data.client_point_coordinates where id=coord_id_ and client_id_=(select cp.client_id from data.client_points cp where cp.id=client_point_coordinates.point_id);
  return true;
 end;
end if;

return false;

--EXCEPTION
--WHEN OTHERS THEN 
--  RETURN false;
  
end

$$;


ALTER FUNCTION api.client_del_point_coordinate(client_id_ integer, pass_ text, coord_id_ integer) OWNER TO postgres;

--
-- TOC entry 543 (class 1255 OID 16507)
-- Name: client_del_route(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_del_route(client_id_ integer, pass_ text, route_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Удаление маршрута.
Возвращает либо true/false
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.routes r where r.client_id=client_id_ and r.id=route_id_) then
 begin
  delete from data.routes where id=route_id_;
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
end

$$;


ALTER FUNCTION api.client_del_route(client_id_ integer, pass_ text, route_id_ integer) OWNER TO postgres;

--
-- TOC entry 545 (class 1255 OID 16508)
-- Name: client_edit_address_modifier(integer, text, bigint, bigint, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_address_modifier(client_id_ integer, pass_ text, address_id_ bigint, edit_id_ bigint, latitude_ numeric, longitude_ numeric) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Редактирование/добавление модификатора гугл-адреса.
Возвращает либо id, либо -1.
*/
DECLARE edit_id integer default -1;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

if coalesce(edit_id_,0)>0 then
  update data.google_modifiers set latitude=latitude_,
				   longitude=longitude_
	 where id=edit_id_ and client_id=client_id_
	 returning id into edit_id;	   
else
   insert into data.google_modifiers (id,client_id,original_id,latitude,longitude)
   values (nextval('data.google_modifiers_id_seq'),client_id_,(select ga.google_original from data.google_addresses ga where ga.id=address_id_ and ga.client_id=client_id_),latitude_,longitude_) 
   returning id into edit_id;
end if;

return coalesce(edit_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.client_edit_address_modifier(client_id_ integer, pass_ text, address_id_ bigint, edit_id_ bigint, latitude_ numeric, longitude_ numeric) OWNER TO postgres;

--
-- TOC entry 546 (class 1255 OID 16509)
-- Name: client_edit_checkpoints(integer, text, bigint, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_checkpoints(client_id_ integer, pass_ text, order_id_ bigint, checkpoints_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Редактирование чекпойнтов заказа. Проверка, что статус не больше 60.
Возвращает либо true/false
*/

declare client_id integer default 0;
declare status_id integer default -1;

DECLARE checkpoints_count integer;

declare ch_to_point_id integer;
declare ch_to_addr_name text;
declare ch_to_addr_latitude numeric;
declare ch_to_addr_longitude numeric;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

SELECT o.client_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into client_id,status_id;
  
if client_id<>client_id_ or status_id>60 then /* только не выполняемые */
 return false;
end if;


  checkpoints_count = jsonb_array_length(checkpoints_);
if checkpoints_count>0 then
 update data.orders set hours = null where id = order_id_;
end if; 
  
 /* delete old checkpoints */
  delete from data.checkpoints ch where ch.order_id = order_id_;
  
  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_point_id = cast(checkpoints_->i->>'to_point_id' as integer);
	if ch_to_point_id = 0 then
	 ch_to_point_id = null;
	end if;
	ch_to_addr_name = cast(checkpoints_->i->>'to_addr_name' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'to_addr_latitude' as numeric);
    ch_to_addr_longitude = cast(checkpoints_->i->>'to_addr_longitude' as numeric);
    ch_kontakt_name = cast(checkpoints_->i->>'kontakt_name' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'kontakt_phone' as text);
    ch_notes = cast(checkpoints_->i->>'to_notes' as text);
	/*
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);
	*/

    insert into data.checkpoints (id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),order_id_,
			 ch_to_point_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 null, --ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 null, --ch_distance_to,
			 null, --ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,point_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_point_id,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

insert into data.order_log(id,order_id,client_id,datetime,action_string)
values (nextval('data.order_log_id_seq'),order_id_,client_id_,CURRENT_TIMESTAMP,'Edit checkpoints') 
on conflict do nothing;

return true;

end

$$;


ALTER FUNCTION api.client_edit_checkpoints(client_id_ integer, pass_ text, order_id_ bigint, checkpoints_ jsonb) OWNER TO postgres;

--
-- TOC entry 547 (class 1255 OID 16510)
-- Name: client_edit_client(integer, text, character varying, character varying, character varying, character varying, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_client(client_id_ integer, pass_ text, client_name_ character varying, client_email_ character varying, client_pass_ character varying, client_def_load_ character varying, client_def_load_lat_ numeric, client_def_load_lng_ numeric) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Редактирование себя клиентом.
Возвращает либо true/false.
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
  return false;
end if;
 
 if client_pass_='' then
   client_pass_ = pass_;
 end if;
 
  update data.clients set name=client_name_,
                   email=client_email_,
	               password=client_pass_,
				   default_load_address=client_def_load_,
				   default_load_latitude=client_def_load_lat_,
				   default_load_longitude=client_def_load_lng_
	 where id=client_id_;	   
	 

return true;

end

$$;


ALTER FUNCTION api.client_edit_client(client_id_ integer, pass_ text, client_name_ character varying, client_email_ character varying, client_pass_ character varying, client_def_load_ character varying, client_def_load_lat_ numeric, client_def_load_lng_ numeric) OWNER TO postgres;

--
-- TOC entry 548 (class 1255 OID 16511)
-- Name: client_edit_ga(integer, text, bigint, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_ga(client_id_ integer, pass_ text, id_ bigint, google_original_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Коррекция гугл-адреса.
Возвращает либо true/false.
*/
begin

if sysdata.check_id_client(client_id_,pass_)<1 then
  return false;
end if;
 
  update data.google_addresses set google_original=google_original_id_
	 where id=id_ and client_id=client_id_;	   
	 

return true;

end

$$;


ALTER FUNCTION api.client_edit_ga(client_id_ integer, pass_ text, id_ bigint, google_original_id_ bigint) OWNER TO postgres;

--
-- TOC entry 549 (class 1255 OID 16512)
-- Name: client_edit_order(integer, text, bigint, character varying, integer, character varying, numeric, numeric, timestamp without time zone, date, character varying, character varying, character varying, numeric, integer, integer, integer, real, integer, character varying, boolean, jsonb, boolean, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_order(client_id_ integer, pass_ text, order_id_ bigint, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, visible_ boolean, checkpoints_ jsonb, free_sum_ boolean, order_mode_ boolean) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Редактирование заказа. Проверка, что статус не в дороге.
Возвращает либо id, либо -1.
*/

DECLARE res_order_id bigint default -1;
declare client_id integer default 0;
declare status_id integer default -1;
declare change_status_from_draft boolean default false;

DECLARE checkpoints_count integer;

declare ch_to_point_id integer;
declare ch_to_addr_name text;
declare ch_to_addr_latitude numeric;
declare ch_to_addr_longitude numeric;
declare ch_kontakt_name text;
declare ch_kontakt_phone text;
declare ch_notes text;
declare ch_distance_to real;
declare ch_duration_to integer;
declare ch_to_time_to timestamp without time zone;

declare driver_summa numeric;
declare route_checkpoint_duration integer default 0;
declare route_load_duration integer default 0;
declare perc numeric default 0;
declare int_num integer;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

SELECT o.client_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into client_id,status_id;
  
if client_id<>client_id_ or status_id>=110 then /* только не выполняемые */
 return -1;
end if;

if status_id<30 and order_mode_ then
  change_status_from_draft = true;
end if; 

  checkpoints_count = jsonb_array_length(checkpoints_);
  
  select o.perc_agg,o.route_checkpoint_duration,o.route_load_duration from laravel.mab_aggregator_options o where o.id=1 
   into perc,route_checkpoint_duration,route_load_duration;
   
--   int_num = summa_ * (100-perc)/100;/* /10;
--   int_num = int_num*10;*/
   driver_summa = summa_;

if change_status_from_draft then
	UPDATE data.orders set order_title = order_title_,
						   point_id = case from_point_id_ when 0 then null else from_point_id_ end,
						   from_addr_name = from_addr_name_,
						   from_addr_latitude = from_addr_latitude_,
						   from_addr_longitude = from_addr_longitude_,
						   from_time = from_time_,
						   doc_date = doc_date_,
						   from_kontakt_name = from_kontakt_name_,
						   from_kontakt_phone = from_kontakt_phone_,
						   from_notes = from_notes_,
						   client_summa = summa_,
						   summa = driver_summa,
						   dispatcher_id = dispatcher_id_,
						   --client_dispatcher_id = dispatcher_id,
						   carclass_id = carclass_id_,
						   hours = hours_,
						   distance = distance_,
						   duration = duration_,
						   duration_calc = (duration_+checkpoints_count*route_checkpoint_duration+route_load_duration),
						   visible = visible_,
						   notes = notes_,
						   free_sum = free_sum_,
						   status_id = 30
		  WHERE id = order_id_ 
		  RETURNING ID INTO res_order_id; 
else
	UPDATE data.orders set order_title = order_title_,
						   point_id = case from_point_id_ when 0 then null else from_point_id_ end,
						   from_addr_name = from_addr_name_,
						   from_addr_latitude = from_addr_latitude_,
						   from_addr_longitude = from_addr_longitude_,
						   from_time = from_time_,
						   doc_date = doc_date_,
						   from_kontakt_name = from_kontakt_name_,
						   from_kontakt_phone = from_kontakt_phone_,
						   from_notes = from_notes_,
						   client_summa = summa_,
						   summa = driver_summa,
						   dispatcher_id = dispatcher_id_,
						   --client_dispatcher_id = dispatcher_id,
						   carclass_id = carclass_id_,
						   hours = hours_,
						   distance = distance_,
						   duration = duration_,
						   duration_calc = (duration_+checkpoints_count*route_checkpoint_duration+route_load_duration),
						   visible = visible_,
						   notes = notes_,
						   free_sum = free_sum_
		  WHERE id = order_id_ 
		  RETURNING ID INTO res_order_id; 
end if;

  /* add history */
  insert into data.order_history (id,client_id,order_title,point_id,from_name,summa,latitude,longitude) 
		  values (nextval('data.order_history_id_seq'),client_id_,order_title_,case from_point_id_ when 0 then null else from_point_id_ end,from_addr_name_,summa_,from_addr_latitude_,from_addr_longitude_) 
          on conflict do nothing;

 /* delete old checkpoints */
  delete from data.checkpoints ch where ch.order_id = res_order_id;
  
  FOR i IN 0..(checkpoints_count-1) LOOP
   begin
    ch_to_point_id = cast(checkpoints_->i->>'to_point_id' as integer);
	if ch_to_point_id = 0 then
	 ch_to_point_id = null;
	end if;
	ch_to_addr_name = cast(checkpoints_->i->>'to_addr_name' as text);
    ch_to_addr_latitude = cast(checkpoints_->i->>'to_addr_latitude' as numeric);
    ch_to_addr_longitude = cast(checkpoints_->i->>'to_addr_longitude' as numeric);
    ch_kontakt_name = cast(checkpoints_->i->>'kontakt_name' as text);
    ch_kontakt_phone = cast(checkpoints_->i->>'kontakt_phone' as text);
    ch_notes = cast(checkpoints_->i->>'to_notes' as text);
    ch_distance_to = cast(checkpoints_->i->>'distance_to' as real);
    ch_duration_to = cast(checkpoints_->i->>'duration_to' as integer);
	ch_to_time_to = cast(checkpoints_->i->>'to_time_to' as timestamp without time zone);

    insert into data.checkpoints (id,order_id,to_point_id,to_addr_name,to_addr_latitude,to_addr_longitude,to_time_to,kontakt_name,kontakt_phone,notes,distance_to,duration_to,position_in_order)  
	  values(nextval('data.checkpoints_id_seq'),res_order_id,
			 ch_to_point_id,
			 ch_to_addr_name,
			 ch_to_addr_latitude,
			 ch_to_addr_longitude,
			 ch_to_time_to,
			 ch_kontakt_name,
			 ch_kontakt_phone,
			 ch_notes,
			 ch_distance_to,
			 ch_duration_to,
			 i+1);
	 
		 insert into data.checkpoint_history (id,client_id,point_id,name,latitude,longitude,kontakt_name,kontakt_phone,notes) 
		  values (nextval('data.checkpoint_history_id_seq'),client_id_,ch_to_point_id,ch_to_addr_name,ch_to_addr_latitude,ch_to_addr_longitude,ch_kontakt_name,ch_kontakt_phone,ch_notes) 
          on conflict do nothing;	 		  
	end; /* for */ 
  END LOOP;

if change_status_from_draft then 
  insert into data.order_log(id,order_id,client_id,datetime,status_old,status_new)
  values (nextval('data.order_log_id_seq'),res_order_id,client_id_,CURRENT_TIMESTAMP,status_id,30) 
  on conflict do nothing;
end if;  

insert into data.order_log(id,order_id,client_id,datetime,action_string)
values (nextval('data.order_log_id_seq'),res_order_id,client_id_,CURRENT_TIMESTAMP,'Edit') 
on conflict do nothing;

return coalesce(res_order_id,-1);

end

$$;


ALTER FUNCTION api.client_edit_order(client_id_ integer, pass_ text, order_id_ bigint, order_title_ character varying, from_point_id_ integer, from_addr_name_ character varying, from_addr_latitude_ numeric, from_addr_longitude_ numeric, from_time_ timestamp without time zone, doc_date_ date, from_kontakt_name_ character varying, from_kontakt_phone_ character varying, from_notes_ character varying, summa_ numeric, dispatcher_id_ integer, carclass_id_ integer, hours_ integer, distance_ real, duration_ integer, notes_ character varying, visible_ boolean, checkpoints_ jsonb, free_sum_ boolean, order_mode_ boolean) OWNER TO postgres;

--
-- TOC entry 550 (class 1255 OID 16514)
-- Name: client_edit_point(integer, text, integer, character varying, character varying, text, character varying, bigint, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_point(client_id_ integer, pass_ text, point_id_ integer, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Редактирование/добавление точки.
Возвращает либо id, либо -1.
*/
DECLARE point_id integer default -1;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

if coalesce(point_id_,0)>0 then
 begin

  update data.client_points set name=point_name_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where id=point_id_ and client_id=client_id_
	 returning id into point_id;	   
	 
 end;
else
 begin
  if exists(select 1 from data.client_points cp where cp.client_id=client_id_ and cp.code=point_code_) then 
     update data.client_points set name=point_name_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where code=point_code_ and client_id=client_id_
	 returning id into point_id;	   
  else 
   insert into data.client_points (id,client_id,name,address,description,code,visible,google_original)
         values (nextval('data.client_points_id_seq'),client_id_,point_name_,point_address_,point_description_,point_code_,point_visible_,google_original_id_) 
		 returning id into point_id;
  end if;
		 
 end;
end if;

return coalesce(point_id,-1);

--EXCEPTION
--WHEN OTHERS THEN 
--  RETURN -1;
  
end

$$;


ALTER FUNCTION api.client_edit_point(client_id_ integer, pass_ text, point_id_ integer, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) OWNER TO postgres;

--
-- TOC entry 552 (class 1255 OID 16515)
-- Name: client_edit_point_coordinates(integer, text, integer, integer, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_point_coordinates(client_id_ integer, pass_ text, point_id_ integer, edit_id_ integer, latitude_ numeric, longitude_ numeric) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Редактирование/добавление дополнительных координат точки.
Возвращает либо id, либо -1.
*/
DECLARE edit_id integer default -1;

begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return -1;
end if;

if coalesce(edit_id_,0)>0 then
  update data.client_point_coordinates set latitude=latitude_,
				   longitude=longitude_
	 where id=edit_id_ and client_id_=(select cp.client_id from data.client_points cp where cp.id=client_point_coordinates.point_id)
	 returning id into edit_id;	   
else
   insert into data.client_point_coordinates (id,point_id,latitude,longitude)
   values (nextval('data.client_point_coordinates_id_seq'),point_id_,latitude_,longitude_) 
   returning id into edit_id;
end if;

return coalesce(edit_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.client_edit_point_coordinates(client_id_ integer, pass_ text, point_id_ integer, edit_id_ integer, latitude_ numeric, longitude_ numeric) OWNER TO postgres;

--
-- TOC entry 553 (class 1255 OID 16516)
-- Name: client_edit_route(integer, text, integer, text, numeric, text, boolean, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_route(client_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_sum_ numeric, route_description_ text, route_active_ boolean, route_type_ integer, OUT route_id integer, OUT updated boolean) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Редактирование/добавление маршрута.
Возвращает либо id, либо -1 и updated = true/false
*/

begin

route_id = -1;
updated = false;

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

if coalesce(route_id_,0)>0 then
 begin
  updated = true;
  update data.routes set name=route_name_,
                   summa=route_sum_,
				   description=route_description_,
				   active=route_active_,
				   type_id = route_type_
	 where id=route_id_ and client_id=client_id_
	 returning id into route_id;	   
	 
 end;
else
 begin
  if exists(select 1 from data.routes r where r.client_id=client_id_ and upper(r.name)=upper(route_name_)) then 
	begin																						 
	  updated = true;																							 
      update data.routes set name=route_name_,
                   summa=route_sum_,
				   description=route_description_,
				   active=route_active_,
				   type_id = route_type_
	  where upper(name)=upper(route_name_) and client_id=client_id_
	  returning id into route_id;	   
    end;																							 
  else
   begin																							  
     updated = false;																							 
     insert into data.routes (id,client_id,name,summa,description,active,type_id)
         values (nextval('data.routes_id_seq'),client_id_,route_name_,route_sum_,route_description_,route_active_,route_type_) 
		 returning id into route_id;
    end;																							 
  end if;
		 
 end;
end if;

route_id = coalesce(route_id,-1);

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
  
end

$$;


ALTER FUNCTION api.client_edit_route(client_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_sum_ numeric, route_description_ text, route_active_ boolean, route_type_ integer, OUT route_id integer, OUT updated boolean) OWNER TO postgres;

--
-- TOC entry 554 (class 1255 OID 16517)
-- Name: client_edit_route(integer, text, integer, text, numeric, text, boolean, integer, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_edit_route(client_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_sum_ numeric, route_description_ text, route_active_ boolean, route_type_ integer, route_restrictions_ jsonb, OUT route_id integer, OUT updated boolean) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Редактирование/добавление маршрута.
Возвращает либо id, либо -1 и updated = true/false
*/

begin

route_id = -1;
updated = false;

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

if coalesce(route_id_,0)>0 then
 begin
  updated = true;
  update data.routes set name=route_name_,
                   summa=route_sum_,
				   description=route_description_,
				   active=route_active_,
				   type_id = route_type_,
				   restrictions = route_restrictions_
	 where id=route_id_ and client_id=client_id_
	 returning id into route_id;	   
	 
 end;
else
 begin
  if exists(select 1 from data.routes r where r.client_id=client_id_ and upper(r.name)=upper(route_name_)) then 
	begin																						 
	  updated = true;																							 
      update data.routes set name=route_name_,
                   summa=route_sum_,
				   description=route_description_,
				   active=route_active_,
				   type_id = route_type_,
				   restrictions = route_restrictions_
	  where upper(name)=upper(route_name_) and client_id=client_id_
	  returning id into route_id;	   
    end;																							 
  else
   begin																							  
     updated = false;																							 
     insert into data.routes (id,client_id,name,summa,description,active,type_id,restrictions)
         values (nextval('data.routes_id_seq'),client_id_,route_name_,route_sum_,route_description_,route_active_,route_type_,route_restrictions_) 
		 returning id into route_id;
    end;																							 
  end if;
		 
 end;
end if;

route_id = coalesce(route_id,-1);

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
  
end

$$;


ALTER FUNCTION api.client_edit_route(client_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_sum_ numeric, route_description_ text, route_active_ boolean, route_type_ integer, route_restrictions_ jsonb, OUT route_id integer, OUT updated boolean) OWNER TO postgres;

--
-- TOC entry 555 (class 1255 OID 16518)
-- Name: client_finish_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_finish_order(order_id_ bigint, client_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Окончательное завершение заказа. 
*/ 
DECLARE order_id BIGINT;
DECLARE order_client_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.client_id,coalesce(o.status_id,0) FROM data.orders o 
   where o.id=order_id_ FOR UPDATE
   into order_id,order_client_id,curr_status_id;

  IF order_id is null 
  or curr_status_id<>120 /* Заказ выполнен водителем */ 
  or order_client_id<>client_id_ 
  THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id=150 /* Заказ завершен окончательно */
						where id=order_id_;

     insert into data.order_log(id,order_id,client_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,order_client_id,CURRENT_TIMESTAMP,150,curr_status_id,'End') 
     on conflict do nothing;
	 
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.client_finish_order(order_id_ bigint, client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 556 (class 1255 OID 16519)
-- Name: client_get_client(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_get_client(client_id_ integer, pass_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Просмотр своих данных.
*/
BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return '';
end if;

RETURN
 (select json_build_object(
		 'id',cl.id,
	     'name',cl.name,
		 'email',cl.email,
		 'default_dispatcher_id',cl.default_dispatcher_id,
	     'default_dispatcher_name',d.name,
	 	 'default_load_address',cl.default_load_address,
	 	 'default_load_latitude',cl.default_load_latitude,
	 	 'default_load_longitude',cl.default_load_longitude,	 
	     'token',cl.token)
 from data.clients cl
 left join data.dispatchers d on d.id=cl.default_dispatcher_id
 where cl.id=client_id_);


END

$$;


ALTER FUNCTION api.client_get_client(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 557 (class 1255 OID 16520)
-- Name: client_get_driver_position(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_get_driver_position(client_id_ integer, pass_ text, order_id_ bigint, OUT latitude numeric, OUT longitude numeric, OUT mark_time timestamp without time zone) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр координат водителя по заказу.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

latitude = 0;
longitude = 0;
select dcl.latitude,dcl.longitude,dcl.loc_time from data.driver_current_locations dcl 
 where dcl.driver_id = (select o.driver_id from data.orders o where o.id=order_id_ and o.client_id=client_id_)
into latitude,longitude,mark_time;

END

$$;


ALTER FUNCTION api.client_get_driver_position(client_id_ integer, pass_ text, order_id_ bigint, OUT latitude numeric, OUT longitude numeric, OUT mark_time timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 558 (class 1255 OID 16521)
-- Name: client_get_ga(integer, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_get_ga(client_id_ integer, pass_ text, address_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Просмотр координат водителя по адресу.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return '';
end if;

return (select json_build_object(
		 'address_id',ga.id,
	     'point_id',cp.id,
	     'point_code',cp.code,
	     'original_id',ga.google_original,
	     'latitude',coalesce(gm.latitude,gor.latitude),
	     'longitude',coalesce(gm.longitude,gor.longitude))
 from data.google_addresses ga
 left join data.google_originals gor on ga.google_original=gor.id	
 left join data.google_modifiers gm on gm.original_id=gor.id and gm.client_id=ga.client_id
 left join data.client_points cp on cp.google_original=gor.id and cp.client_id=client_id_
 where ga.client_id=client_id_ and trim(upper(address_))=trim(upper(ga.address)) LIMIT 1);

END

$$;


ALTER FUNCTION api.client_get_ga(client_id_ integer, pass_ text, address_ text) OWNER TO postgres;

--
-- TOC entry 559 (class 1255 OID 16522)
-- Name: client_get_order(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_get_order(client_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT json_checkpoints text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Просмотр заказа.
*/
BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

select json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'from_time',o.from_time,
		 'doc_date',coalesce(o.doc_date,o.from_time::date),
		 'point_id',o.point_id,
		 'point_name',p.name,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
	     'from_addr_longitude',o.from_addr_longitude,
	     'from_kontakt_name',o.from_kontakt_name,
	     'from_kontakt_phone',o.from_kontakt_phone,
	     'from_notes',o.from_notes,
	     'summa',o.client_summa,
		 'dispatcher_id',o.dispatcher_id,
	     'dispatcher_name',dsp.name,	
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'paytype_id',coalesce(o.paytype_id,0),
		 'hours',coalesce(o.hours,0),
		 'client_id',o.client_id,
		 'client_dispatcher_id',o.client_dispatcher_id,
		 'client_code',o.client_code,
	     'driver_car_attribs',o.driver_car_attribs,
		 'is_deleted',o.is_deleted,
		 'del_time',o.del_time,
		 'distance',o.distance,
		 'duration',o.duration,
		 'duration_calc',o.duration_calc,
		 'notes',o.notes,
		 'visible',o.visible,
         'free_sum',o.free_sum)
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
/* left join sysdata."SYS_CARTYPES" ct on ct.id=o.driver_cartype_id
 left join sysdata."SYS_CARCLASSES" cc on cc.id=ct.class_id*/
 left join data.drivers d on d.id=o.driver_id
 left join data.dispatchers dsp on dsp.id=o.dispatcher_id
   where o.id=order_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'order_id',c.order_id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'to_notes',c.notes,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = order_id_
		  ORDER BY c.position_in_order)) 
		  into json_checkpoints;

END

$$;


ALTER FUNCTION api.client_get_order(client_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT json_checkpoints text) OWNER TO postgres;

--
-- TOC entry 560 (class 1255 OID 16523)
-- Name: client_get_point(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_get_point(client_id_ integer, pass_ text, point_id_ integer, OUT json_data text, OUT json_coordinates text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр точки.
*/
BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

select json_build_object(
		 'id',cp.id,
	     'name',cp.name,
		 'address',cp.address,
		 'google_original',cp.google_original,
		 'latitude',gor.latitude,
		 'longitude',gor.longitude,
		 'description',cp.description,
	     'code',cp.code,
		 'visible',coalesce(cp.visible,true))
 from data.client_points cp 
 left join data.google_originals gor on gor.id=cp.google_original							
 where cp.id=point_id_ and cp.client_id=client_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',cpc.id,
									   'latitude',cpc.latitude,
									   'longitude',cpc.longitude)
          FROM data.client_point_coordinates cpc
		  left join data.client_points cp on cpc.point_id=cp.id
          WHERE cpc.point_id = point_id_ and cp.client_id=client_id_
		  ORDER BY cpc.id)) 
		  into json_coordinates;

END

$$;


ALTER FUNCTION api.client_get_point(client_id_ integer, pass_ text, point_id_ integer, OUT json_data text, OUT json_coordinates text) OWNER TO postgres;

--
-- TOC entry 561 (class 1255 OID 16524)
-- Name: client_order2draft(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_order2draft(client_id_ integer, pass_ text, order_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается клиентом.
Изменение статуса на черновик (20). Проверка, что статус 30.
Возвращает либо true/false.
*/

declare client_id integer default 0;
declare dispatcher_id integer default 0;
declare status_id integer default -1;
declare are_selected boolean default false;


begin

if sysdata.check_id_client(client_id_,pass_)<1 then
 return false;
end if;

SELECT o.client_id,o.dispatcher_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into client_id,dispatcher_id,status_id;

if status_id=20 then
 return true;
end if;

if client_id<>client_id_ or coalesce(dispatcher_id,0)>0 or status_id<>30 then /* только новые */
 return false;
end if;

select dso.is_active from data.dispatcher_selected_orders dso 
where dso.order_id=order_id_ and dso.is_active limit 1 FOR UPDATE
into are_selected;
are_selected = coalesce(are_selected,false);

if are_selected then /* есть уже в работе */
 return false;
end if;

UPDATE data.orders set status_id = 20 WHERE id = order_id_; 

insert into data.order_log(id,order_id,client_id,datetime,status_old,status_new)
values (nextval('data.order_log_id_seq'),order_id_,client_id_,CURRENT_TIMESTAMP,30,20) 
on conflict do nothing;

return true;

end

$$;


ALTER FUNCTION api.client_order2draft(client_id_ integer, pass_ text, order_id_ bigint) OWNER TO postgres;

--
-- TOC entry 562 (class 1255 OID 16525)
-- Name: client_restore_ga(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_restore_ga(client_id_ integer, pass_ text, edit_id_ bigint, OUT success integer, OUT latitude numeric, OUT longitude numeric) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Восстановление оригинальных координат (удаление правок).
Возвращает либо true, либо false.
*/

DECLARE address_id bigint default 0;
begin

success = 0;

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;


if exists(select 1 from data.google_modifiers where id=edit_id_ and client_id=client_id_) then
 begin
  select gor.latitude,gor.longitude from data.google_originals gor 
   where id=(select original_id from data.google_modifiers gm where id=edit_id_ and client_id=client_id_)
   into latitude,longitude;
  
   delete from data.google_modifiers where id=edit_id_ and client_id=client_id_;
   success = 1;
   return;
 end;
end if; 

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION api.client_restore_ga(client_id_ integer, pass_ text, edit_id_ bigint, OUT success integer, OUT latitude numeric, OUT longitude numeric) OWNER TO postgres;

--
-- TOC entry 563 (class 1255 OID 16526)
-- Name: client_view_dispatchers(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_dispatchers(client_id_ integer, pass_ text) RETURNS TABLE(dispatcher_id integer, dispatcher_name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр всех диспетчеров.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT d.id,d.name
   FROM data.dispatchers d
   WHERE (d.is_active);
  
END

$$;


ALTER FUNCTION api.client_view_dispatchers(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 564 (class 1255 OID 16527)
-- Name: client_view_google_addresses(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_google_addresses(client_id_ integer, pass_ text) RETURNS TABLE(id bigint, address text, google_address_id bigint, google_address text, latitude numeric, longitude numeric, edit_id bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр своих google-адресов.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT ga.id,
	ga.address,
	gor.id as google_address_id,
	gor.address as google_address,
	coalesce(gm.latitude,gor.latitude),	
	coalesce(gm.longitude,gor.longitude),	
	coalesce(gm.id,0)
   FROM data.google_addresses ga
   left join data.google_originals gor on ga.google_original=gor.id
   left join data.google_modifiers gm on gm.original_id=gor.id and gm.client_id=ga.client_id
  WHERE (ga.client_id = client_id_);
  
END

$$;


ALTER FUNCTION api.client_view_google_addresses(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 565 (class 1255 OID 16528)
-- Name: client_view_link_dispatchers(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_link_dispatchers(client_id_ integer, pass_ text) RETURNS TABLE(dispatcher_id integer, dispatcher_name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается клиентом.
Просмотр всех связанных диспетчеров.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT l.dispatcher_id,
	d.name
   FROM data.dispatcher_to_client l
   LEFT JOIN data.dispatchers d ON d.id=l.dispatcher_id
  WHERE (l.client_id = client_id_);
  
END

$$;


ALTER FUNCTION api.client_view_link_dispatchers(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 566 (class 1255 OID 16529)
-- Name: client_view_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_orders(client_id_ integer, pass_ text) RETURNS TABLE(id bigint, order_time timestamp without time zone, order_title character varying, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, dispatcher_name character varying, carclass_id integer, carclass_name character varying, paytype_id integer, paytype_name character varying, is_deleted boolean, distance real, duration integer, duration_calc integer, visible boolean, notes character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр всех заказов по клиенту.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.order_title,	
	o.from_time,
	o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
/*    ARRAY( SELECT c.to_addr_name
           FROM data.checkpoints c
          WHERE c.order_id = o.id) AS to_addr_names,*/
    o.client_summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	disp.name,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.paytype_id,
	coalesce(pt.name,'Любой'),
	o.is_deleted,
	o.distance,
	o.duration,
	o.duration_calc,
	o.visible,
    o.notes
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.dispatchers disp ON disp.id=o.dispatcher_id			  
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
   LEFT JOIN sysdata."SYS_PAYTYPES" pt ON pt.id=o.paytype_id
  WHERE (o.client_id = client_id_);
  
END

$$;


ALTER FUNCTION api.client_view_orders(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 567 (class 1255 OID 16530)
-- Name: client_view_points(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_points(client_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, address character varying, google_original bigint, latitude numeric, longitude numeric, description text, code character varying, visible boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр всех мест.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT cp.id,
	cp.name,
	cp.address,	
	cp.google_original,
    gor.latitude,
    gor.longitude,
    cp.description,
    cp.code,
	coalesce(cp.visible,true)
   FROM data.client_points cp
   LEFT JOIN data.google_originals gor on gor.id=cp.google_original
   WHERE (cp.client_id = client_id_);
  
END

$$;


ALTER FUNCTION api.client_view_points(client_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 568 (class 1255 OID 16531)
-- Name: client_view_routes(integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.client_view_routes(client_id_ integer, pass_ text, code_ character varying) RETURNS TABLE(id integer, name text, summa numeric, description text, active boolean, type_id integer, type_name text, type_difficulty numeric, restrictions jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр всех маршрутов.
*/

BEGIN

if sysdata.check_id_client(client_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT r.id,
	r.name,
	r.summa,	
    r.description,
	coalesce(r.active,true),
	rt.id,
	rc.name,
	rt.difficulty,
	r.restrictions
   FROM data.routes r
   LEFT JOIN sysdata."SYS_ROUTETYPES" rt on rt.id=r.type_id
   left join sysdata."SYS_RESOURCES" rc on rc.resource_id=rt.resource_id and rc.country_code=code_
  WHERE (r.client_id = client_id_);
  
END

$$;


ALTER FUNCTION api.client_view_routes(client_id_ integer, pass_ text, code_ character varying) OWNER TO postgres;

--
-- TOC entry 569 (class 1255 OID 16532)
-- Name: del_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.del_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Пометка заказа как удаленного. Если заказ не новый, ничего не происходит.
*/
DECLARE order_id BIGINT;
DECLARE curr_status_id INT;
DECLARE is_del BOOLEAN;
DECLARE res INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

  SELECT o.id, coalesce(o.status_id,0), o.is_deleted FROM data.orders o where o.id=order_id_ and o.dispatcher_id=dispatcher_id_ 
  FOR UPDATE
  into order_id,curr_status_id,is_del;

  IF order_id is null THEN
	 res=-1;
  ELSIF curr_status_id>0 or coalesce(is_del,false) THEN
     res=0;
  ELSE
   BEGIN
    UPDATE data.orders set is_deleted=true, 
	                       del_time=CURRENT_TIMESTAMP 
					   where id=order_id_;
    res=1;
   END;	
  END IF;  

RETURN res;
END

$$;


ALTER FUNCTION api.del_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 570 (class 1255 OID 16533)
-- Name: del_orders_history(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.del_orders_history(dispatcher_id_ integer, pass_ text, orders_history_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.order_history where id=orders_history_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.del_orders_history(dispatcher_id_ integer, pass_ text, orders_history_id_ bigint) OWNER TO postgres;

--
-- TOC entry 571 (class 1255 OID 16534)
-- Name: dispatcher_accept_checkpoint(integer, text, bigint, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_accept_checkpoint(dispatcher_id_ integer, pass_ text, checkpoint_id_ bigint, accepted_ boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка снятие акцепта с чекпойнта.
Возвращает boolean.
*/
declare updated_count integer;
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

with updated as
(
	update data.checkpoints set accepted = accepted_
	where id=checkpoint_id_ and exists(select 1 from data.orders o where o.id=order_id and o.dispatcher_id=dispatcher_id_)
	returning id
)
select count(*) from updated into updated_count;

if updated_count>0 then
 return true;
else
 return false;
end if; 

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
  
end

$$;


ALTER FUNCTION api.dispatcher_accept_checkpoint(dispatcher_id_ integer, pass_ text, checkpoint_id_ bigint, accepted_ boolean) OWNER TO postgres;

--
-- TOC entry 572 (class 1255 OID 16535)
-- Name: dispatcher_add_by_schedule(integer, text, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_add_by_schedule(dispatcher_id_ integer, pass_ text, date_ date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Добавляет данные по календарю в список заказов.
*/
declare json1 jsonb;
declare json2 jsonb;
declare json3 jsonb;
begin
if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return  (json_build_object('date',date_))::jsonb
	   ||(json_build_object('success','[]'::jsonb))::jsonb
	   ||(select array_to_json(array(SELECT json_build_object('id',0,
															  'name','Access error')
								 )))::jsonb;
end if;

with routes as
(
	select dr.id,dr.name,coalesce(dr.base_sum,0) base_sum,dr.client_id,dr.load_data,dr.load_time,dr.calc_data,dr.restrictions,coalesce(dr.docs_next_day,false) docs_next_day
	from data.dispatcher_routes dr 
	where dr.dispatcher_id=dispatcher_id_ and coalesce(dr.active,true)
),
cfdata as
(
	select cf.id,
	cf.driver_id,
	d.family_name||' '||d.name||' '||d.second_name driver_name,
	cf.route_id,
	r.name route_name,
	r.base_sum,
	r.load_data,
	r.load_time,
	r.client_id,
	r.docs_next_day,
	d.contract_id,
	(
		select (elem->>'price')::numeric 
        from routes dr 
        cross join jsonb_array_elements(dr.calc_data->'contracts') elem
        where elem->>'id' = d.contract_id::text and dr.id=cf.route_id
	) as price
	from data.calendar_final cf
	left join routes r on r.id=cf.route_id
	left join data.drivers d on d.id=cf.driver_id
	where cf.dispatcher_id=dispatcher_id_ and cf.cdate=date_
	  and cf.daytype_id=1 and cf.route_id is not null
),
existed_orders as
(
	select o.id,o.driver_id,o.dispatcher_route_id as route_id from data.orders o
	where o.dispatcher_id=dispatcher_id_ and o.from_time::date=date_ and not coalesce(o.is_deleted,false)
),
errors as
(
	select cf.id, 
	cf.driver_id, 
	cf.driver_name,
	cf.route_id,
	cf.route_name,
	exists(select 1 from existed_orders o where o.driver_id=coalesce(cf.driver_id,0)) driver_error,
	exists(select 1 from existed_orders o where o.route_id=cf.route_id) route_error,
	( (cf.driver_id is not null) and (coalesce(cf.price,0)<=0) ) price_error
	from cfdata cf
),
res_insert as
(
	  insert into data.orders (id,order_time,order_title,from_addr_name,from_addr_latitude,from_addr_longitude,from_time,client_summa,summa,driver_id,dispatcher_id,client_dispatcher_id,client_id,status_id,visible,free_sum,doc_date,created_by_dispatcher_id,dispatcher_route_id)
         select nextval('data.orders_id_seq'),CURRENT_TIMESTAMP,cf.route_name,cf.load_data->>'place',(cf.load_data->>'lat')::numeric,(cf.load_data->>'lng')::numeric,date_+cf.load_time,cf.price,cf.price,cf.driver_id,dispatcher_id_,dispatcher_id_,cf.client_id,case coalesce(cf.driver_id,0) when 0 then 30 else 50 end,true,true,case cf.docs_next_day when true then (date_+interval '1 day')::date else null end,dispatcher_id_,cf.route_id
		 from cfdata cf
		 where not exists(select 1 from errors er where er.id=cf.id and (driver_error or route_error or price_error) )
		 returning id,order_title,client_id,summa,driver_id,dispatcher_route_id
),
dso_insert as
(
	insert into data.dispatcher_selected_orders (id,order_id,dispatcher_id,sel_time,is_active)
	 select nextval('data.dispatcher_selected_orders_id_seq'),ri.id,dispatcher_id_,CURRENT_TIMESTAMP,true
	 from res_insert ri
),
success_json as
(	
	select array(SELECT ri.id from res_insert ri) success	
)
select json_build_object('date',date_),
 json_build_object('success',
   (
	 select array_to_json(array( SELECT json_build_object('id',ri.id,
		 												  'driver_id',ri.driver_id,
														  'driver_name',d.family_name||' '||d.name||' '||d.second_name,
														  'route_id',ri.dispatcher_route_id,
														  'route_name',ri.order_title,
														  'summa',ri.summa,
														  'client_id',ri.client_id,
														  'client_name',cl.name)
           						FROM res_insert ri
								left join data.drivers d on d.id=ri.driver_id
								left join data.clients cl on cl.id=ri.client_id
							   )
						 ) 
   ) 
 )as json_success,
 (
	 select array_to_json(array( SELECT json_build_object('driver_id',er.driver_id,
														  'driver_name',er.driver_name,
														  'route_id',er.route_id,
														  'route_name',er.route_name,
														  'driver_error',er.driver_error,
														  'route_error',er.route_error,
														  'price_error',er.price_error)
           						FROM errors er
								where er.driver_error or er.route_error or er.price_error
							   )
						 ) 
 ) as json_error
from success_json into json1,json2,json3;

return json1||json2||json3;
end

$$;


ALTER FUNCTION api.dispatcher_add_by_schedule(dispatcher_id_ integer, pass_ text, date_ date) OWNER TO postgres;

--
-- TOC entry 573 (class 1255 OID 16537)
-- Name: dispatcher_add_costs(integer, text, integer, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_add_costs(dispatcher_id_ integer, pass_ text, driver_id_ integer, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Добавляет/изменяет затраты по водителю.
*/

DECLARE driver_dispatcher INTEGER;

begin
if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;
select d.dispatcher_id from data.drivers d where d.id=driver_id_ into driver_dispatcher;
if driver_dispatcher<>dispatcher_id_ then
 return false;
end if; 

delete from data.driver_costs dc where dc.driver_id = driver_id_;-- and dc.id not in json_object_keys(data_);
insert into data.driver_costs(id,driver_id,cost_id,percent)
 select nextval('data.driver_costs_id_seq'), driver_id_, d.key::integer, d.value::numeric from jsonb_each_text(data_) d;
--on conflict(driver_id,cost_id) update set percent=;

return true;
end

$$;


ALTER FUNCTION api.dispatcher_add_costs(dispatcher_id_ integer, pass_ text, driver_id_ integer, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 575 (class 1255 OID 16538)
-- Name: dispatcher_add_ga(integer, text, text, text, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_add_ga(dispatcher_id_ integer, pass_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Добавление гугл-адреса.
*/

BEGIN

address_id = -1; 
original_id = NULL;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if not exists(select 1 from data.google_addresses ga where ga.dispatcher_id=dispatcher_id_ and trim(upper(ga.address))=trim(upper(address_))) then
 begin							
    select gor.id from data.google_originals gor where upper(google_address_)=upper(gor.address)
	into original_id;

	if original_id is null then
      insert into data.google_originals(id,address,latitude,longitude)
 	  values(nextval('data.google_originals_id_seq'),google_address_,latitude_,longitude_)
	  on conflict do nothing																		   
	  returning id into original_id;
    end if;		
																				   
	if original_id is null then
		return;
	else
      insert into data.google_addresses(id,dispatcher_id,address,google_original)
	              values(nextval('data.google_addresses_id_seq'),dispatcher_id_,trim(address_),original_id)
		  		  returning id into address_id;
     end if;
 end;
else
	select ga.id,ga.google_original from data.google_addresses ga where ga.dispatcher_id=dispatcher_id_ and trim(upper(ga.address))=trim(upper(address_)) 
	into address_id, original_id;
end if;

address_id = coalesce(address_id,-1);

RETURN;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
END

$$;


ALTER FUNCTION api.dispatcher_add_ga(dispatcher_id_ integer, pass_ text, address_ text, google_address_ text, latitude_ numeric, longitude_ numeric, OUT address_id bigint, OUT original_id bigint) OWNER TO postgres;

--
-- TOC entry 576 (class 1255 OID 16539)
-- Name: dispatcher_add_order_to_favorites(integer, text, bigint, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_add_order_to_favorites(dispatcher_id_ integer, pass_ text, order_id_ bigint, dfo_id_ bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Добавление своего заказа в Избранное.
*/

DECLARE dfo BIGINT DEFAULT -1;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if exists(select 1 from data.dispatcher_favorite_orders dfo where dfo.id=dfo_id_ and dfo.dispatcher_id = dispatcher_id_) then
 begin
   dfo = dfo_id_;
   update data.dispatcher_favorite_orders set favorite=true 
    where dispatcher_id = dispatcher_id_ and id=dfo_id_;
 end;	
else
 insert into data.dispatcher_favorite_orders (id,order_id,dispatcher_id,favorite)
  values(nextval('data.dispatcher_favorite_orders_id_seq'), order_id_, dispatcher_id_, true) 
  returning id into dfo;
end if;

 return dfo;

END

$$;


ALTER FUNCTION api.dispatcher_add_order_to_favorites(dispatcher_id_ integer, pass_ text, order_id_ bigint, dfo_id_ bigint) OWNER TO postgres;

--
-- TOC entry 577 (class 1255 OID 16540)
-- Name: dispatcher_appoint_order(integer, text, bigint, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_appoint_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Назначение принудительно водителю заказа. Если статус неподходящий,
ничего не произойдет.
*/

DECLARE selected_order_id BIGINT DEFAULT NULL;
DECLARE car_driver_id INTEGER DEFAULT NULL;
DECLARE car_id BIGINT DEFAULT NULL;
DECLARE car_attribs JSONB DEFAULT NULL;
DECLARE curr_status_id INT DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

 SELECT o.id, coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ and exists(select 1 from data.dispatcher_selected_orders dso where dso.order_id=order_id_ and dso.dispatcher_id=dispatcher_id_) 
  FOR UPDATE
  into selected_order_id,curr_status_id;

select dc.driver_id from data.driver_cars dc
where dc.id=car_id_ 
into car_driver_id;

if coalesce(selected_order_id,0)<1 or coalesce(car_driver_id,0)<1 or not coalesce(curr_status_id,0) in (30,40) then
 return false;
end if;

select json_build_object(
		 'car_id',dc.id,
	     'cartype_id',dc.cartype_id,
		 'cartype_name',ct.name,
		 'carclass_id',cc.id,
		 'carclass_name',cc.name,
		 'carmodel',dc.carmodel,
		 'carnumber',dc.carnumber,
		 'carcolor',dc.carcolor)
    from data.driver_cars dc
	left join sysdata."SYS_CARTYPES" ct on ct.id=dc.cartype_id
	left join sysdata."SYS_CARCLASSES" cc on cc.id=ct.class_id
	where dc.id = car_id_ into car_attribs;
	
if car_attribs is null then
 return false;
end if;

     UPDATE data.orders set dispatcher_id=dispatcher_id_,
	                        driver_id=car_driver_id,
	                        status_id=50,
	                        driver_car_attribs=car_attribs
	                    where id=order_id_;
/*						
        insert into data.orders_appointing (id,order_id,dispatcher_id,driver_id,appoint_order,car_attribs) 
	                          values(nextval('data.orders_appointing_id_seq'),order_id_,dispatcher_id_,car_driver_id,CURRENT_TIMESTAMP,car_attribs);
*/

/*Удалю из отклоненных*/
delete from data.orders_rejecting where order_id=order_id_ and driver_id=car_driver_id;

insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,status_old,action_string)
values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,car_driver_id,CURRENT_TIMESTAMP,50,curr_status_id,'Appoint') 
on conflict do nothing;
     return true;

END

$$;


ALTER FUNCTION api.dispatcher_appoint_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, car_id_ integer) OWNER TO postgres;

--
-- TOC entry 578 (class 1255 OID 16541)
-- Name: dispatcher_autocreate_execute(integer, text, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_autocreate_execute(dispatcher_id_ integer, pass_ text, date_ date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Выполнение автосоздания заказов.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

insert into data.autocreate_logs(id,dispatcher_id,datetime,type_id,action_result)
 values(nextval('data.autocreate_logs_id_seq'),dispatcher_id_,CURRENT_TIMESTAMP,1,(select api.dispatcher_add_by_schedule(dispatcher_id_, pass_, date_)));

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
END

$$;


ALTER FUNCTION api.dispatcher_autocreate_execute(dispatcher_id_ integer, pass_ text, date_ date) OWNER TO postgres;

--
-- TOC entry 579 (class 1255 OID 16542)
-- Name: dispatcher_calendar_add_event(integer, text, integer, integer, integer, date, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_add_event(dispatcher_id_ integer, pass_ text, driver_id_ integer, route_id_ integer, daytype_id_ integer, cdate_ date, code_ character varying, OUT calendar_id bigint, OUT route_name text, OUT driver_name text, OUT daytype_name text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Добавление события в календарь.
Возвращает либо id, либо -1.
*/
DECLARE notification_id BIGINT;

begin

calendar_id = -1;
route_name = '';
daytype_name = '';

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

insert into data.calendar(id,dispatcher_id,driver_id,route_id,daytype_id,cdate)
values (nextval('data.calendar_id_seq'),dispatcher_id_,driver_id_,route_id_,daytype_id_,cdate_)
--on conflict(dispatcher_id,driver_id,cdate)
--DO 
--   UPDATE SET route_id = route_id_, daytype_id = daytype_id_
returning id   
into calendar_id;

if calendar_id>0 then
 begin
  route_name = coalesce((SELECT r.name from data.dispatcher_routes r where r.id = route_id_),'');
  driver_name = coalesce((SELECT d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.' from data.drivers d where d.id = driver_id_),'');
  SELECT rc.name from sysdata."SYS_DAYTYPES" dt
  left join sysdata."SYS_RESOURCES" rc on rc.resource_id=dt.resource_id and rc.country_code=code_
  where dt.id = daytype_id_
  into daytype_name;
 end;
end if;

/*
-- внесем в уведомления
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id_,cdate_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate_;
*/

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_add_event(dispatcher_id_ integer, pass_ text, driver_id_ integer, route_id_ integer, daytype_id_ integer, cdate_ date, code_ character varying, OUT calendar_id bigint, OUT route_name text, OUT driver_name text, OUT daytype_name text) OWNER TO postgres;

--
-- TOC entry 580 (class 1255 OID 16543)
-- Name: dispatcher_calendar_begin_changes(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_begin_changes(dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Начать изменения в календаре.
*/

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if not exists(select 1 from data.calendar where dispatcher_id=dispatcher_id_) then
	insert into data.calendar select cf.* from data.calendar_final cf where cf.dispatcher_id=dispatcher_id_;
end if;	

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_begin_changes(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 581 (class 1255 OID 16544)
-- Name: dispatcher_calendar_cancel_changes(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_cancel_changes(dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Отменить изменения в календаре.
*/

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

delete from data.calendar where dispatcher_id=dispatcher_id_;	

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_cancel_changes(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 582 (class 1255 OID 16545)
-- Name: dispatcher_calendar_change_driver(integer, text, integer, date, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_change_driver(dispatcher_id_ integer, pass_ text, route_id_ integer, cdate_ date, driver_id_ integer, OUT changed boolean, OUT driver_name text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Изменение маршрута в календаре.
Возвращает либо true/false и имя маршрута.
*/
DECLARE notification_id BIGINT;

begin

changed = false;
driver_name = '';

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

update data.calendar set driver_id = driver_id_
where dispatcher_id = dispatcher_id_ and route_id = route_id_ and cdate = cdate_;

driver_name = coalesce((SELECT d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.' from data.drivers d where d.id = driver_id_),'');
changed = true;

/*
-- внесем в уведомления
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id_,cdate_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate_;
*/

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_change_driver(dispatcher_id_ integer, pass_ text, route_id_ integer, cdate_ date, driver_id_ integer, OUT changed boolean, OUT driver_name text) OWNER TO postgres;

--
-- TOC entry 583 (class 1255 OID 16546)
-- Name: dispatcher_calendar_change_route(integer, text, integer, date, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_change_route(dispatcher_id_ integer, pass_ text, driver_id_ integer, cdate_ date, route_id_ integer, OUT changed boolean, OUT route_name text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Изменение маршрута в календаре.
Возвращает либо true/false и имя маршрута.
*/
DECLARE notification_id BIGINT;

begin

changed = false;
route_name = '';

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

update data.calendar set route_id = route_id_
where dispatcher_id = dispatcher_id_ and driver_id = driver_id_ and cdate = cdate_;

route_name = coalesce((SELECT r.name from data.dispatcher_routes r where r.id = route_id_),'');
changed = true;

/*
-- внесем в уведомления
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id_,cdate_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate_;
*/

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_change_route(dispatcher_id_ integer, pass_ text, driver_id_ integer, cdate_ date, route_id_ integer, OUT changed boolean, OUT route_name text) OWNER TO postgres;

--
-- TOC entry 584 (class 1255 OID 16547)
-- Name: dispatcher_calendar_delete_event(integer, text, integer, integer, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_delete_event(dispatcher_id_ integer, pass_ text, driver_id_ integer, route_id_ integer, cdate_ date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Удаление события в календарь.
Возвращает либо true/false
*/
DECLARE rows_count integer;
DECLARE notification_id BIGINT;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if coalesce(driver_id_,0)>0 then
  begin
	WITH deleted AS 
	(
		delete from data.calendar where dispatcher_id=dispatcher_id_ and driver_id=driver_id_ and cdate=cdate_ 
		returning *
	) 
	select count(*) from deleted into rows_count;
  end;
else
  begin
	WITH deleted AS 
	(
		delete from data.calendar where dispatcher_id=dispatcher_id_ and route_id=route_id_ and cdate=cdate_ 
		returning *
	) 
	select count(*) from deleted into rows_count;
  end;
end if;

/*
-- внесем в уведомления
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id_,cdate_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate_;
*/

if rows_count > 0 then
 return true;
end if; 

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_delete_event(dispatcher_id_ integer, pass_ text, driver_id_ integer, route_id_ integer, cdate_ date) OWNER TO postgres;

--
-- TOC entry 585 (class 1255 OID 16548)
-- Name: dispatcher_calendar_drag_driver(integer, text, integer, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_drag_driver(dispatcher_id_ integer, pass_ text, driver_id1_ integer, driver_id2_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Перенос события в календаре.
Возвращает либо true/false.
*/

declare idx1 integer;
declare idx2 integer;
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

idx1 = coalesce((select calendar_index from data.drivers where id = driver_id1_),0);
idx2 = coalesce((select calendar_index from data.drivers where id = driver_id2_),0);

if idx1 < idx2 then --перенос вниз
 begin
  /*
	Все idx, что idx1 < idx <= idx2  делаем -1, а idx1 = idx2
  */
  with tmp as
  (
	  select id, calendar_index as idx from data.drivers 
	  where dispatcher_id = dispatcher_id_ and calendar_index > idx1 and calendar_index <= idx2
  )
  update data.drivers 
  set calendar_index = tmp.idx-1 
  from tmp where drivers.id=tmp.id;
 end;
else --перенос вверх 
 begin
  /*
	Все idx, что idx2 <= idx < idx1  делаем +1, а idx1 = idx2
  */
  with tmp as
  (
	  select id, calendar_index as idx from data.drivers 
	  where dispatcher_id = dispatcher_id_ and calendar_index >= idx2 and calendar_index < idx1
  )
  update data.drivers  
  set calendar_index = tmp.idx+1 
  from tmp where drivers.id=tmp.id;
 end;

end if; 

update data.drivers set calendar_index = idx2
 where dispatcher_id = dispatcher_id_ and id = driver_id1_;

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_drag_driver(dispatcher_id_ integer, pass_ text, driver_id1_ integer, driver_id2_ integer) OWNER TO postgres;

--
-- TOC entry 588 (class 1255 OID 16549)
-- Name: dispatcher_calendar_drag_event(integer, text, integer, integer, date, integer, integer, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_drag_event(dispatcher_id_ integer, pass_ text, driver_id1_ integer, route_id1_ integer, cdate1_ date, driver_id2_ integer, route_id2_ integer, cdate2_ date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Перенос события в календаре.
Возвращает либо true/false.
*/

DECLARE notification_id BIGINT;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if coalesce(driver_id1_,0)>0 then
	update data.calendar set driver_id = driver_id2_,
						 cdate = cdate2_
	where dispatcher_id = dispatcher_id_ and driver_id = driver_id1_ and cdate = cdate1_;
else
	update data.calendar set route_id = route_id2_,
						 cdate = cdate2_
	where dispatcher_id = dispatcher_id_ and route_id = route_id1_ and cdate = cdate1_;
end if;

/*
-- внесем в уведомления
-- для 1-го
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id1_,cdate1_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate1_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate1_;

-- для 2-го
notification_id = nextval('data.calendar_notifications_notification_id_seq');

insert into data.calendar_notifications as cn (id,driver_id,event_date,notify_id)
values (nextval('data.calendar_notifications_id_seq'),driver_id2_,cdate2_,notification_id)
on conflict(driver_id)
DO 
   UPDATE SET event_date = cdate2_,
              notify_id = notification_id
   WHERE cn.event_date<=cdate2_;
*/

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_drag_event(dispatcher_id_ integer, pass_ text, driver_id1_ integer, route_id1_ integer, cdate1_ date, driver_id2_ integer, route_id2_ integer, cdate2_ date) OWNER TO postgres;

--
-- TOC entry 589 (class 1255 OID 16550)
-- Name: dispatcher_calendar_save_changes(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_calendar_save_changes(dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Применение изменений в календаре.
*/
DECLARE notification_id BIGINT;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.calendar where dispatcher_id=dispatcher_id_) then
	begin
--создадим уведомления для всех, у кого изменилось
		notification_id = nextval('data.calendar_notifications_notification_id_seq');
		
		with cals_fin as
		(
			select distinct(cf1.driver_id),(select MD5(array(select json_build_object('route',cf2.route_id,
											  'daytype',cf2.daytype_id,
											  'cdate',cf2.cdate) from data.calendar_final cf2 where cf2.driver_id=cf1.driver_id and cf2.cdate>=CURRENT_DATE)::text) as hash) from data.calendar_final cf1 where cf1.dispatcher_id=dispatcher_id_ and cf1.driver_id is not null
		),
		cals as
		(
			select distinct(c1.driver_id),(select MD5(array(select json_build_object('route',c2.route_id,
											  'daytype',c2.daytype_id,
											  'cdate',c2.cdate) from data.calendar c2 where c2.driver_id=c1.driver_id and c2.cdate>=CURRENT_DATE)::text) as hash) from data.calendar c1 where c1.dispatcher_id=dispatcher_id_ and c1.driver_id is not null
		)
		insert into data.calendar_notifications
			select nextval('data.calendar_notifications_id_seq'),c.driver_id,CURRENT_DATE,notification_id
			from cals c
			left join cals_fin cf on c.driver_id=cf.driver_id and c.hash<>cf.hash
			where cf.driver_id is not null
		on conflict(driver_id)
		DO 
		   UPDATE SET event_date = CURRENT_DATE,
					  notify_id = notification_id;

	
		delete from data.calendar_final where dispatcher_id=dispatcher_id_;
		insert into data.calendar_final select c.* from data.calendar c where c.dispatcher_id=dispatcher_id_;
		delete from data.calendar where dispatcher_id=dispatcher_id_;
	end;
end if;

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
end

$$;


ALTER FUNCTION api.dispatcher_calendar_save_changes(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 590 (class 1255 OID 16551)
-- Name: dispatcher_cancel_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_cancel_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Отмена выполняемого заказа. Статус (40/60)->30, водитель, параметры машины.
Диспетчер становится тем диспетчером, который был установлен клиентом.
История отмен записывается в data.orders_canceling .
*/

DECLARE order_id BIGINT;
DECLARE order_driver_id INT;
DECLARE dispatcher_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.driver_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,order_driver_id,curr_status_id;
  select d.dispatcher_id from data.drivers d
   where d.id = order_driver_id FOR UPDATE
   into dispatcher_id;

  IF order_id is null 
  or curr_status_id not in (40,60,100,110) 
  or dispatcher_id<>dispatcher_id_ 
  THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set driver_id=null,
	                        status_id=30, /* Новый заказ */
							dispatcher_id=client_dispatcher_id,
							driver_car_attribs=null
						where id=order_id_;
	 
	 insert into data.orders_canceling (id,order_id,driver_id,cancel_order) 
	                          values(nextval('data.orders_canceling_id_seq'),order_id_,order_driver_id,CURRENT_TIMESTAMP);

     insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,order_driver_id,CURRENT_TIMESTAMP,30,curr_status_id,'Cancel') 
     on conflict do nothing;
							  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.dispatcher_cancel_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 591 (class 1255 OID 16552)
-- Name: dispatcher_change_active_route(integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_change_active_route(dispatcher_id_ integer, pass_ text, route_id_ integer, route_active_ boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Изменение активности маршрута.
Возвращает boolean.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

update data.dispatcher_routes set active=route_active_ where id=route_id_ and dispatcher_id=dispatcher_id_;	   
 
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN FALSE;
  
end

$$;


ALTER FUNCTION api.dispatcher_change_active_route(dispatcher_id_ integer, pass_ text, route_id_ integer, route_active_ boolean) OWNER TO postgres;

--
-- TOC entry 592 (class 1255 OID 16553)
-- Name: dispatcher_change_driver_in_order(integer, text, bigint, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_change_driver_in_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Назначение принудительно водителю заказа. Если статус неподходящий,
ничего не произойдет.
*/

DECLARE selected_order_id BIGINT DEFAULT NULL;
DECLARE car_driver_id INTEGER DEFAULT NULL;
DECLARE car_id BIGINT DEFAULT NULL;
DECLARE car_attribs JSONB DEFAULT NULL;
DECLARE curr_status_id INT DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

 SELECT o.id, coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ and exists(select 1 from data.dispatcher_selected_orders dso where dso.order_id=order_id_ and dso.dispatcher_id=dispatcher_id_) 
  FOR UPDATE
  into selected_order_id,curr_status_id;

select dc.driver_id from data.driver_cars dc
where dc.id=car_id_ 
into car_driver_id;

if coalesce(selected_order_id,0)<1 or coalesce(car_driver_id,0)<1 or not coalesce(curr_status_id,0)>=120 then
 return false;
end if;

select json_build_object(
		 'car_id',dc.id,
	     'cartype_id',dc.cartype_id,
		 'cartype_name',ct.name,
		 'carclass_id',cc.id,
		 'carclass_name',cc.name,
		 'carmodel',dc.carmodel,
		 'carnumber',dc.carnumber,
		 'carcolor',dc.carcolor)
    from data.driver_cars dc
	left join sysdata."SYS_CARTYPES" ct on ct.id=dc.cartype_id
	left join sysdata."SYS_CARCLASSES" cc on cc.id=ct.class_id
	where dc.id = car_id_ into car_attribs;
	
if car_attribs is null then
 return false;
end if;

     UPDATE data.orders set dispatcher_id=dispatcher_id_,
	                        driver_id=car_driver_id,
	                        driver_car_attribs=car_attribs,
							end_device_id=null
	                    where id=order_id_;

/*Удалю из отклоненных*/
delete from data.orders_rejecting where order_id=order_id_ and driver_id=car_driver_id;

insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,status_old,action_string)
values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,car_driver_id,CURRENT_TIMESTAMP,curr_status_id,curr_status_id,'Change driver') 
on conflict do nothing;

return api.dispatcher_finish_order(order_id_,dispatcher_id_,pass_,true);

END

$$;


ALTER FUNCTION api.dispatcher_change_driver_in_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, car_id_ integer) OWNER TO postgres;

--
-- TOC entry 586 (class 1255 OID 16554)
-- Name: dispatcher_del_addsum(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_addsum(addsum_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Пометка штрафа/бонуса как удаленного.
*/
DECLARE addsum_id BIGINT;
DECLARE is_del BOOLEAN;
DECLARE res INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

  SELECT a.id, a.is_deleted FROM data.addsums a where a.id=addsum_id_ and a.dispatcher_id=dispatcher_id_ and not coalesce(a.is_deleted,false)
  FOR UPDATE
  into addsum_id,is_del;

  IF addsum_id is null THEN
	 res=-2;
  ELSIF coalesce(is_del,false) THEN
     res=0;
  ELSE
   BEGIN
    UPDATE data.addsums set is_deleted=true, 
	                       del_time=CURRENT_TIMESTAMP 
					   where id=addsum_id;
    insert into data.finances_log(id,addsum_id,dispatcher_id,datetime,action_string)
         values (nextval('data.finances_log_id_seq'),addsum_id,dispatcher_id_,CURRENT_TIMESTAMP,'Delete') 
         on conflict do nothing;					   
    res=1;
   END;	
  END IF;  

RETURN res;
END

$$;


ALTER FUNCTION api.dispatcher_del_addsum(addsum_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 587 (class 1255 OID 16555)
-- Name: dispatcher_del_contract(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_contract(dispatcher_id_ integer, pass_ text, contract_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
 Вызывается диспетчером.
 Удаление контракта.
*/

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.contracts where id=contract_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.dispatcher_del_contract(dispatcher_id_ integer, pass_ text, contract_id_ integer) OWNER TO postgres;

--
-- TOC entry 593 (class 1255 OID 16556)
-- Name: dispatcher_del_cost_type(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_cost_type(dispatcher_id_ integer, pass_ text, cost_type_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
 Вызывается диспетчером.
 Удаление типа затрат.
*/

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.cost_types where id=cost_type_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.dispatcher_del_cost_type(dispatcher_id_ integer, pass_ text, cost_type_id_ integer) OWNER TO postgres;

--
-- TOC entry 483 (class 1255 OID 16557)
-- Name: dispatcher_del_dogovor(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_dogovor(dogovor_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Удаление договора.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.dispatcher_dogovors dd where dd.dispatcher_id=dispatcher_id_ and dd.id=dogovor_id_) then
 begin
  delete from data.dispatcher_dogovors where id=dogovor_id_;
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
END

$$;


ALTER FUNCTION api.dispatcher_del_dogovor(dogovor_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 529 (class 1255 OID 16558)
-- Name: dispatcher_del_driver_car(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE _dispatcher_id integer default 0;
DECLARE _driver_id integer default -1;

/*
 Вызывается диспетчером.
 Удаление автомобиля. Возвращает либо id водителя, либо -1; 
*/

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

select coalesce(d.dispatcher_id,-1), d.id from data.driver_cars dc
 left join data.drivers d on d.id=dc.driver_id
 where dc.id=driver_car_id_ into _dispatcher_id, _driver_id;
  if _dispatcher_id<>dispatcher_id_ then
   return -1;
  end if;
  

DELETE FROM data.driver_cars where id=driver_car_id_;
return _driver_id;

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
end

$$;


ALTER FUNCTION api.dispatcher_del_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) OWNER TO postgres;

--
-- TOC entry 595 (class 1255 OID 16559)
-- Name: dispatcher_del_feedback(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_feedback(feedback_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Пометка платежа как удаленного. Если платеж акцептован, ничего не происходит.
*/
DECLARE feedback_id BIGINT;
DECLARE paid_date DATE;
DECLARE is_del BOOLEAN;
DECLARE res INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

  SELECT f.id, f.paid, f.is_deleted FROM data.feedback f where f.id=feedback_id_ and f.dispatcher_id=dispatcher_id_ and not coalesce(f.is_deleted,false)
  FOR UPDATE
  into feedback_id,paid_date,is_del;

  IF feedback_id is null THEN
	 res=-2;
  ELSIF (paid_date is not null or coalesce(is_del,false)) THEN
     res=0;
  ELSE
   BEGIN
    UPDATE data.feedback set is_deleted=true, 
	                       del_time=CURRENT_TIMESTAMP 
					   where id=feedback_id;
    insert into data.finances_log(id,payment_id,dispatcher_id,datetime,action_string)
         values (nextval('data.finances_log_id_seq'),feedback_id,dispatcher_id_,CURRENT_TIMESTAMP,'Delete') 
         on conflict do nothing;					   
    res=1;
   END;	
  END IF;  

RETURN res;
END

$$;


ALTER FUNCTION api.dispatcher_del_feedback(feedback_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 596 (class 1255 OID 16560)
-- Name: dispatcher_del_ga(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_ga(dispatcher_id_ integer, pass_ text, address_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Удаление своего гугл-адреса.
Возвращает либо true, либо false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.google_addresses where id=address_id_ and dispatcher_id=dispatcher_id_) then
 begin
  delete from data.google_addresses where id=address_id_ and dispatcher_id=dispatcher_id_;
  return true;
 end;
end if; 

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$$;


ALTER FUNCTION api.dispatcher_del_ga(dispatcher_id_ integer, pass_ text, address_id_ bigint) OWNER TO postgres;

--
-- TOC entry 597 (class 1255 OID 16561)
-- Name: dispatcher_del_order_from_favorites(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_order_from_favorites(dispatcher_id_ integer, pass_ text, dfo_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Удаление своего заказа из Избранного.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

   update data.dispatcher_favorite_orders set favorite=false 
    where dispatcher_id = dispatcher_id_ and id=dfo_id_;

 return true;

END

$$;


ALTER FUNCTION api.dispatcher_del_order_from_favorites(dispatcher_id_ integer, pass_ text, dfo_id_ bigint) OWNER TO postgres;

--
-- TOC entry 598 (class 1255 OID 16562)
-- Name: dispatcher_del_point(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_point(dispatcher_id_ integer, pass_ text, point_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Удаление точки.
Возвращает либо true/false
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.client_points cp where cp.dispatcher_id=dispatcher_id_ and cp.id=point_id_) then
 begin
  delete from data.client_points where id=point_id_;
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
end

$$;


ALTER FUNCTION api.dispatcher_del_point(dispatcher_id_ integer, pass_ text, point_id_ integer) OWNER TO postgres;

--
-- TOC entry 599 (class 1255 OID 16563)
-- Name: dispatcher_del_point_coordinate(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_point_coordinate(dispatcher_id_ integer, pass_ text, coord_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Удаление координат.
Возвращает либо true/false
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.client_point_coordinates cpc where cpc.id=coord_id_ and dispatcher_id_=(select cp.dispatcher_id from data.client_points cp where cp.id=cpc.point_id)) then
 begin
  delete from data.client_point_coordinates where id=coord_id_ and dispatcher_id_=(select cp.dispatcher_id from data.client_points cp where cp.id=client_point_coordinates.point_id);
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
end

$$;


ALTER FUNCTION api.dispatcher_del_point_coordinate(dispatcher_id_ integer, pass_ text, coord_id_ integer) OWNER TO postgres;

--
-- TOC entry 600 (class 1255 OID 16564)
-- Name: dispatcher_del_pointgroup(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Удаление группы мест
Возвращает либо true, либо false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.client_point_groups t where t.id=pointgroup_id_ and t.dispatcher_id=dispatcher_id_) 
and not exists(select 1 from data.client_points dc where dc.group_id=pointgroup_id_) then
 begin
  delete from data.client_point_groups where id=pointgroup_id_ and dispatcher_id=dispatcher_id_;
  return true;
 end;
end if; 

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$$;


ALTER FUNCTION api.dispatcher_del_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer) OWNER TO postgres;

--
-- TOC entry 601 (class 1255 OID 16565)
-- Name: dispatcher_del_route(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_route(dispatcher_id_ integer, pass_ text, route_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Удаление маршрута.
Возвращает либо true/false
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.dispatcher_routes dr where dr.dispatcher_id=dispatcher_id_ and dr.id=route_id_) then
 begin
  delete from data.dispatcher_routes where id=route_id_;
  return true;
 end;
end if;

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
  
end

$$;


ALTER FUNCTION api.dispatcher_del_route(dispatcher_id_ integer, pass_ text, route_id_ integer) OWNER TO postgres;

--
-- TOC entry 602 (class 1255 OID 16566)
-- Name: dispatcher_del_tariff(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_del_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Удаление тарифа
Возвращает либо true, либо false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if exists(select 1 from data.tariffs t where t.id=tariff_id_ and t.dispatcher_id=dispatcher_id_) 
and not exists(select 1 from data.driver_cars dc where dc.tariff_id=tariff_id_) then
 begin
  delete from data.tariffs where id=tariff_id_ and dispatcher_id=dispatcher_id_;
  return true;
 end;
end if; 

return false;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$$;


ALTER FUNCTION api.dispatcher_del_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer) OWNER TO postgres;

--
-- TOC entry 604 (class 1255 OID 16567)
-- Name: dispatcher_deselect_driver(integer, text, bigint, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_deselect_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, driver_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Удаление водителя из списка претендентов на выделенный ордер.
*/

DECLARE sel_id BIGINT DEFAULT NULL;
DECLARE record_id BIGINT DEFAULT NULL;
DECLARE dispatcher_id INTEGER DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select dso.id,dso.dispatcher_id from data.dispatcher_selected_orders dso
 where dso.order_id=order_id_ and dso.dispatcher_id=dispatcher_id_ 
 into sel_id,dispatcher_id;
 
if coalesce(dispatcher_id,0)!=dispatcher_id_ or coalesce(sel_id,0)<1 then
 return false;
end if;

select dsd.id from data.dispatcher_selected_drivers dsd 
 where dsd.selected_id=sel_id and dsd.driver_id=driver_id_
 into record_id;
 
  IF coalesce(record_id,0)>0 THEN 
     delete from data.dispatcher_selected_drivers where id=record_id;
  ELSE
	 return false;
  END IF;  

 update	data.orders set first_offer_time = (select min(dsd.datetime) FROM data.dispatcher_selected_drivers dsd WHERE dsd.selected_id = sel_id)
 where id=order_id_;
  

insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,action_string)
values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,driver_id_,CURRENT_TIMESTAMP,'Deselect driver') 
on conflict do nothing;

 return true;

END

$$;


ALTER FUNCTION api.dispatcher_deselect_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 605 (class 1255 OID 16568)
-- Name: dispatcher_deselect_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_deselect_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Снятие выделения ордера для дальнейшего предложения водителям.
Если ордер создан диспетчером, то false
*/

DECLARE order_id BIGINT DEFAULT NULL;
DECLARE selected_id BIGINT DEFAULT NULL;
DECLARE curr_status_id INTEGER DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if coalesce((select o.created_by_dispatcher_id from data.orders o where o.id=order_id_),0)=dispatcher_id_ then
 return false;
end if;

    select dso.id,o.id,o.status_id from data.orders o 
	left join data.dispatcher_selected_orders dso on dso.order_id=o.id
    where o.id=order_id_ and dso.dispatcher_id=dispatcher_id_ 
	FOR UPDATE
	into selected_id, order_id, curr_status_id;
	
if coalesce(curr_status_id,0)>30 then
 return false;
end if;
    
	  if coalesce(selected_id,0)>0 then
	    update data.dispatcher_selected_orders set is_active=false 
		where id=selected_id;
	  else
       return false;
	  end if; 

insert into data.order_log(id,order_id,dispatcher_id,datetime,action_string)
values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,CURRENT_TIMESTAMP,'Deselect order') 
on conflict do nothing;

return true;

END

$$;


ALTER FUNCTION api.dispatcher_deselect_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 606 (class 1255 OID 16569)
-- Name: dispatcher_edit_address_modifier(integer, text, bigint, bigint, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_address_modifier(dispatcher_id_ integer, pass_ text, address_id_ bigint, edit_id_ bigint, latitude_ numeric, longitude_ numeric) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Редактирование/добавление модификатора гугл-адреса.
Возвращает либо id, либо -1.
*/
DECLARE edit_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(edit_id_,0)>0 then
  update data.google_modifiers set latitude=latitude_,
				   longitude=longitude_
	 where id=edit_id_ and dispatcher_id=dispatcher_id_
	 returning id into edit_id;	   
else
   insert into data.google_modifiers (id,dispatcher_id,original_id,latitude,longitude)
   values (nextval('data.google_modifiers_id_seq'),dispatcher_id_,(select ga.google_original from data.google_addresses ga where ga.id=address_id_ and ga.dispatcher_id=dispatcher_id_),latitude_,longitude_) 
   returning id into edit_id;
end if;

return coalesce(edit_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.dispatcher_edit_address_modifier(dispatcher_id_ integer, pass_ text, address_id_ bigint, edit_id_ bigint, latitude_ numeric, longitude_ numeric) OWNER TO postgres;

--
-- TOC entry 607 (class 1255 OID 16570)
-- Name: dispatcher_edit_addsum(integer, text, bigint, integer, timestamp without time zone, real, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint, driver_id_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, files_ jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Редактирование/добавление штрафа/бонуса.
Возвращает либо id, либо -1.
*/

DECLARE addsum_dispatcher_id integer default 0;
DECLARE fact_addsum_id bigint default 0;
DECLARE attach_doc_id bigint default 0;
DECLARE add_files jsonb default null;
DECLARE i integer;
DECLARE action_text text;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(addsum_id_,0)>0 then
 begin  
    action_text = 'Edit';
	
    select coalesce(a.dispatcher_id,-1) from data.addsums a
     where a.id=addsum_id_ into addsum_dispatcher_id;
  
    if addsum_dispatcher_id<>dispatcher_id_ then
      return -1;
     end if;
  
     update data.addsums set driver_id=driver_id_,
				   operdate=operdate_,
				   summa=summa_,
				   commentary=commentary_
	    where id=addsum_id_ and dispatcher_id=dispatcher_id_
	    returning id into fact_addsum_id;
	 
     select ad.id from data.addsums_docs ad 
      where ad.addsum_id=fact_addsum_id
      into attach_doc_id;
 
      if coalesce(attach_doc_id,0)>0 then
        delete from data.addsums_files af 
        where not (files_ ? ('id'||af.id)::text ) and af.doc_id=attach_doc_id;
      end if; 	 	
	
   end;   
  else /* Создание*/
     action_text = 'Create';
	
     insert into data.addsums(id,dispatcher_id,driver_id,operdate,summa,commentary)
     values(nextval('data.addsums_id_seq'),dispatcher_id_,driver_id_,operdate_,summa_,commentary_)
	 returning id into fact_addsum_id;
  end if;	 

 if coalesce(attach_doc_id,0)<1 then
  begin
    if cast(files_ as text)<>'' and cast(files_ as text)<>'{}' and cast(files_ as text)<>'[]' then
      insert into data.addsums_docs(id,addsum_id)
      values (nextval('data.addsums_docs_id_seq'),fact_addsum_id)
      returning id into attach_doc_id;   
    end if; 
   end;
  end if; 

  if cast(files_ as text)<>'' and cast(files_ as text)<>'{}' and cast(files_ as text)<>'[]' then
    begin
     add_files = (SELECT jsonb_object_agg(key, value)
                  FROM jsonb_each(files_)
                  WHERE
                  key NOT LIKE 'id%'
                  AND jsonb_typeof(value) != 'null');

      insert into data.addsums_files(id,doc_id,filename,filepath,filesize)
  	    select nextval('data.addsums_files_id_seq'),attach_doc_id,
	                cast(add_files->key->>'name' as text),
					cast(add_files->key->>'guid' as text),
					cast(add_files->key->>'size' as bigint)
	        FROM jsonb_each(add_files);
    end;
  end if;

insert into data.finances_log(id,addsum_id,dispatcher_id,datetime,action_string)
     values (nextval('data.finances_log_id_seq'),fact_addsum_id,dispatcher_id_,CURRENT_TIMESTAMP,action_text) 
     on conflict do nothing;

return fact_addsum_id;

end

$$;


ALTER FUNCTION api.dispatcher_edit_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint, driver_id_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, files_ jsonb) OWNER TO postgres;

--
-- TOC entry 608 (class 1255 OID 16571)
-- Name: dispatcher_edit_contract(integer, text, integer, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_contract(dispatcher_id_ integer, pass_ text, contract_id_ integer, contract_name_ text, contract_description_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Обновление контракта.
Возвращает либо id, либо -1.
*/
DECLARE contract_id integer default -1;
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(contract_id_,0)>0 then --обновить
  update data.contracts set name=contract_name_,description=contract_description_
  where id=contract_id_ and dispatcher_id=dispatcher_id_  
  returning id into contract_id;
else
 insert into data.contracts(id,name,description,dispatcher_id)
  values (nextval('data.contracts_id_seq'),contract_name_,contract_description_,dispatcher_id_) 
  on conflict (name,dispatcher_id) do nothing
  returning id into contract_id;
end if;

return coalesce(contract_id,-1);

EXCEPTION
WHEN OTHERS THEN
  RETURN -1;

end

$$;


ALTER FUNCTION api.dispatcher_edit_contract(dispatcher_id_ integer, pass_ text, contract_id_ integer, contract_name_ text, contract_description_ text) OWNER TO postgres;

--
-- TOC entry 551 (class 1255 OID 16572)
-- Name: dispatcher_edit_cost_type(integer, text, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_cost_type(dispatcher_id_ integer, pass_ text, cost_type_id_ integer, cost_type_name_ character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Обновление типа затрат.
Возвращает либо id, либо -1.
*/
DECLARE cost_type_id integer default -1;
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(cost_type_id_,0)>0 then --обновить
  update data.cost_types set name=cost_type_name_
  where id=cost_type_id_ and dispatcher_id=dispatcher_id_  
  returning id into cost_type_id;
else
 insert into data.cost_types(id,name,dispatcher_id)
  values (nextval('data.cost_types_id_seq'),cost_type_name_,dispatcher_id_) 
  on conflict (name,dispatcher_id) do nothing
  returning id into cost_type_id;
end if;

return coalesce(cost_type_id,-1);

EXCEPTION
WHEN OTHERS THEN
  RETURN -1;

end

$$;


ALTER FUNCTION api.dispatcher_edit_cost_type(dispatcher_id_ integer, pass_ text, cost_type_id_ integer, cost_type_name_ character varying) OWNER TO postgres;

--
-- TOC entry 603 (class 1255 OID 16573)
-- Name: dispatcher_edit_dispatcher(integer, text, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_dispatcher(dispatcher_id_ integer, pass_ text, dispatcher_name_ character varying, dispatcher_email_ character varying, dispatcher_phone_ character varying, dispatcher_pass_ character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Редактирование себя диспетчером.
Возвращает либо true/false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
  return false;
end if;
 
 if dispatcher_pass_='' then
   dispatcher_pass_ = pass_;
 end if;
 
  update data.dispatchers set name=dispatcher_name_,
                   login=dispatcher_email_,
                   phone=dispatcher_phone_,
	               pass=dispatcher_pass_
	 where id=dispatcher_id_;	   
	 

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_dispatcher(dispatcher_id_ integer, pass_ text, dispatcher_name_ character varying, dispatcher_email_ character varying, dispatcher_phone_ character varying, dispatcher_pass_ character varying) OWNER TO postgres;

--
-- TOC entry 610 (class 1255 OID 16574)
-- Name: dispatcher_edit_dogovor(integer, text, bigint, integer, character varying, boolean, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_dogovor(dispatcher_id_ integer, pass_ text, dogovor_id_ bigint, dogovor_type_ integer, dogovor_name_ character varying, dogovor_archive_ boolean, files_ jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление договора.
Возвращает либо id, либо -1.
*/

DECLARE dogovor_dispatcher_id integer default 0;
DECLARE fact_dogovor_id bigint default 0;
DECLARE attach_doc_id bigint default 0;
DECLARE add_files jsonb default null;
DECLARE i integer;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(dogovor_id_,0)>0 then
 begin  
    select coalesce(dd.dispatcher_id,-1) from data.dispatcher_dogovors dd
     where dd.id=dogovor_id_ into dogovor_dispatcher_id;
  
    if dogovor_dispatcher_id<>dispatcher_id_ then
      return -1;
     end if;
  
     update data.dispatcher_dogovors set type_id=dogovor_type_,
				   name=dogovor_name_,
				   archive=dogovor_archive_
	    where id=dogovor_id_ and dispatcher_id=dispatcher_id_
	    returning id into fact_dogovor_id;
	 
     attach_doc_id = fact_dogovor_id;
 
      if coalesce(attach_doc_id,0)>0 then
        delete from data.dispatcher_dogovor_files ddf 
        where not (files_ ? ('id'||ddf.id)::text ) and ddf.dogovor_id=attach_doc_id;
      end if; 	 	
	
   end;   
  else /* Создание*/
     insert into data.dispatcher_dogovors(id,dispatcher_id,type_id,name,archive)
     values(nextval('data.dispatcher_dogovors_id_seq'),dispatcher_id_,dogovor_type_,dogovor_name_,dogovor_archive_)
	 returning id into fact_dogovor_id;
  end if;	 

    attach_doc_id = fact_dogovor_id;

  if cast(files_ as text)<>'' and cast(files_ as text)<>'{}' and cast(files_ as text)<>'[]' then
    begin
     add_files = (SELECT jsonb_object_agg(key, value)
                  FROM jsonb_each(files_)
                  WHERE
                  key NOT LIKE 'id%'
                  AND jsonb_typeof(value) != 'null');

      insert into data.dispatcher_dogovor_files(id,dogovor_id,filename,filepath,filesize)
  	    select nextval('data.dispatcher_dogovor_files_id_seq'),attach_doc_id,
	                cast(add_files->key->>'name' as text),
					cast(add_files->key->>'guid' as text),
					cast(add_files->key->>'size' as bigint)
	        FROM jsonb_each(add_files);
    end;
  end if;

return fact_dogovor_id;

end

$$;


ALTER FUNCTION api.dispatcher_edit_dogovor(dispatcher_id_ integer, pass_ text, dogovor_id_ bigint, dogovor_type_ integer, dogovor_name_ character varying, dogovor_archive_ boolean, files_ jsonb) OWNER TO postgres;

--
-- TOC entry 611 (class 1255 OID 16575)
-- Name: dispatcher_edit_driver(integer, text, integer, character varying, character varying, character varying, character varying, character varying, boolean, integer, integer, date, text, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_contract_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_restrictions_ jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление водителя.
Возвращает либо id, либо -1.
*/
DECLARE driver_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_id_,0)>0 then
 begin
 
  update data.drivers set name=driver_name_,
                   second_name=driver_second_name_,
				   family_name=driver_family_name_,
				   login=driver_login_,
				   pass=coalesce(driver_pass_,pass),
				   is_active=driver_is_active_,
				   level_id=driver_level_id_,
				   contract_id=driver_contract_id_,
				   date_of_birth=driver_date_of_birth_,
				   contact=driver_contact_,
				   contact2=driver_contact2_,
				   restrictions=driver_restrictions_
	 where id=driver_id_ and dispatcher_id=dispatcher_id_
	 returning id into driver_id;	   
	 
 end;
else
 begin
 
  insert into data.drivers (id,login,name,second_name,family_name,pass,is_active,level_id,contract_id,dispatcher_id,date_of_birth,contact,contact2,restrictions)
         values (nextval('data.drivers_id_seq'),driver_login_,driver_name_,driver_second_name_,driver_family_name_,driver_pass_,driver_is_active_,driver_level_id_,driver_contract_id_,dispatcher_id_,driver_date_of_birth_,driver_contact_,driver_contact2_,driver_restrictions_) 
		 returning id into driver_id;
		 
 end;
end if;

return coalesce(driver_id,-1);

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_contract_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_restrictions_ jsonb) OWNER TO postgres;

--
-- TOC entry 612 (class 1255 OID 16576)
-- Name: dispatcher_edit_driver_bank(integer, text, integer, text, text, text, text, text, text, text, character varying, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_bank(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_inn_ text, driver_kpp_ text, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_bank_card_ character varying, driver_ogrnip_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Обновление информации о банке.
Возвращает либо id, либо -1.
*/
DECLARE driver_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_id_,0)>0 then
 begin
 
  update data.drivers set inn=driver_inn_,
				   kpp=driver_kpp_,
				   bank=driver_bank_,
				   bik=driver_bik_,
				   korrschet=driver_korrschet_,
				   rasschet=driver_rasschet_,
				   poluchatel=driver_poluchatel_,
				   bank_card=driver_bank_card_,
				   ogrnip=driver_ogrnip_
	 where id=driver_id_ and dispatcher_id=dispatcher_id_
	 returning id into driver_id;	   
	 
 end;
end if;

return coalesce(driver_id,-1);

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_bank(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_inn_ text, driver_kpp_ text, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_bank_card_ character varying, driver_ogrnip_ text) OWNER TO postgres;

--
-- TOC entry 613 (class 1255 OID 16577)
-- Name: dispatcher_edit_driver_car(integer, text, integer, integer, character varying, character varying, character varying, numeric, numeric, integer, integer, integer, integer, boolean, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, weight_limit_ numeric, volume_limit_ numeric, trays_limit_ integer, pallets_limit_ integer, carclass_id_ integer, cartype_id_ integer, is_active_ boolean, tariffs_ jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE car_id integer default 0;
DECLARE _dispatcher_id integer default 0;
DECLARE car_count integer;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_car_id_,0)>0 then /*редактирование*/
 begin
  select coalesce(d.dispatcher_id,-1) from data.driver_cars dc
  left join data.drivers d on d.id=dc.driver_id
  where dc.id=driver_car_id_ into _dispatcher_id;
  if _dispatcher_id<>dispatcher_id_ then
   return -1;
  end if;

  delete from data.driver_car_tariffs dct 
   where dct.driver_car_id=driver_car_id_ and
   dct.tariff_id::text not in (select jsonb_array_elements(tariffs_)->>'tariff_id');

  update data.driver_cars set driver_id=driver_id_,
                   carclass_id=carclass_id_,
                   cartype_id=cartype_id_,
				   carmodel=carmodel_,
				   carnumber=carnumber_,
				   carcolor=carcolor_,
				   weight_limit=weight_limit_,
				   volume_limit=volume_limit_,
				   trays_limit=trays_limit_,
				   pallets_limit=pallets_limit_,
				   is_active=is_active_
	 where id=driver_car_id_
	 returning id into car_id;
 end;	 
else /*new car*/
 begin
  select coalesce(d.dispatcher_id,-1) from data.drivers d 
  where d.id=driver_id_ into _dispatcher_id;
  if _dispatcher_id<>dispatcher_id_ then
   return -1;
  end if;

	car_count = (select count(id) from data.driver_cars dc where dc.driver_id = driver_id_);

	insert into data.driver_cars (id,driver_id,carclass_id,cartype_id,carmodel,carnumber,carcolor,weight_limit,volume_limit,trays_limit,pallets_limit,is_active,is_default)
         values (nextval('data.driver_cars_id_seq'),driver_id_,carclass_id_,cartype_id_,carmodel_,carnumber_,carcolor_,weight_limit_,volume_limit_,trays_limit_,pallets_limit_,is_active_, case when car_count=0 then true else false end)
		 returning id into car_id;
 end;
end if; 

insert into data.driver_car_tariffs(id,driver_car_id,tariff_id)
  select nextval('data.driver_car_tariffs_id_seq'),car_id,(js.value->>'tariff_id')::int from jsonb_array_elements(tariffs_) js
  on conflict (driver_car_id,tariff_id) do nothing;

return car_id;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, weight_limit_ numeric, volume_limit_ numeric, trays_limit_ integer, pallets_limit_ integer, carclass_id_ integer, cartype_id_ integer, is_active_ boolean, tariffs_ jsonb) OWNER TO postgres;

--
-- TOC entry 614 (class 1255 OID 16578)
-- Name: dispatcher_edit_driver_car_docs(integer, text, integer, integer, text, text, date, date, date, boolean, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_car_docs(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, doc_type_ integer, doc_serie_ text, doc_number_ text, doc_date_ date, start_date_ date, end_date_ date, add_doc_ boolean, files_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE _dispatcher_id integer default 0;
DECLARE _doc_id integer default null;
DECLARE files_count integer default 0;
DECLARE add_files jsonb default null;
DECLARE i integer;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select coalesce(d.dispatcher_id,-1) from data.driver_cars dc
left join data.drivers d on d.id=dc.driver_id
where dc.id=driver_car_id_ into _dispatcher_id;
if _dispatcher_id<>dispatcher_id_ then
 return false;
end if;

if not add_doc_ then
 begin
   select dcd.id from data.driver_car_docs dcd 
    where dcd.driver_car_id=driver_car_id_ and dcd.doc_type=doc_type_
    into _doc_id;
 
   delete from data.driver_car_files dcf 
   where not (files_ ? ('id'||dcf.id)::text ) and dcf.doc_id=_doc_id;
  end;
end if;  

if add_doc_ or coalesce(_doc_id,0)=0 then
 insert into data.driver_car_docs(id,doc_type,driver_car_id,doc_serie,doc_number,doc_date,start_date,end_date)
 values (nextval('data.driver_car_docs_id_seq'),doc_type_,driver_car_id_,doc_serie_,doc_number_,doc_date_,start_date_,end_date_)
 returning id into _doc_id;
end if;

if files_ is NULL or cast(files_ as text)='' or cast(files_ as text)='{}' or cast(files_ as text)='[]' then
 return true;
end if; 

add_files = (SELECT jsonb_object_agg(key, value)
  FROM jsonb_each(files_)
  WHERE
    key NOT LIKE 'id%'
    AND jsonb_typeof(value) != 'null');

	/*RAISE EXCEPTION 'res = %', add_files;*/
	
    insert into data.driver_car_files(id,doc_id,filename,filepath,filesize)
	 select nextval('data.driver_car_files_id_seq'),_doc_id,
	                cast(add_files->key->>'name' as text),
					cast(add_files->key->>'guid' as text),
					cast(add_files->key->>'size' as bigint)
	 FROM jsonb_each(add_files);
 return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_car_docs(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, doc_type_ integer, doc_serie_ text, doc_number_ text, doc_date_ date, start_date_ date, end_date_ date, add_doc_ boolean, files_ jsonb) OWNER TO postgres;

--
-- TOC entry 617 (class 1255 OID 16579)
-- Name: dispatcher_edit_driver_dogovor(integer, text, integer, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_number text, dog_begin date, dog_end date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE dispatcher_id integer default 0;
DECLARE dog_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d where d.id=driver_id_ limit 1
into dispatcher_id;
if dispatcher_id<>dispatcher_id_ then
 return false;
end if; 

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=6
into dog_id;

if coalesce(dog_id,0)>0 then
 update data.driver_docs set doc_number=dog_number,
				   doc_date=dog_begin,
				   start_date=dog_begin,
				   end_date=dog_end
	                where id=dog_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_number,doc_date,start_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,6,dog_number,dog_begin,dog_begin,dog_end);
end if;						 

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_number text, dog_begin date, dog_end date) OWNER TO postgres;

--
-- TOC entry 618 (class 1255 OID 16580)
-- Name: dispatcher_edit_driver_med(integer, text, integer, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, med_number text, med_begin date, med_end date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE med_id bigint default 0;
DECLARE dispatcher_id integer default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d where d.id=driver_id_ limit 1
into dispatcher_id;
if dispatcher_id<>dispatcher_id_ then
 return false;
end if; 

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=5
into med_id;

if coalesce(med_id,0)>0 then
 update data.driver_docs set doc_number=med_number,
				   doc_date=med_begin,
				   end_date=med_end
	                where id=med_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,5,med_number,med_begin,med_end);
end if;						 

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, med_number text, med_begin date, med_end date) OWNER TO postgres;

--
-- TOC entry 619 (class 1255 OID 16581)
-- Name: dispatcher_edit_driver_passport(integer, text, integer, text, text, date, text, character varying, character varying, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_serie text, pass_number text, pass_date date, pass_from text, reg_addresse_ character varying, fact_addresse_ character varying, reg_address_lat_ numeric, reg_address_lng_ numeric, fact_address_lat_ numeric, fact_address_lng_ numeric) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE dispatcher_id integer default 0;
DECLARE pass_id bigint default 0;
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d where d.id=driver_id_ limit 1
into dispatcher_id;
if dispatcher_id<>dispatcher_id_ then
 return false;
end if; 

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=1
into pass_id;

if coalesce(pass_id,0)>0 then
 update data.driver_docs set doc_serie=pass_serie,
				   doc_number=pass_number,
				   doc_date=pass_date,
				   doc_from=pass_from
	                where id=pass_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,doc_from)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,1,pass_serie,pass_number,pass_date,pass_from);
end if;						 

update data.drivers set reg_addresse=reg_addresse_,
                        fact_addresse=fact_addresse_,
						reg_address_lat=reg_address_lat_,
						reg_address_lng=reg_address_lng_,
						fact_address_lat=fact_address_lat_,
						fact_address_lng=fact_address_lng_
						where id=driver_id_;

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_serie text, pass_number text, pass_date date, pass_from text, reg_addresse_ character varying, fact_addresse_ character varying, reg_address_lat_ numeric, reg_address_lng_ numeric, fact_address_lat_ numeric, fact_address_lng_ numeric) OWNER TO postgres;

--
-- TOC entry 620 (class 1255 OID 16582)
-- Name: dispatcher_edit_driver_strah(integer, text, integer, text, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, strah_serie text, strah_number text, strah_begin date, strah_end date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE strah_id bigint default 0;
DECLARE dispatcher_id integer default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;
select d.dispatcher_id from data.drivers d where d.id=driver_id_ limit 1
into dispatcher_id;
if dispatcher_id<>dispatcher_id_ then
 return false;
end if; 

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=4
into strah_id;

if coalesce(strah_id,0)>0 then
 update data.driver_docs set doc_serie=strah_serie,
                   doc_number=strah_number,
				   doc_date=strah_begin,
				   end_date=strah_end
	                where id=strah_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,4,strah_serie,strah_number,strah_begin,strah_end);
end if;						 


return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, strah_serie text, strah_number text, strah_begin date, strah_end date) OWNER TO postgres;

--
-- TOC entry 621 (class 1255 OID 16583)
-- Name: dispatcher_edit_driver_vu(integer, text, integer, text, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, vu_serie text, vu_number text, vu_begin date, vu_end date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE vu_id bigint default 0;
DECLARE dispatcher_id integer default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d where d.id=driver_id_ limit 1
into dispatcher_id;
if dispatcher_id<>dispatcher_id_ then
 return false;
end if; 

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=10
into vu_id;

if coalesce(vu_id,0)>0 then
 update data.driver_docs set doc_serie=vu_serie,
                   doc_number=vu_number,
				   doc_date=vu_begin,
				   end_date=vu_end
	                where id=vu_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,10,vu_serie,vu_number,vu_begin,vu_end);
end if;						 

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, vu_serie text, vu_number text, vu_begin date, vu_end date) OWNER TO postgres;

--
-- TOC entry 624 (class 1255 OID 16584)
-- Name: dispatcher_edit_feedback(integer, text, bigint, integer, integer, timestamp without time zone, real, date, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, driver_id_ integer, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, paid_ date, commentary_ text, files_ jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление платежа.
Возвращает либо id, либо -1.
*/

DECLARE feedback_dispatcher_id integer default 0;
DECLARE fact_feedback_id bigint default 0;
DECLARE attach_doc_id bigint default 0;
DECLARE add_files jsonb default null;
DECLARE i integer;
DECLARE action_text text;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(feedback_id_,0)>0 then
 begin  
    action_text = 'Edit';
	
    select coalesce(f.dispatcher_id,-1) from data.feedback f
     where f.id=feedback_id_ into feedback_dispatcher_id;
  
    if feedback_dispatcher_id<>dispatcher_id_ then
      return -1;
     end if;
  
     update data.feedback set driver_id=driver_id_,
				   opernumber=opernumber_,
				   operdate=operdate_,
				   summa=summa_,
				   paid=paid_,
				   commentary=commentary_
	    where id=feedback_id_ and dispatcher_id=dispatcher_id_
	    returning id into fact_feedback_id;
	 
     select fd.id from data.feedback_docs fd 
      where fd.feedback_id=fact_feedback_id
      into attach_doc_id;
 
      if coalesce(attach_doc_id,0)>0 then
        delete from data.feedback_files ff 
        where not (files_ ? ('id'||ff.id)::text ) and ff.doc_id=attach_doc_id;
      end if; 	 	
	
   end;   
  else /* Создание*/
     action_text = 'Create';
	
     insert into data.feedback(id,dispatcher_id,driver_id,opernumber,operdate,summa,paid,commentary)
     values(nextval('data.feedback_id_seq'),dispatcher_id_,driver_id_,opernumber_,operdate_,summa_,paid_,commentary_)
	 returning id into fact_feedback_id;
  end if;	 

 if coalesce(attach_doc_id,0)<1 then
  begin
    if cast(files_ as text)<>'' and cast(files_ as text)<>'{}' and cast(files_ as text)<>'[]' then
      insert into data.feedback_docs(id,feedback_id)
      values (nextval('data.feedback_docs_id_seq'),fact_feedback_id)
      returning id into attach_doc_id;   
    end if; 
   end;
  end if; 

  if cast(files_ as text)<>'' and cast(files_ as text)<>'{}' and cast(files_ as text)<>'[]' then
    begin
     add_files = (SELECT jsonb_object_agg(key, value)
                  FROM jsonb_each(files_)
                  WHERE
                  key NOT LIKE 'id%'
                  AND jsonb_typeof(value) != 'null');

      insert into data.feedback_files(id,doc_id,filename,filepath,filesize)
  	    select nextval('data.feedback_files_id_seq'),attach_doc_id,
	                cast(add_files->key->>'name' as text),
					cast(add_files->key->>'guid' as text),
					cast(add_files->key->>'size' as bigint)
	        FROM jsonb_each(add_files);
    end;
  end if;

insert into data.finances_log(id,payment_id,dispatcher_id,datetime,action_string)
     values (nextval('data.finances_log_id_seq'),fact_feedback_id,dispatcher_id_,CURRENT_TIMESTAMP,action_text) 
     on conflict do nothing;

return fact_feedback_id;

end

$$;


ALTER FUNCTION api.dispatcher_edit_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, driver_id_ integer, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, paid_ date, commentary_ text, files_ jsonb) OWNER TO postgres;

--
-- TOC entry 625 (class 1255 OID 16585)
-- Name: dispatcher_edit_ga(integer, text, bigint, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_ga(dispatcher_id_ integer, pass_ text, id_ bigint, google_original_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Коррекция гугл-адреса.
Возвращает либо true/false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
  return false;
end if;
 
  update data.google_addresses set google_original=google_original_id_
	 where id=id_ and dispatcher_id=dispatcher_id_;	   
	 

return true;

end

$$;


ALTER FUNCTION api.dispatcher_edit_ga(dispatcher_id_ integer, pass_ text, id_ bigint, google_original_id_ bigint) OWNER TO postgres;

--
-- TOC entry 626 (class 1255 OID 16586)
-- Name: dispatcher_edit_option(integer, text, integer, text, text, text, integer, real, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_option(dispatcher_id_ integer, pass_ text, section_id_ integer, param_name_ text, param_view_name_ text, param_value_text_ text, param_value_integer_ integer, param_value_real_ real, param_value_json_ jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Обновление настройки.
Возвращает либо id, либо -1.
*/
DECLARE option_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

insert into data."options"(id,dispatcher_id,section_id,param_name,param_view_name,param_value_text,param_value_integer,param_value_real,param_value_json)
  values (nextval('data.options_id_seq'),dispatcher_id_,section_id_,param_name_,param_view_name_,param_value_text_,param_value_integer_,param_value_real_,param_value_json_)
  on conflict(dispatcher_id,param_name) 
  do update set param_view_name=param_view_name_,
                param_value_text=param_value_text_,
				param_value_integer=param_value_integer_,
				param_value_real=param_value_real_,
				param_value_json=param_value_json_,
				section_id=section_id_
   returning id into option_id;

return coalesce(option_id,-1);

end

$$;


ALTER FUNCTION api.dispatcher_edit_option(dispatcher_id_ integer, pass_ text, section_id_ integer, param_name_ text, param_view_name_ text, param_value_text_ text, param_value_integer_ integer, param_value_real_ real, param_value_json_ jsonb) OWNER TO postgres;

--
-- TOC entry 627 (class 1255 OID 16587)
-- Name: dispatcher_edit_point(integer, text, integer, integer, character varying, character varying, text, character varying, bigint, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_point(dispatcher_id_ integer, pass_ text, point_id_ integer, group_id_ integer, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Редактирование/добавление точки.
Возвращает либо id, либо -1.
*/
DECLARE point_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(point_id_,0)>0 then
 begin

  update data.client_points set name=point_name_,
                   group_id=group_id_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where id=point_id_ and dispatcher_id=dispatcher_id_
	 returning id into point_id;	   
	 
 end;
else
 begin
  if exists(select 1 from data.client_points cp where cp.dispatcher_id=dispatcher_id_ and cp.code=point_code_) then 
     update data.client_points set name=point_name_,
	 			   group_id=group_id_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where code=point_code_ and dispatcher_id=dispatcher_id_
	 returning id into point_id;	   
  else 
   insert into data.client_points (id,dispatcher_id,name,address,description,code,visible,google_original,group_id)
         values (nextval('data.client_points_id_seq'),dispatcher_id_,point_name_,point_address_,point_description_,point_code_,point_visible_,google_original_id_,group_id_) 
		 returning id into point_id;
  end if;
		 
 end;
end if;

return coalesce(point_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.dispatcher_edit_point(dispatcher_id_ integer, pass_ text, point_id_ integer, group_id_ integer, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) OWNER TO postgres;

--
-- TOC entry 628 (class 1255 OID 16588)
-- Name: dispatcher_edit_point_by_group_code(integer, text, integer, character varying, character varying, character varying, text, character varying, bigint, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_point_by_group_code(dispatcher_id_ integer, pass_ text, point_id_ integer, group_code_ character varying, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Редактирование/добавление точки (с _кодом_ группы).
Возвращает либо id, либо -1.
*/
DECLARE point_id integer default -1;
DECLARE group_id_ integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

group_id_ = (select id from data.client_point_groups where code = group_code_);

if coalesce(group_id_,0)<1 then
 return -1;
end if; 
 
if coalesce(point_id_,0)>0 then
 begin

  update data.client_points set name=point_name_,
                   group_id=group_id_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where id=point_id_ and dispatcher_id=dispatcher_id_
	 returning id into point_id;	   
	 
 end;
else
 begin
  if exists(select 1 from data.client_points cp where cp.dispatcher_id=dispatcher_id_ and cp.code=point_code_) then 
     update data.client_points set name=point_name_,
	 			   group_id=group_id_,
                   address=point_address_,
				   description=point_description_,
				   google_original=google_original_id_,
				   visible=point_visible_
	 where code=point_code_ and dispatcher_id=dispatcher_id_
	 returning id into point_id;	   
  else 
   insert into data.client_points (id,dispatcher_id,name,address,description,code,visible,google_original,group_id)
         values (nextval('data.client_points_id_seq'),dispatcher_id_,point_name_,point_address_,point_description_,point_code_,point_visible_,google_original_id_,group_id_) 
		 returning id into point_id;
  end if;
		 
 end;
end if;

return coalesce(point_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.dispatcher_edit_point_by_group_code(dispatcher_id_ integer, pass_ text, point_id_ integer, group_code_ character varying, point_address_ character varying, point_name_ character varying, point_description_ text, point_code_ character varying, google_original_id_ bigint, point_visible_ boolean) OWNER TO postgres;

--
-- TOC entry 622 (class 1255 OID 16589)
-- Name: dispatcher_edit_point_coordinates(integer, text, integer, integer, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_point_coordinates(dispatcher_id_ integer, pass_ text, point_id_ integer, edit_id_ integer, latitude_ numeric, longitude_ numeric) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Редактирование/добавление дополнительных координат точки.
Возвращает либо id, либо -1.
*/
DECLARE edit_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(edit_id_,0)>0 then
  update data.dispatcher_point_coordinates set latitude=latitude_,
				   longitude=longitude_
	 where id=edit_id_ and dispatcher_id_=(select cp.dispatcher_id from data.client_points cp where cp.id=client_point_coordinates.point_id)
	 returning id into edit_id;	   
else
   insert into data.client_point_coordinates (id,point_id,latitude,longitude)
   values (nextval('data.client_point_coordinates_id_seq'),point_id_,latitude_,longitude_) 
   returning id into edit_id;
end if;

return coalesce(edit_id,-1);

EXCEPTION
WHEN OTHERS THEN 
  RETURN -1;
  
end

$$;


ALTER FUNCTION api.dispatcher_edit_point_coordinates(dispatcher_id_ integer, pass_ text, point_id_ integer, edit_id_ integer, latitude_ numeric, longitude_ numeric) OWNER TO postgres;

--
-- TOC entry 630 (class 1255 OID 16590)
-- Name: dispatcher_edit_pointgroup(integer, text, integer, text, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer, pointgroup_name_ text, pointgroup_description_ text, pointgroup_code_ character varying, OUT _pointgroup_id integer, OUT updated boolean) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление группы мест.
Возвращает либо id, либо -1 и updated = true/false
*/

begin

_pointgroup_id = -1;
updated = false;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if coalesce(pointgroup_id_,0)>0 then
 begin
  updated = true;
  update data.client_point_groups set name=pointgroup_name_,
				   description=pointgroup_description_,
				   code=pointgroup_code_
	 where id=pointgroup_id_ and dispatcher_id=dispatcher_id_
	 returning id into _pointgroup_id;	   
 end;
else
 begin																							  
     updated = false;																							 
     insert into data.client_point_groups (id,dispatcher_id,name,description,code)
         values (nextval('data.client_point_groups_id_seq'),dispatcher_id_,pointgroup_name_,pointgroup_description_,pointgroup_code_) 
		 returning id into _pointgroup_id;
  end;																							 
end if;

_pointgroup_id = coalesce(_pointgroup_id,-1);

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION api.dispatcher_edit_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer, pointgroup_name_ text, pointgroup_description_ text, pointgroup_code_ character varying, OUT _pointgroup_id integer, OUT updated boolean) OWNER TO postgres;

--
-- TOC entry 631 (class 1255 OID 16591)
-- Name: dispatcher_edit_route(integer, text, integer, text, numeric, text, boolean, boolean, integer, jsonb, integer, jsonb, time without time zone, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_route(dispatcher_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_base_sum_ numeric, route_description_ text, route_active_ boolean, route_docs_next_day_ boolean, route_difficulty_ integer, route_restrictions_ jsonb, route_client_id_ integer, route_load_data_ jsonb, route_load_time_ time without time zone, route_calculations_ jsonb, OUT edit_route_id integer, OUT updated boolean) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление маршрута.
Возвращает либо id, либо -1 и updated = true/false
*/

DECLARE i integer;
DECLARE calc_count integer;
DECLARE json_id integer;
DECLARE json_type_id integer;
DECLARE json_date date;
DECLARE json_data jsonb;

begin

edit_route_id = -1;
updated = false;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if coalesce(route_id_,0)>0 then
 begin
  updated = true;
  update data.dispatcher_routes set name=route_name_,
  				   base_sum = route_base_sum_,
                   description=route_description_,
				   active=route_active_,
				   docs_next_day = route_docs_next_day_,
				   difficulty_id = route_difficulty_,
				   restrictions = route_restrictions_,
				   client_id = route_client_id_,
				   load_data = route_load_data_,
				   load_time = route_load_time_
	 where id=route_id_ and dispatcher_id=dispatcher_id_
	 returning id into edit_route_id;	   	 

   delete from data.dispatcher_route_calculations where id=edit_route_id;  

end;
else
 begin
  if exists(select 1 from data.dispatcher_routes r where r.dispatcher_id=dispatcher_id_ and upper(r.name)=upper(route_name_)) then 
	begin																						 
	  updated = true;																							 
      update data.dispatcher_routes set name=route_name_,
	               base_sum = route_base_sum_,
				   description=route_description_,
				   active=route_active_,
				   docs_next_day = route_docs_next_day_,
				   difficulty_id = route_difficulty_,
				   restrictions = route_restrictions_,
				   client_id = route_client_id_,
				   load_data = route_load_data_,
				   load_time = route_load_time_
	  where upper(name)=upper(route_name_) and dispatcher_id=dispatcher_id_
	  returning id into edit_route_id;	  

      delete from data.dispatcher_route_calculations where id=edit_route_id;  
    end;																							 
  else
   begin																							  
     updated = false;																							 
     insert into data.dispatcher_routes (id,dispatcher_id,name,base_sum,description,active,docs_next_day,difficulty_id,restrictions,client_id,load_data,load_time)
         values (nextval('data.dispatcher_routes_id_seq'),dispatcher_id_,route_name_,route_base_sum_,route_description_,route_active_,route_docs_next_day_,route_difficulty_,route_restrictions_,route_client_id_,route_load_data_,route_load_time_) 
		 returning id into edit_route_id;
    end;																							 
  end if;
		 
 end;
end if;

calc_count = jsonb_array_length(route_calculations_);
FOR i IN 0..(calc_count-1) LOOP
   begin
    json_id = cast(route_calculations_->i->>'id' as integer);
	json_date = cast(route_calculations_->i->>'date' as date);
    json_type_id = cast(route_calculations_->i->>'type_id' as integer);
    json_data  = cast(route_calculations_->i->>'data' as jsonb);
	
	insert into data.dispatcher_route_calculations (id,route_id,calc_date,calc_type_id,calc_data)  
	  values(case when json_id<0 then nextval('data.dispatcher_route_calculations_id_seq') else json_id end,
			 edit_route_id,
			 json_date,
			 json_type_id,
			 json_data)
	on conflict (id) do update
	set (route_id,calc_date,calc_type_id,calc_data) = (excluded.route_id,excluded.calc_date,excluded.calc_type_id,excluded.calc_data);
	

   end;
END LOOP;   


edit_route_id = coalesce(edit_route_id,-1);


return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION api.dispatcher_edit_route(dispatcher_id_ integer, pass_ text, route_id_ integer, route_name_ text, route_base_sum_ numeric, route_description_ text, route_active_ boolean, route_docs_next_day_ boolean, route_difficulty_ integer, route_restrictions_ jsonb, route_client_id_ integer, route_load_data_ jsonb, route_load_time_ time without time zone, route_calculations_ jsonb, OUT edit_route_id integer, OUT updated boolean) OWNER TO postgres;

--
-- TOC entry 632 (class 1255 OID 16592)
-- Name: dispatcher_edit_tariff(integer, text, integer, text, text, date, date, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_edit_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer, tariff_name_ text, tariff_description_ text, tariff_begin_date_ date, tariff_end_date_ date, percents_ jsonb, OUT _tariff_id integer, OUT updated boolean) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Редактирование/добавление тарифа.
Возвращает либо id, либо -1 и updated = true/false
*/
DECLARE costs_count integer default 0;
DECLARE i integer;
DECLARE cost_id integer;

begin

_tariff_id = -1;
updated = false;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

costs_count = jsonb_array_length(percents_);
	 

if coalesce(tariff_id_,0)>0 then
 begin
  updated = true;
  update data.tariffs set name=tariff_name_,
				   description=tariff_description_,
				   begin_date=tariff_begin_date_,
				   end_date=tariff_end_date_
	 where id=tariff_id_ and dispatcher_id=dispatcher_id_
	 returning id into _tariff_id;	   

   with ids as (
    select jsonb_array_elements(percents_)->>'id' id
   )
  delete from data.tariff_costs tc
   where tc.tariff_id=tariff_id_ and not exists(select 1 from ids i where tc.id=i.id::int);

 end;
else
 begin																							  
     updated = false;																							 
     insert into data.tariffs (id,dispatcher_id,name,description,begin_date,end_date)
         values (nextval('data.tariffs_id_seq'),dispatcher_id_,tariff_name_,tariff_description_,tariff_begin_date_,tariff_end_date_) 
		 returning id into _tariff_id;
  end;																							 
end if;


FOR i IN 0..(costs_count-1) LOOP
 begin
  cost_id = cast(percents_->i->>'id' as integer);
  if cost_id > 0 then
     update data.tariff_costs set name = cast(percents_->i->>'name' as text),
	                              percent = cast(percents_->i->>'percent' as numeric)
     where id = cost_id;	 
  else
    insert into data.tariff_costs (id,tariff_id,name,percent)  
	  values(nextval('data.tariff_costs_id_seq'),_tariff_id,
			 cast(percents_->i->>'name' as text),
			 cast(percents_->i->>'percent' as numeric));
   end if;			 
 end;			 
END LOOP;

_tariff_id = coalesce(_tariff_id,-1);

return;

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION api.dispatcher_edit_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer, tariff_name_ text, tariff_description_ text, tariff_begin_date_ date, tariff_end_date_ date, percents_ jsonb, OUT _tariff_id integer, OUT updated boolean) OWNER TO postgres;

--
-- TOC entry 633 (class 1255 OID 16593)
-- Name: dispatcher_finish_order(bigint, integer, text, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_finish_order(order_id_ bigint, dispatcher_id_ integer, pass_ text, from_changes_ boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Завершение маршрута. 
*/ 
DECLARE order_id BIGINT;
DECLARE order_summa NUMERIC;
DECLARE order_driver_id INT;
DECLARE car_id INT;
DECLARE dispatcher_id INT;
DECLARE curr_status_id INT;

DECLARE from_date date;
DECLARE lat numeric;
DECLARE lng numeric;

DECLARE agg_summa numeric DEFAULT 0;
DECLARE agg_name text;

DECLARE job_id BIGINT;
DECLARE job_nodename TEXT;
DECLARE job_schedule TEXT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.driver_id,coalesce(o.status_id,0),o.summa,o.from_time::date,o.from_addr_latitude,o.from_addr_longitude,(o.driver_car_attribs->>'car_id')::int  
  FROM data.orders o 
   where o.id=order_id_ FOR UPDATE
   into order_id,order_driver_id,curr_status_id,order_summa,from_date,lat,lng,car_id;
  select d.dispatcher_id from data.drivers d
   where d.id = order_driver_id FOR UPDATE
   into dispatcher_id;

  IF order_id is null 
  or (curr_status_id<>110 and not from_changes_) /* Заказ выполняется */ 
  or dispatcher_id<>dispatcher_id_ 
  THEN
	 return false;
  ELSE
    BEGIN
	 if not from_changes_ then
       UPDATE data.orders set status_id=120, /* Заказ выполнен по мнению водителя */
	                      end_time = CURRENT_TIMESTAMP
		  				  where id=order_id_;
	 end if;

      job_schedule = '* * * * *';
      job_nodename = (select param_value_string from sysdata."SYS_PARAMS" where param_name = 'CRON_NODENAME');
      job_id = cron.schedule(job_schedule, 'select count(*) from data.log');
      update cron.job set nodename = job_nodename,
                          command = 'select sysdata.cron_fill_order_location(' || order_id_::text || ',' || order_driver_id::text || ',' || job_id || ')'
             where jobid = job_id;

	select cc.name,round(cc.stavka*order_summa/100.) from aggregator_api.calc_commission(from_date,lat,lng) cc
	into agg_name,agg_summa;
	
     delete from data.order_costs o where o.order_id=order_id_;
	 insert into data.order_costs(id,order_id,cost_id,summa)
	  select nextval('data.order_costs_id_seq'),order_id_,dc.cost_id,round(dc.percent*(order_summa-agg_summa)/100.)
	   from data.driver_costs dc where dc.driver_id=order_driver_id and dc.percent<>0;
	   
	with calc_tariff_costs as
	(
		select tc.id,tc.percent from data.tariff_costs tc
		left join data.tariffs t on tc.tariff_id=t.id
		left join data.driver_car_tariffs dct on dct.tariff_id=tc.tariff_id
		left join data.driver_cars dc on dc.id=dct.driver_car_id
		where dc.id=car_id and dc.driver_id=order_driver_id 
		and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date
	)
	insert into data.order_costs(id,order_id,tariff_cost_id,summa)
	 select nextval('data.order_costs_id_seq'),order_id_,ctc.id,round(ctc.percent*(order_summa-agg_summa)/100.)
	  from calc_tariff_costs ctc where ctc.percent<>0;

   delete from data.order_agg_costs o where o.order_id=order_id_;  
	 if agg_summa<>0 then
	   insert into data.order_agg_costs(id,order_id,cost_name,summa)
	    values(nextval('data.order_agg_costs_id_seq'),order_id_,agg_name,agg_summa);
	 end if;  
/*
    insert into data.order_agg_costs(id,order_id,cost_name,summa)
	  select nextval('data.order_agg_costs_id_seq'),order_id_,cc.name,round(cc.stavka*order_summa/100.)
	   from aggregator_api.calc_commission(from_date,lat,lng) cc where cc.stavka<>0;
*/
	if not from_changes_ then
	  insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,status_old,action_string)
      values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,order_driver_id,CURRENT_TIMESTAMP,120,110,'Finish') 
       on conflict do nothing;
	 end if;  
						  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.dispatcher_finish_order(order_id_ bigint, dispatcher_id_ integer, pass_ text, from_changes_ boolean) OWNER TO postgres;

--
-- TOC entry 634 (class 1255 OID 16594)
-- Name: dispatcher_fire_driver(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_fire_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Открепление (увольнение) водителя.
Возвращает либо true, либо false.
*/
DECLARE driver_dispatcher_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d
 where d.id=driver_id_ into driver_dispatcher_id
  FOR UPDATE;

if driver_dispatcher_id<>dispatcher_id_ then
 return false;
end if;

update data.drivers set dispatcher_id=NULL
 where id=driver_id_;

return true;

end

$$;


ALTER FUNCTION api.dispatcher_fire_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 635 (class 1255 OID 16595)
-- Name: dispatcher_get_addsum(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ integer, OUT driver_id integer, OUT driver_name text, OUT operdate date, OUT commentary text, OUT summa numeric, OUT is_deleted boolean, OUT scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select a.driver_id,
        coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
	    a.operdate,
	    a.commentary,
		a.summa,
		a.is_deleted,
		(select array_to_json(ARRAY( SELECT json_build_object('filename',af.filename,
									   'filepath',af.filepath,
									   'filesize',af.filesize,
									   'doc_id',af.doc_id,
									   'id',af.id)
           FROM data.addsums_files af 
		   left join data.addsums_docs ad on ad.id=af.doc_id
		   where ad.addsum_id=a.id)))
 from data.addsums a
 left join data.drivers d on d.id=a.driver_id
 where a.id=addsum_id_ and a.dispatcher_id=dispatcher_id_
  into driver_id,
       driver_name,
	   operdate,
	   commentary,
	   summa,
	   is_deleted,
	   scan;

END

$$;


ALTER FUNCTION api.dispatcher_get_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ integer, OUT driver_id integer, OUT driver_name text, OUT operdate date, OUT commentary text, OUT summa numeric, OUT is_deleted boolean, OUT scan text) OWNER TO postgres;

--
-- TOC entry 636 (class 1255 OID 16596)
-- Name: dispatcher_get_autocreate_log(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_autocreate_log(dispatcher_id_ integer, pass_ text, log_id_ bigint, OUT action_result jsonb, OUT datetime timestamp without time zone) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр записи лога об автосоздании.
*/
BEGIN

datetime = null;
action_result = null;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

select al.datetime,al.action_result from data.autocreate_logs al 
where al.id = log_id_ and al.dispatcher_id = dispatcher_id_
into datetime,action_result;

END

$$;


ALTER FUNCTION api.dispatcher_get_autocreate_log(dispatcher_id_ integer, pass_ text, log_id_ bigint, OUT action_result jsonb, OUT datetime timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 637 (class 1255 OID 16597)
-- Name: dispatcher_get_bar_1(integer, text, integer, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_bar_1(dispatcher_id_ integer, pass_ text, driver_id_ integer, intervals_ jsonb) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр графика работы за периоды.
*/
DECLARE driver_dispatcher_id INTEGER DEFAULT NULL;
DECLARE intervals_count INTEGER DEFAULT 0;
declare i integer;
declare date1 date default null;
declare date2 date default null;
declare days integer;
declare array_days integer[];
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
 begin
 /*Проверю, может ли он видеть этого водителя*/
 	select d.dispatcher_id from data.drivers d where d.id=driver_id_
	 into driver_dispatcher_id;
	
	if driver_dispatcher_id<>dispatcher_id_ then
     return '';
    end if;
 end;
else
 return '';
end if;

array_days = ARRAY[]::integer[];
intervals_count = jsonb_array_length(intervals_);
FOR i IN 0..(intervals_count-1) LOOP
   begin
    date1 = cast(intervals_->i->>'begin' as date);
	date2 = cast(intervals_->i->>'end' as date);
	select count(distinct(o.from_time::date)) from data.orders o 
	 where o.driver_id=driver_id_ and date1<=o.from_time::date and o.from_time::date<=date2
	  and o.status_id>=110 into days;
	
	array_days = array_append(array_days,coalesce(days,0));
	
   end;
END LOOP;   

return array_to_json(array_days);

END

$$;


ALTER FUNCTION api.dispatcher_get_bar_1(dispatcher_id_ integer, pass_ text, driver_id_ integer, intervals_ jsonb) OWNER TO postgres;

--
-- TOC entry 638 (class 1255 OID 16598)
-- Name: dispatcher_get_checkpoint(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_checkpoint(dispatcher_id_ integer, pass_ text, checkpoint_id_ bigint) RETURNS TABLE(order_id bigint, to_addr_name character varying, to_addr_latitude numeric, to_addr_longitude numeric, kontakt_name character varying, kontakt_phone character varying, notes character varying, visited_status boolean, visited_time timestamp without time zone, position_in_order integer, by_driver boolean, accepted boolean, photos jsonb, order_title character varying, order_driver text, order_client character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр данных по чекпойнту.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

RETURN QUERY  
	SELECT c.order_id,
	c.to_addr_name,
	c.to_addr_latitude,
	c.to_addr_longitude,
	c.kontakt_name,
	c.kontakt_phone,
	c.notes,
    COALESCE(c.visited_status, false) AS visited_status,
	c.visited_time,			  
    c.position_in_order,
    coalesce(c.by_driver,false) as by_driver,				  
    coalesce(c.accepted,false) as accepted,	  
    c.photos,
	o.order_title,
	coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
	cl.name
	
   FROM data.checkpoints c
   LEFT JOIN data.orders o on o.id=c.order_id
   LEFT JOIN data.drivers d on d.id=o.driver_id
   LEFT JOIN data.clients cl on cl.id=o.client_id
  WHERE c.id = checkpoint_id_ and 
        o.dispatcher_id=dispatcher_id_ and 
		not coalesce(o.is_deleted, false) and 
		coalesce(o.visible, true);
  
END

$$;


ALTER FUNCTION api.dispatcher_get_checkpoint(dispatcher_id_ integer, pass_ text, checkpoint_id_ bigint) OWNER TO postgres;

--
-- TOC entry 639 (class 1255 OID 16599)
-- Name: dispatcher_get_dashboard_hash(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_dashboard_hash(dispatcher_id_ integer, pass_ text) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр только списка id dashboard.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return '[]'::json;
end if;

 RETURN array_to_json(ARRAY( 
	 SELECT id FROM data.orders
     WHERE o.dispatcher_id=dispatcher_id_ and not coalesce(o.is_deleted, false) and coalesce(o.visible, true)
	 ));
  
END

$$;


ALTER FUNCTION api.dispatcher_get_dashboard_hash(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 640 (class 1255 OID 16600)
-- Name: dispatcher_get_dispatcher(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_dispatcher(dispatcher_id_ integer, pass_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр своих данных.
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return '';
end if;

RETURN
 (select json_build_object(
		 'id',d.id,
	     'name',d.name,
		 'email',d.login,
	     'phone',d.phone,
	     'token',d.token)
 from data.dispatchers d
 where d.id=dispatcher_id_);

END

$$;


ALTER FUNCTION api.dispatcher_get_dispatcher(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 641 (class 1255 OID 16601)
-- Name: dispatcher_get_dogovor(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_dogovor(dispatcher_id_ integer, pass_ text, dogovor_id_ integer, OUT dogovor_type integer, OUT dogovor_name character varying, OUT archive boolean, OUT docs text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.type_id,
        dd.name,
	    dd.archive,
		(select array_to_json(ARRAY( SELECT json_build_object('filename',ddf.filename,
									   'filepath',ddf.filepath,
									   'filesize',ddf.filesize,
									   'doc_id',ddf.dogovor_id,
									   'id',ddf.id)
           FROM data.dispatcher_dogovor_files ddf 
		   where ddf.dogovor_id=dd.id)))
 from data.dispatcher_dogovors dd
 where dd.id=dogovor_id_ and dd.dispatcher_id=dispatcher_id_
  into dogovor_type,
       dogovor_name,
	   archive,
	   docs;

END

$$;


ALTER FUNCTION api.dispatcher_get_dogovor(dispatcher_id_ integer, pass_ text, dogovor_id_ integer, OUT dogovor_type integer, OUT dogovor_name character varying, OUT archive boolean, OUT docs text) OWNER TO postgres;

--
-- TOC entry 642 (class 1255 OID 16602)
-- Name: dispatcher_get_dogovor_files(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_dogovor_files(dispatcher_id_ integer, pass_ text, dogovor_id_ integer) RETURNS TABLE(id bigint, filename text, filepath text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 100
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT ddf.id,ddf.filename,ddf.filepath from data.dispatcher_dogovor_files ddf
	left join data.dispatcher_dogovors dd on dd.id=dogovor_id_
	where ddf.dogovor_id=dogovor_id_ and dd.dispatcher_id=dispatcher_id_;

END

$$;


ALTER FUNCTION api.dispatcher_get_dogovor_files(dispatcher_id_ integer, pass_ text, dogovor_id_ integer) OWNER TO postgres;

--
-- TOC entry 643 (class 1255 OID 16603)
-- Name: dispatcher_get_driver_car(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT driver_id integer, OUT driver_full_name character varying, OUT driver_is_active boolean, OUT carmodel text, OUT weight_limit numeric, OUT volume_limit numeric, OUT trays_limit integer, OUT pallets_limit integer, OUT carnumber text, OUT carcolor text, OUT carclass_id integer, OUT carclass_name character varying, OUT cartype_id integer, OUT cartype_name character varying, OUT is_active boolean, OUT is_default boolean, OUT tariffs jsonb, OUT photos text, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dc.driver_id,
        cast(coalesce(dd.family_name,'')||' '||coalesce(dd.name,'')||' '||coalesce(dd.second_name,'') as character varying),
		dd.is_active,
        dc.carmodel,
		dc.weight_limit, 
		dc.volume_limit,
		dc.trays_limit, 
		dc.pallets_limit,
	    dc.carnumber,
	    dc.carcolor,
		dc.carclass_id,
		cc.name,
	    dc.cartype_id,
		ct.name,
	    dc.is_active,
	    coalesce(dc.is_default,false),
		(select array_to_json(ARRAY( SELECT json_build_object('tariff_id',dct.tariff_id,
									   'id',dct.id)
           FROM data.driver_car_tariffs dct 
		   where dct.driver_car_id=dc.id))),
		(select array_to_json(ARRAY( SELECT json_build_object('filename',dcf.filename,
									   'filepath',dcf.filepath,
									   'filesize',dcf.filesize,
									   'doc_id',dcf.doc_id,
									   'id',dcf.id)
           FROM data.driver_car_files dcf 
		   left join data.driver_car_docs dcd on dcd.id=dcf.doc_id and dcd.doc_type=11
		   where dcd.driver_car_id=dc.id))),
	    pts.doc_serie,
	    pts.doc_number,
		(select array_to_json(ARRAY( SELECT json_build_object('filename',dcf.filename,
									   'filepath',dcf.filepath,
									   'filesize',dcf.filesize,
									   'doc_id',dcf.doc_id,
									   'id',dcf.id)
           FROM data.driver_car_files dcf 
		   left join data.driver_car_docs dcd on dcd.id=dcf.doc_id and dcd.doc_type=2
		   where dcd.driver_car_id=dc.id))),
		sts.doc_serie,
	    sts.doc_number,
		(select array_to_json(ARRAY( SELECT json_build_object('filename',dcf.filename,
									   'filepath',dcf.filepath,
									   'filesize',dcf.filesize,
									   'doc_id',dcf.doc_id,
									   'id',dcf.id)
           FROM data.driver_car_files dcf 
		   left join data.driver_car_docs dcd on dcd.id=dcf.doc_id and dcd.doc_type=3
		   where dcd.driver_car_id=dc.id)))
 from data.driver_cars dc
 left join data.drivers dd on dc.driver_id=dd.id
 left join sysdata."SYS_CARCLASSES" cc on dc.carclass_id=cc.id
 left join sysdata."SYS_CARTYPES" ct on dc.cartype_id=ct.id
 left join data.driver_car_docs pts on pts.driver_car_id=dc.id and pts.doc_type=2
 left join data.driver_car_docs sts on sts.driver_car_id=dc.id and sts.doc_type=3
 where dc.id=driver_car_id_ and dd.dispatcher_id=dispatcher_id_
  into driver_id,
       driver_full_name,
	   driver_is_active,
       carmodel,
	   weight_limit, 
	   volume_limit,
	   trays_limit, 
	   pallets_limit,
	   carnumber,
	   carcolor,
	   carclass_id,
	   carclass_name,
	   cartype_id,
	   cartype_name,
	   is_active,
	   is_default,
	   tariffs,
	   photos,
	   ptsnumber,
	   ptsserie,
	   ptsscan,
	   stsnumber,
	   stsserie,
   	   stsscan;

END

$$;


ALTER FUNCTION api.dispatcher_get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT driver_id integer, OUT driver_full_name character varying, OUT driver_is_active boolean, OUT carmodel text, OUT weight_limit numeric, OUT volume_limit numeric, OUT trays_limit integer, OUT pallets_limit integer, OUT carnumber text, OUT carcolor text, OUT carclass_id integer, OUT carclass_name character varying, OUT cartype_id integer, OUT cartype_name character varying, OUT is_active boolean, OUT is_default boolean, OUT tariffs jsonb, OUT photos text, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) OWNER TO postgres;

--
-- TOC entry 644 (class 1255 OID 16604)
-- Name: dispatcher_get_driver_car_files(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_driver_car_files(dispatcher_id_ integer, pass_ text, car_id_ integer) RETURNS TABLE(id bigint, doc_id bigint, doc_type integer, filename text, filepath text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE _dispatcher_id integer;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

/*Проверю, что машина подчинена диспетчеру*/
select d.dispatcher_id from data.driver_cars dc
left join data.drivers d on d.id=dc.driver_id
where dc.id=car_id_
into _dispatcher_id;

if coalesce(_dispatcher_id,0)<>dispatcher_id_ then
 return;
end if; 
 
 RETURN QUERY  
	SELECT dcf.id,dcf.doc_id,dcd.doc_type,dcf.filename,dcf.filepath from data.driver_car_files dcf
	left join data.driver_cars_doc dcd on dcf.doc_id=dcd.id
	where dcd.driver_car_id=car_id_;

END

$$;


ALTER FUNCTION api.dispatcher_get_driver_car_files(dispatcher_id_ integer, pass_ text, car_id_ integer) OWNER TO postgres;

--
-- TOC entry 645 (class 1255 OID 16605)
-- Name: dispatcher_get_driver_distance(integer, text, integer, timestamp without time zone, timestamp without time zone, numeric, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_driver_distance(dispatcher_id_ integer, pass_ text, driver_id_ integer, time1_ timestamp without time zone, time2_ timestamp without time zone, load_lat_ numeric, load_lng_ numeric) RETURNS real
    LANGUAGE plpgsql IMMUTABLE
    AS $$

DECLARE full_distance real default 0;
DECLARE first_time bool default true;
DECLARE lat1 numeric;
DECLARE lng1 numeric;
DECLARE lat2 numeric;
DECLARE lng2 numeric;
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return 0;
end if;
--if driver_id_=94 then
--RAISE NOTICE 'driver=%, time1=%, time2=%s',driver_id_,time1_,time2_;		
--end if;
for lat2,lng2 in select dhl.curr_latitude,dhl.curr_longitude from data.driver_history_locations dhl 
  where dhl.driver_id=driver_id_ and dhl.loc_time>=coalesce(time1_,CURRENT_TIMESTAMP) and dhl.loc_time<=coalesce(time2_,CURRENT_TIMESTAMP)
   loop
     if first_time then
	   first_time = false;
	   lat1 = load_lat_;
	   lng1 = load_lng_;
	 end if;

     full_distance = full_distance + sysdata.get_distance(lat1,lng1,lat2,lng2);
	 
	 lat1 = lat2;
	 lng1 = lng2;
   end loop;

RETURN full_distance;

END

$$;


ALTER FUNCTION api.dispatcher_get_driver_distance(dispatcher_id_ integer, pass_ text, driver_id_ integer, time1_ timestamp without time zone, time2_ timestamp without time zone, load_lat_ numeric, load_lng_ numeric) OWNER TO postgres;

--
-- TOC entry 646 (class 1255 OID 16606)
-- Name: dispatcher_get_driver_locations(integer, text, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_driver_locations(dispatcher_id_ integer, pass_ text, driver_id_ integer, begin_time_ timestamp without time zone, end_time_ timestamp without time zone) RETURNS TABLE(latitude numeric, longitude numeric, loc_time timestamp without time zone, device_id text, device_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE _dispatcher_id integer;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

/*Проверю, что водитель подчинен диспетчеру*/
select d.dispatcher_id from data.drivers d
where d.id=driver_id_
into _dispatcher_id;

if coalesce(_dispatcher_id,0)<>dispatcher_id_ then
 return;
end if; 
 
 RETURN QUERY  
   select dhl.curr_latitude,dhl.curr_longitude,dhl.loc_time,dd.device_id,dd.device_name from data.driver_history_locations dhl 
   left join data.driver_devices dd on dd.id=dhl.device_id
   where dhl.driver_id=driver_id_ and 
   dhl.loc_time>=begin_time_ and dhl.loc_time<=coalesce(end_time_,dhl.loc_time);
END

$$;


ALTER FUNCTION api.dispatcher_get_driver_locations(dispatcher_id_ integer, pass_ text, driver_id_ integer, begin_time_ timestamp without time zone, end_time_ timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 647 (class 1255 OID 16607)
-- Name: dispatcher_get_driver_position(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_driver_position(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT latitude numeric, OUT longitude numeric, OUT mark_time timestamp without time zone) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается клиентом.
Просмотр координат водителя.
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

latitude = 0;
longitude = 0;
select dcl.latitude,dcl.longitude,dcl.loc_time from data.driver_current_locations dcl 
left join data.drivers d on d.id=driver_id
where dcl.driver_id = driver_id_ and d.dispatcher_id=dispatcher_id_
into latitude,longitude,mark_time;

END

$$;


ALTER FUNCTION api.dispatcher_get_driver_position(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT latitude numeric, OUT longitude numeric, OUT mark_time timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 648 (class 1255 OID 16608)
-- Name: dispatcher_get_feedback(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ integer, OUT driver_id integer, OUT driver_name text, OUT opernumber integer, OUT operdate date, OUT commentary text, OUT summa numeric, OUT paid date, OUT is_deleted boolean, OUT scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select f.driver_id,
        coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
	    f.opernumber,
	    f.operdate,
	    f.commentary,
		f.summa,
		f.paid,
		f.is_deleted,
		(select array_to_json(ARRAY( SELECT json_build_object('filename',ff.filename,
									   'filepath',ff.filepath,
									   'filesize',ff.filesize,
									   'doc_id',ff.doc_id,
									   'id',ff.id)
           FROM data.feedback_files ff 
		   left join data.feedback_docs fd on fd.id=ff.doc_id
		   where fd.feedback_id=f.id)))
 from data.feedback f
 left join data.drivers d on d.id=f.driver_id
 where f.id=feedback_id_ and f.dispatcher_id=dispatcher_id_
  into driver_id,
       driver_name,
	   opernumber,
	   operdate,
	   commentary,
	   summa,
	   paid,
	   is_deleted,
	   scan;

END

$$;


ALTER FUNCTION api.dispatcher_get_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ integer, OUT driver_id integer, OUT driver_name text, OUT opernumber integer, OUT operdate date, OUT commentary text, OUT summa numeric, OUT paid date, OUT is_deleted boolean, OUT scan text) OWNER TO postgres;

--
-- TOC entry 629 (class 1255 OID 16609)
-- Name: dispatcher_get_ga(integer, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_ga(dispatcher_id_ integer, pass_ text, address_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр координат водителя по адресу.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return '';
end if;

return (select json_build_object(
		 'address_id',ga.id,
	     'point_id',cp.id,
	     'point_code',cp.code,
	     'original_id',ga.google_original,
	     'latitude',coalesce(gm.latitude,gor.latitude),
	     'longitude',coalesce(gm.longitude,gor.longitude))
 from data.google_addresses ga
 left join data.google_originals gor on ga.google_original=gor.id	
 left join data.google_modifiers gm on gm.original_id=gor.id and gm.dispatcher_id=ga.dispatcher_id
 left join data.client_points cp on cp.google_original=gor.id and cp.dispatcher_id=dispatcher_id_
 where ga.dispatcher_id=dispatcher_id_ and trim(upper(address_))=trim(upper(ga.address)) LIMIT 1);

END

$$;


ALTER FUNCTION api.dispatcher_get_ga(dispatcher_id_ integer, pass_ text, address_ text) OWNER TO postgres;

--
-- TOC entry 649 (class 1255 OID 16610)
-- Name: dispatcher_get_order(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, OUT selected_driver integer, OUT selected_driver_full_name text, OUT json_data text, OUT json_checkpoints text, OUT json_selected_drivers text, OUT offer_time timestamp without time zone, OUT json_stops text, OUT json_ratings text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр заказа.
*/
DECLARE sel_id BIGINT DEFAULT NULL;
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
 begin
 /*Проверю, может ли он это видеть*/
   if not sysdata.order4dispatcher(order_id_, dispatcher_id_) then
     return;
    end if;
 end;
else
 return;
end if;

select dso.id from data.dispatcher_selected_orders dso 
where dso.order_id=order_id_ and dso.dispatcher_id=dispatcher_id_ and dso.is_active
into sel_id;

select json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'from_time',o.from_time,
		 'point_id',o.point_id,
		 'point_name',p.name,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
	     'from_addr_longitude',o.from_addr_longitude,
	     'from_kontakt_name',o.from_kontakt_name,
	     'from_kontakt_phone',o.from_kontakt_phone,
	     'from_notes',o.from_notes,
	     'summa',o.summa,
		 'dispatcher_id',o.dispatcher_id,
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'carclass_name',cc.name,
		 'paytype_id',coalesce(o.paytype_id,0),
		 'paytype_name',pt.name,
		 'hours',coalesce(o.hours,0),
		 'client_id',o.client_id,
		 'client_name',cl.name,
		 'client_code',o.client_code,
	     'driver_car_attribs',o.driver_car_attribs,
		 'is_deleted',o.is_deleted,
		 'del_time',o.del_time,
		 'distance',o.distance,
		 'duration',o.duration,
	     'duration_calc',o.duration_calc,
		 'notes',o.notes,
	     'selected', sel_id,
	     'favorite', coalesce(dfo.favorite, false),
		 'visible',o.visible,
         'begin_time',o.begin_time,
         'end_time',o.end_time
           ),
		 coalesce(o.driver_id,0),
		 coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 case o.status_id when 30 then o.first_offer_time else null end
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join data.dispatcher_favorite_orders dfo ON dfo.order_id=o.id and dfo.dispatcher_id=dispatcher_id_
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join sysdata."SYS_PAYTYPES" pt on pt.id=o.paytype_id
 left join sysdata."SYS_CARCLASSES" cc on cc.id=o.carclass_id
 /*
 left join sysdata."SYS_CARTYPES" ct on ct.id=o.driver_cartype_id
 left join sysdata."SYS_CARCLASSES" cc2 on cc2.id=ct.class_id
 */
left join data.clients cl on cl.id=o.client_id
 left join data.drivers d on d.id=o.driver_id
  where o.id=order_id_ into json_data,selected_driver,selected_driver_full_name,offer_time;

select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'order_id',c.order_id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'to_notes',c.notes,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'by_driver',c.by_driver,
									   'accepted', c.accepted,
									   'photos',c.photos,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = order_id_
		  ORDER BY c.position_in_order)) 
		  into json_checkpoints;

select array_to_json(ARRAY( SELECT json_build_object('dsd_id',dsd.id,
									   'driver_id',d.id,
									   'driver_family_name',d.family_name,
									   'driver_name',d.name,
									   'driver_second_name',d.second_name,
									   'offer_time',dsd.datetime,
									   'first_view',(select min(timeview::timestamp(0)) from data.order_views ov where ov.order_id=order_id_ and ov.driver_id=d.id),
                                       'reject',(select min(orj.reject_order::timestamp(0)) from data.orders_rejecting orj where orj.order_id=order_id_ and orj.driver_id=dsd.driver_id)																
									)
          FROM data.dispatcher_selected_drivers dsd
		  LEFT JOIN data.drivers d ON d.id=dsd.driver_id
          WHERE dsd.selected_id = sel_id
		  ORDER BY d.family_name,d.name,d.second_name)) 
		  into json_selected_drivers;

select array_to_json(ARRAY( SELECT json_build_object('id',ds.id,
									   'datetime',ds.datetime,
									   'latitude',ds.latitude,
									   'longitude',ds.longitude)
           FROM data.driver_stops ds
          WHERE ds.order_id = order_id_
		  ORDER BY ds.datetime)) 
		  into json_stops;

select array_to_json(ARRAY( SELECT json_build_object('id',r.id,
									   'rating_id',r.rating_id,
									   'rating_name',srp.name,
									   'rating_value',r.rating_value::numeric(6,2))
           FROM data.order_ratings r
		   left join sysdata."SYS_ROUTERATING_PARAMS" srp on srp.id=r.rating_id
          WHERE r.order_id = order_id_ and r.rating_value is not null
		  ORDER BY r.rating_id)) 
		  into json_ratings;

END

$$;


ALTER FUNCTION api.dispatcher_get_order(dispatcher_id_ integer, pass_ text, order_id_ bigint, OUT selected_driver integer, OUT selected_driver_full_name text, OUT json_data text, OUT json_checkpoints text, OUT json_selected_drivers text, OUT offer_time timestamp without time zone, OUT json_stops text, OUT json_ratings text) OWNER TO postgres;

--
-- TOC entry 651 (class 1255 OID 16612)
-- Name: dispatcher_get_order_locations(bigint, integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_order_locations(order_id_ bigint, dispatcher_id_ integer, pass_ text, driver_id_ integer, full_report_ boolean) RETURNS TABLE(datetime timestamp without time zone, latitude numeric, longitude numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if full_report_ then
 RETURN QUERY  
 select l.datetime,l.latitude,l.longitude 
  from data.order_locations l
  where l.order_id=order_id_ and l.driver_id=driver_id_
  order by l.datetime;
else
 RETURN QUERY  
 select l.datetime,l.latitude,l.longitude
  from (select l.datetime,l.latitude,l.longitude, lag(l.latitude) over (order by l.datetime) as prev_latitude,lag(l.longitude) over (order by l.datetime) as prev_longitude
      from data.order_locations l
	  where l.order_id=order_id_ and l.driver_id=driver_id_
     ) l
 where l.prev_latitude is distinct from l.latitude and l.prev_longitude is distinct from l.longitude
 order by l.datetime;
end if; 

END

$$;


ALTER FUNCTION api.dispatcher_get_order_locations(order_id_ bigint, dispatcher_id_ integer, pass_ text, driver_id_ integer, full_report_ boolean) OWNER TO postgres;

--
-- TOC entry 652 (class 1255 OID 16613)
-- Name: dispatcher_get_point(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_point(dispatcher_id_ integer, pass_ text, point_id_ integer, OUT json_data text, OUT json_coordinates text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр точки.
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

select json_build_object(
		 'id',cp.id,
	     'name',cp.name,
		 'address',cp.address,
		 'google_original',cp.google_original,
		 'latitude',gor.latitude,
		 'longitude',gor.longitude,
		 'description',cp.description,
	     'code',cp.code,
		 'visible',coalesce(cp.visible,true),
	     'group_id',gp.id,
	     'group_name',gp.name)
 from data.client_points cp 
 left join data.google_originals gor on gor.id=cp.google_original							
 left join data.client_point_groups gp on gp.id=cp.group_id
 where cp.id=point_id_ and cp.dispatcher_id=dispatcher_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',cpc.id,
									   'latitude',cpc.latitude,
									   'longitude',cpc.longitude)
          FROM data.client_point_coordinates cpc
		  left join data.client_points cp on cpc.point_id=cp.id
          WHERE cpc.point_id = point_id_ and cp.dispatcher_id=dispatcher_id_
		  ORDER BY cpc.id)) 
		  into json_coordinates;

END

$$;


ALTER FUNCTION api.dispatcher_get_point(dispatcher_id_ integer, pass_ text, point_id_ integer, OUT json_data text, OUT json_coordinates text) OWNER TO postgres;

--
-- TOC entry 653 (class 1255 OID 16614)
-- Name: dispatcher_get_pointgroup(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer) RETURNS TABLE(name text, description text, code character varying, can_delete boolean, json_points jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр данных по группе мест.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

RETURN QUERY  
	SELECT pg.name,
	pg.description,
	pg.code,
	not exists(select 1 from data.client_points cp where cp.group_id=pg.id),
	(select array_to_json(ARRAY( SELECT json_build_object('name',cp.name,
									   'address',cp.address,
									   'lat',gor.latitude,
									   'lng',gor.longitude)
           FROM data.client_points cp
		   LEFT JOIN data.google_originals gor on gor.id=cp.google_original
		   WHERE cp.group_id=pg.id and cp.visible)))::jsonb

   FROM data.client_point_groups pg
  WHERE pg.id = pointgroup_id_ and 
        pg.dispatcher_id=dispatcher_id_;
  
END

$$;


ALTER FUNCTION api.dispatcher_get_pointgroup(dispatcher_id_ integer, pass_ text, pointgroup_id_ integer) OWNER TO postgres;

--
-- TOC entry 654 (class 1255 OID 16615)
-- Name: dispatcher_get_route(integer, text, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_route(dispatcher_id_ integer, pass_ text, route_id_ integer, country_code_ character varying, OUT name text, OUT base_sum numeric, OUT active boolean, OUT docs_next_day boolean, OUT description text, OUT difficulty_id integer, OUT restrictions jsonb, OUT client_id integer, OUT client_name character varying, OUT load_data jsonb, OUT load_time time without time zone, OUT calculation jsonb) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр маршрута.
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

select dr.name,coalesce(dr.base_sum,0),dr.active,coalesce(dr.docs_next_day,false),dr.description,dr.difficulty_id,dr.restrictions,dr.client_id,cl.name,dr.load_data,dr.load_time,
          (select array_to_json(ARRAY( SELECT json_build_object('id',drc.id,
									   'date',drc.calc_date,
									   'type_id',drc.calc_type_id,
									   'type_name',rc.name,						
									   'data',drc.calc_data)
           FROM data.dispatcher_route_calculations drc
		   left join sysdata."SYS_ROUTECALC_TYPES" srt on srt.id = drc.calc_type_id
		   left join sysdata."SYS_RESOURCES" rc on rc.resource_id=srt.resource_id and rc.country_code=country_code_
           WHERE drc.route_id = route_id_
 		   ORDER BY drc.calc_date desc)))
from data.dispatcher_routes dr
left join data.clients cl on cl.id=dr.client_id
where dr.id = route_id_ and dr.dispatcher_id=dispatcher_id_
into name,
    base_sum,	
	active,
	docs_next_day,
	description,
	difficulty_id,
	restrictions,
	client_id,
	client_name,
	load_data,
	load_time,
	calculation;

END

$$;


ALTER FUNCTION api.dispatcher_get_route(dispatcher_id_ integer, pass_ text, route_id_ integer, country_code_ character varying, OUT name text, OUT base_sum numeric, OUT active boolean, OUT docs_next_day boolean, OUT description text, OUT difficulty_id integer, OUT restrictions jsonb, OUT client_id integer, OUT client_name character varying, OUT load_data jsonb, OUT load_time time without time zone, OUT calculation jsonb) OWNER TO postgres;

--
-- TOC entry 655 (class 1255 OID 16616)
-- Name: dispatcher_get_tariff(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_get_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer, OUT json_data text, OUT json_costs text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр тарифа.
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

with otc as (
	 select distinct(tc.tariff_id) tariff_id from data.order_costs oc 
	 left join data.tariff_costs tc on tc.id=oc.tariff_cost_id
	 where tc.tariff_id is not null	 
 )
select json_build_object(
		 'id',t.id,
	     'name',t.name,
		 'description',t.description,
		 'begin_date',t.begin_date,
		 'end_date',t.end_date,
		 'is_closed',case when t.end_date is null then false else (t.end_date<CURRENT_DATE) end,
		 'can_delete',not exists(select 1 from data.driver_cars dc where dc.tariff_id=t.id) and not exists(select 1 from otc where otc.tariff_id=t.id)
	    )
from data.tariffs t
where t.id=tariff_id_ and t.dispatcher_id=dispatcher_id_
into json_data;
	
select array_to_json(ARRAY( SELECT json_build_object('id',tc.id,
									   'tariff_id',tc.tariff_id,
									   'name',tc.name,
									   'percent',tc.percent,
									   'can_delete',not exists(select 1 from data.order_costs oc where oc.tariff_cost_id=tc.id)
										)
           FROM data.tariff_costs tc
          WHERE tc.tariff_id = tariff_id_
		  ORDER BY tc.percent desc)) 
		  into json_costs;

END

$$;


ALTER FUNCTION api.dispatcher_get_tariff(dispatcher_id_ integer, pass_ text, tariff_id_ integer, OUT json_data text, OUT json_costs text) OWNER TO postgres;

--
-- TOC entry 657 (class 1255 OID 16617)
-- Name: dispatcher_hire_driver(integer, text, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_hire_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, new_pass_ character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Взятие на работу водителя (без диспетчера).
Возвращает либо id, либо -1.
*/
DECLARE driver_id integer default -1;
DECLARE dispatcher_id integer default -1;
DECLARE login character varying default '';

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

select d.login,d.dispatcher_id from data.drivers d 
 where d.id=driver_id_ into login,dispatcher_id;

if login<>'' and dispatcher_id is null then
  update data.drivers set dispatcher_id=dispatcher_id_,
                          pass = new_pass_
	 where id=driver_id_
	 returning id into driver_id;	   	 
end if;

return coalesce(driver_id,-1);

end

$$;


ALTER FUNCTION api.dispatcher_hire_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, new_pass_ character varying) OWNER TO postgres;

--
-- TOC entry 658 (class 1255 OID 16618)
-- Name: dispatcher_mark_money_request_as_read(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_mark_money_request_as_read(dispatcher_id_ integer, pass_ text, request_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Пометка запроса денег как прочитанного.
Возвращает либо true, либо false.
*/
begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

update data.money_requests set unread=false
 where id=request_id_;

return true;

end

$$;


ALTER FUNCTION api.dispatcher_mark_money_request_as_read(dispatcher_id_ integer, pass_ text, request_id_ bigint) OWNER TO postgres;

--
-- TOC entry 659 (class 1255 OID 16619)
-- Name: dispatcher_oborots(integer, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_oborots(dispatcher_id_ integer, pass_ text, date1_ date, date2_ date) RETURNS TABLE(id integer, fio text, saldo_in numeric, oborot_period numeric, cost_period numeric, paid_period numeric, bonus_period numeric, penalty_period numeric, saldo_out numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр оборотов по водителям
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
with oborot_work as
(	
	SELECT o.driver_id work_driver,o.from_time::date work_date,sum(summa) work_sum FROM data.orders o 
	 where o.dispatcher_id=dispatcher_id_ and o.status_id>=120 group by 1,2 order by 1,2
),
oborot_before as
(
	select o.work_driver, sum(o.work_sum) work_sum from oborot_work o where o.work_date<date1_ group by 1
),
oborot_period as
(
	select o.work_driver, sum(o.work_sum) work_sum from oborot_work o where o.work_date>=date1_ and o.work_date<=date2_ group by 1
),
cost_dates as
(
 select costs.* from (
	SELECT o.driver_id cost_driver,o.from_time::date cost_date, sum(oc.summa) cost_sum FROM data.order_costs oc 
	left join data.orders o on oc.order_id=o.id 
	where o.dispatcher_id=dispatcher_id_
    group by 1,2
	 UNION ALL	
	SELECT o.driver_id cost_driver,o.from_time::date cost_date, sum(oac.summa) cost_sum FROM data.order_agg_costs oac 
	left join data.orders o on oac.order_id=o.id 
	where o.dispatcher_id=dispatcher_id_
	group by 1,2
  ) as costs order by 1,2	 
),
cost_before as
(
	select cd.cost_driver, sum(cd.cost_sum) cost_sum from cost_dates cd where cd.cost_date<date1_ group by 1
),
cost_period as
(
	select cd.cost_driver, sum(cd.cost_sum) cost_sum from cost_dates cd where cd.cost_date>=date1_ and cd.cost_date<=date2_ group by 1
),
paid as
(
	SELECT f.driver_id paid_driver, f.operdate::date paid_date,sum(f.summa) paid_sum FROM data.feedback f 
	 where f.dispatcher_id=dispatcher_id_ and not f.paid is null and not coalesce(f.is_deleted,false)
     group by 1,2 order by 1,2	
),
paid_before as
(
	select p.paid_driver, sum(p.paid_sum) paid_sum from paid p where p.paid_date<date1_ group by 1
),
paid_period as
(
	select p.paid_driver, sum(p.paid_sum) paid_sum from paid p where p.paid_date>=date1_ and p.paid_date<=date2_ group by 1
),
add_dates as
(
	SELECT a.driver_id add_driver, a.operdate::date add_date,sum(a.summa) add_sum, case when a.summa<0 then -1 else 1 end as add_koeff FROM data.addsums a 
	 where a.dispatcher_id=dispatcher_id_ and not coalesce(a.is_deleted,false)
     group by 1,2,4 order by 1,2	
),
bonus_before as
(
	select a.add_driver, sum(a.add_sum) add_sum from add_dates a where a.add_koeff>0 and a.add_date<date1_ group by 1
),
bonus_period as
(
	select a.add_driver, sum(a.add_sum) add_sum from add_dates a where a.add_koeff>0 and a.add_date>=date1_ and a.add_date<=date2_ group by 1
),
penalty_before as
(
	select a.add_driver, sum(a.add_sum) add_sum from add_dates a where a.add_koeff<0 and a.add_date<date1_ group by 1
),
penalty_period as
(
	select a.add_driver, sum(a.add_sum) add_sum from add_dates a where a.add_koeff<0 and a.add_date>=date1_ and a.add_date<=date2_ group by 1
),
all_drivers as
 (
	 select d.id driver_id, d.family_name||' '||d.name||' '||d.second_name as fio, 
	 coalesce((select work_sum from oborot_before where work_driver=d.id),0) as o_b,
	 coalesce((select work_sum from oborot_period where work_driver=d.id),0) as o_p,
	 coalesce((select cost_sum from cost_before where cost_driver=d.id),0) as c_b,
	 coalesce((select cost_sum from cost_period where cost_driver=d.id),0) as c_p,
	 coalesce((select paid_sum from paid_before where paid_driver=d.id),0) as pd_b,
	 coalesce((select paid_sum from paid_period where paid_driver=d.id),0) as pd_p,
	 coalesce((select add_sum from bonus_before where add_driver=d.id),0) as b_b,
	 coalesce((select add_sum from bonus_period where add_driver=d.id),0) as b_p,
	 coalesce((select add_sum from penalty_before where add_driver=d.id),0) as p_b,
	 coalesce((select add_sum from penalty_period where add_driver=d.id),0) as p_p
	 from data.drivers d where d.dispatcher_id=dispatcher_id_
 )
 select ad.driver_id,ad.fio,
 o_b - pd_b - c_b + b_b - p_b as saldo_in,
 o_p oborot_period,
 c_p cost_period,
 pd_p paid_period,
 b_p bonus_period,
 p_p penalty_period,
 o_b + o_p - pd_b - pd_p - c_b - c_p + b_b + b_p - p_b - p_p as saldo_out
 from all_drivers ad;
END

$$;


ALTER FUNCTION api.dispatcher_oborots(dispatcher_id_ integer, pass_ text, date1_ date, date2_ date) OWNER TO postgres;

--
-- TOC entry 660 (class 1255 OID 16620)
-- Name: dispatcher_report_1(integer, text, timestamp without time zone, timestamp without time zone, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_report_1(dispatcher_id_ integer, pass_ text, load_time_from_ timestamp without time zone, load_time_to_ timestamp without time zone, driver_list_ text, client_list_ text) RETURNS TABLE(id bigint, load_time timestamp without time zone, order_title character varying, driver_id integer, driver_name text, client_id integer, client_name character varying, order_sum numeric, status_id integer, order_status character varying, begin_time timestamp without time zone, end_time timestamp without time zone, distance real)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр отчета №1.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
 /*
  With begin_times as 
    (
        select l.order_id, max(l.datetime::timestamp(0)) as dt from data.order_log l
		                         left join data.orders o on l.order_id=o.id
							     where l.status_old<>l.status_new and
						               l.status_new = 110 and
		                               o.from_time::date>=coalesce(load_time_from_::date,o.from_time::date) and
		                               o.from_time::date<=coalesce(load_time_to_::date,o.from_time::date) and
		                               case when driver_list_='' then true else (select o.driver_id::text in (select unnest(string_to_array(driver_list_,',')))) end and
		                               case when client_list_='' then true else (select o.client_id::text in (select unnest(string_to_array(client_list_,',')))) end
		                         group by 1
    )
   ,end_times as 
    (
        select l.order_id, max(l.datetime::timestamp(0)) as dt from data.order_log l
		                         left join data.orders o on l.order_id=o.id
							     where l.status_old<>l.status_new and
						               l.status_new = 120 and
		                               o.from_time::date>=coalesce(load_time_from_::date,o.from_time::date) and
		                               o.from_time::date<=coalesce(load_time_to_::date,o.from_time::date) and
		                               case when driver_list_='' then true else (select o.driver_id::text in (select unnest(string_to_array(driver_list_,',')))) end and
		                               case when client_list_='' then true else (select o.client_id::text in (select unnest(string_to_array(client_list_,',')))) end
		                         group by 1
    ) 
	SELECT o.id,
	o.from_time,
	o.order_title,
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
	o.client_id,
	cl.name,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,
	bt.dt as begin_time,
	et.dt end_time,
	 
	round((select api.dispatcher_get_driver_distance(dispatcher_id_,pass_,o.driver_id,bt.dt,et.dt,o.from_addr_latitude,o.from_addr_longitude)))::real
	
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN begin_times bt ON bt.order_id=o.id
   LEFT JOIN end_times et ON et.order_id=o.id
  WHERE sysdata.order4dispatcher(o.id, dispatcher_id_) and 
  o.from_time::date>=coalesce(load_time_from_::date,o.from_time::date) and
  o.from_time::date<=coalesce(load_time_to_::date,o.from_time::date) and
  o.driver_id is not null and 
  case when driver_list_='' then true else (select o.driver_id::text in (select unnest(string_to_array(driver_list_,',')))) end and
  case when client_list_='' then true else (select o.client_id::text in (select unnest(string_to_array(client_list_,',')))) end and
  o.status_id>60;
*/  
	SELECT o.id,
	o.from_time,
	o.order_title,
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
	o.client_id,
	cl.name,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,
	o.begin_time,
	o.end_time,
	 
	round((select api.dispatcher_get_driver_distance(dispatcher_id_,pass_,o.driver_id,o.begin_time,o.end_time,o.from_addr_latitude,o.from_addr_longitude)))::real
	
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
  WHERE sysdata.order4dispatcher(o.id, dispatcher_id_) and 
  o.from_time::date>=coalesce(load_time_from_::date,o.from_time::date) and
  o.from_time::date<=coalesce(load_time_to_::date,o.from_time::date) and
  o.driver_id is not null and 
  case when driver_list_='' then true else (select o.driver_id::text in (select unnest(string_to_array(driver_list_,',')))) end and
  case when client_list_='' then true else (select o.client_id::text in (select unnest(string_to_array(client_list_,',')))) end and
  o.status_id>60;

END

$$;


ALTER FUNCTION api.dispatcher_report_1(dispatcher_id_ integer, pass_ text, load_time_from_ timestamp without time zone, load_time_to_ timestamp without time zone, driver_list_ text, client_list_ text) OWNER TO postgres;

--
-- TOC entry 661 (class 1255 OID 16621)
-- Name: dispatcher_restore_addsum(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_restore_addsum(addsum_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Восстановление удаленного штрафа/бонуса.
*/
DECLARE addsum_id BIGINT;
DECLARE is_del BOOLEAN;
DECLARE res INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

  SELECT a.id, a.is_deleted FROM data.addsums a where a.id=addsum_id_ and a.dispatcher_id=dispatcher_id_ and coalesce(a.is_deleted,false)
  FOR UPDATE
  into addsum_id,is_del;

  IF addsum_id is null THEN
	 res=-2;
  ELSIF not coalesce(is_del,false) THEN
     res=0;
  ELSE
   BEGIN
    UPDATE data.addsums set is_deleted=false, 
	                       del_time=null 
					   where id=addsum_id;
    insert into data.finances_log(id,addsum_id,dispatcher_id,datetime,action_string)
         values (nextval('data.finances_log_id_seq'),addsum_id,dispatcher_id_,CURRENT_TIMESTAMP,'Restore') 
         on conflict do nothing;					   
					   
    res=1;
   END;	
  END IF;  

RETURN res;
END

$$;


ALTER FUNCTION api.dispatcher_restore_addsum(addsum_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 662 (class 1255 OID 16622)
-- Name: dispatcher_restore_feedback(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_restore_feedback(feedback_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Восстановление удаленного платежа.
*/
DECLARE feedback_id BIGINT;
DECLARE is_del BOOLEAN;
DECLARE res INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

  SELECT f.id, f.is_deleted FROM data.feedback f where f.id=feedback_id_ and f.dispatcher_id=dispatcher_id_ and coalesce(f.is_deleted,false)
  FOR UPDATE
  into feedback_id,is_del;

  IF feedback_id is null THEN
	 res=-2;
  ELSIF not coalesce(is_del,false) THEN
     res=0;
  ELSE
   BEGIN
    UPDATE data.feedback set is_deleted=false, 
	                       del_time=null 
					   where id=feedback_id;
    insert into data.finances_log(id,payment_id,dispatcher_id,datetime,action_string)
         values (nextval('data.finances_log_id_seq'),feedback_id,dispatcher_id_,CURRENT_TIMESTAMP,'Restore') 
         on conflict do nothing;					   
					   
    res=1;
   END;	
  END IF;  

RETURN res;
END

$$;


ALTER FUNCTION api.dispatcher_restore_feedback(feedback_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 664 (class 1255 OID 16623)
-- Name: dispatcher_restore_ga(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_restore_ga(dispatcher_id_ integer, pass_ text, edit_id_ bigint, OUT success integer, OUT latitude numeric, OUT longitude numeric) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Восстановление оригинальных координат (удаление правок).
Возвращает либо true, либо false.
*/

DECLARE address_id bigint default 0;
begin

success = 0;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if exists(select 1 from data.google_modifiers where id=edit_id_ and dispatcher_id=dispatcher_id_) then
 begin
  select gor.latitude,gor.longitude from data.google_originals gor 
   where id=(select original_id from data.google_modifiers gm where id=edit_id_ and dispatcher_id=dispatcher_id_)
   into latitude,longitude;
  
   delete from data.google_modifiers where id=edit_id_ and dispatcher_id=dispatcher_id_;
   success = 1;
   return;
 end;
end if; 

EXCEPTION
WHEN OTHERS THEN 
  RETURN;

end

$$;


ALTER FUNCTION api.dispatcher_restore_ga(dispatcher_id_ integer, pass_ text, edit_id_ bigint, OUT success integer, OUT latitude numeric, OUT longitude numeric) OWNER TO postgres;

--
-- TOC entry 665 (class 1255 OID 16624)
-- Name: dispatcher_revoke_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_revoke_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ 
/*
Вызывается диспетчером.
Сброс назначенного заказа и запись об этом в историю сброшенных диспетчером заказов.
*/
DECLARE order_id BIGINT;
DECLARE order_driver_id INT;
DECLARE curr_status_id INT DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT o.driver_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ and o.dispatcher_id=dispatcher_id_ FOR UPDATE
  into order_driver_id,curr_status_id;

  IF coalesce(curr_status_id,0)<>50 THEN /*Только назначенный*/
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set dispatcher_id=client_dispatcher_id, /*изначальный от клиента*/
	                        driver_id=null,
	                        status_id=30,
							driver_car_attribs=null
						where id=order_id_;
/*						
	 insert into data.orders_revoking (id,order_id,dispatcher_id,driver_id,revoke_order) 
	                          values(nextval('data.orders_revoking_id_seq'),order_id_,dispatcher_id_,order_driver_id,CURRENT_TIMESTAMP);
  */   
	 insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,order_driver_id,CURRENT_TIMESTAMP,50,30,'Revoke') 
     on conflict do nothing;

							  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.dispatcher_revoke_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 666 (class 1255 OID 16625)
-- Name: dispatcher_select_driver(integer, text, bigint, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_select_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, driver_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Предложение водителю на выделенный ордер.
*/

DECLARE sel_id BIGINT DEFAULT NULL;
DECLARE dispatcher_id INTEGER DEFAULT NULL;
DECLARE curr_status_id INTEGER DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select dso.id, dso.dispatcher_id from data.dispatcher_selected_orders dso
 where dso.order_id=order_id_ and dso.is_active into sel_id,dispatcher_id;
 
if coalesce(dispatcher_id,0)<>dispatcher_id_ then
 return false;
end if;

  SELECT coalesce(o.status_id,0) FROM data.orders o 
  where sysdata.order4dispatcher(order_id_, dispatcher_id_)
  FOR UPDATE
  into curr_status_id;

  IF coalesce(curr_status_id,0)<>30 THEN /*30 - подтвержденная заявка*/
	 return false;
  ELSE
 	 insert into data.dispatcher_selected_drivers(id,selected_id,driver_id,datetime) 
     values(nextval('data.dispatcher_selected_drivers_id_seq'),sel_id,driver_id_,CURRENT_TIMESTAMP)
	 on conflict do nothing;
	 
	 update	data.orders set first_offer_time = (select min(dsd.datetime) FROM data.dispatcher_selected_drivers dsd WHERE dsd.selected_id = sel_id)
	 where id=order_id_;
	 
  END IF;  

  insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,action_string)
  values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,driver_id_,CURRENT_TIMESTAMP,30,'Select driver') 
  on conflict do nothing;


 return true;

END

$$;


ALTER FUNCTION api.dispatcher_select_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 667 (class 1255 OID 16626)
-- Name: dispatcher_select_driver(integer, text, bigint, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_select_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, drivers_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Пакетное предложение водителям на выделенный ордер. Остальные предложения удаляются.
*/

DECLARE sel_id BIGINT DEFAULT NULL;
DECLARE dispatcher_id INTEGER DEFAULT NULL;
DECLARE curr_status_id INTEGER DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

select dso.id, dso.dispatcher_id from data.dispatcher_selected_orders dso
 where dso.order_id=order_id_ and dso.is_active into sel_id,dispatcher_id;
 
if coalesce(dispatcher_id,0)<>dispatcher_id_ then
 return false;
end if;

  SELECT coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ and sysdata.order4dispatcher(order_id_, dispatcher_id_)
  FOR UPDATE
  into curr_status_id;

  IF coalesce(curr_status_id,0)<>30 THEN /*30 - подтвержденная заявка*/
	 return false;
  ELSE
	 delete from data.dispatcher_selected_drivers where selected_id = sel_id and driver_id not in (select unnest(drivers_::int[]));
	 insert into data.dispatcher_selected_drivers(id,selected_id,datetime,driver_id) 
	 SELECT nextval('data.dispatcher_selected_drivers_id_seq'),sel_id,CURRENT_TIMESTAMP,unnest(drivers_::int[])
	 on conflict do nothing;
																							   
	 update	data.orders set first_offer_time = (select min(dsd.datetime) FROM data.dispatcher_selected_drivers dsd WHERE dsd.selected_id = sel_id)
	 where id=order_id_;
														   
  END IF;  

 insert into data.order_log(id,order_id,dispatcher_id,driver_id,datetime,status_new,action_string)
 select nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,unnest(drivers_::int[]),CURRENT_TIMESTAMP,30,'Select driver'
 on conflict do nothing;

 return true;

END

$$;


ALTER FUNCTION api.dispatcher_select_driver(dispatcher_id_ integer, pass_ text, order_id_ bigint, drivers_ text) OWNER TO postgres;

--
-- TOC entry 668 (class 1255 OID 16627)
-- Name: dispatcher_select_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_select_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Выделение ордера для дальнейшего предложения водителям.
*/

DECLARE selected_id BIGINT DEFAULT NULL;
DECLARE curr_status_id INTEGER DEFAULT NULL;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ and sysdata.order4dispatcher(order_id_, dispatcher_id_) FOR UPDATE
  into curr_status_id;
  
  IF coalesce(curr_status_id,0)<>30 THEN /*30 - подтвержденная заявка*/
	 return false;
  ELSE
   BEGIN
    select id from data.dispatcher_selected_orders dso 
    where dso.order_id=order_id_ and dso.dispatcher_id=dispatcher_id_
	into selected_id;
    
	  if coalesce(selected_id,0)>0 then
	    update data.dispatcher_selected_orders set sel_time=CURRENT_TIMESTAMP,
		                                           is_active=true 
		where id=selected_id;
	  else
         insert into data.dispatcher_selected_orders(id,order_id,dispatcher_id,sel_time,is_active) 
         values(nextval('data.dispatcher_selected_orders_id_seq'),order_id_,dispatcher_id_,CURRENT_TIMESTAMP,true)
	     on conflict do nothing;
	   end if;  
	END; 
  END IF;  

  insert into data.order_log(id,order_id,dispatcher_id,datetime,status_new,action_string)
  values (nextval('data.order_log_id_seq'),order_id_,dispatcher_id_,CURRENT_TIMESTAMP,30,'Select order') 
  on conflict do nothing;

 return true;

END

$$;


ALTER FUNCTION api.dispatcher_select_order(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 656 (class 1255 OID 16628)
-- Name: dispatcher_view_activity(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_activity(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS TABLE(id bigint, datetime timestamp without time zone, balls integer, description text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр истории активности
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT da.id,
	da.datetime,
	da.balls,
	sat.typename
   FROM data.driver_activities da
   left join data.drivers d on da.driver_id=d.id
   left join sysdata."SYS_ACTIVITYTYPES" sat on da.type_id=sat.id
   WHERE da.driver_id = driver_id_ and d.dispatcher_id = dispatcher_id_;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_activity(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 670 (class 1255 OID 16629)
-- Name: dispatcher_view_addsums(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_addsums(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, operdate date, dispatcher_id integer, driver_id integer, driver_name character varying, summa numeric, commentary text, is_deleted boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается диспетчером.
Просмотр штрафов/бонусов по водителям.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT a.id,	
	a.operdate::date,
    a.dispatcher_id,
    a.driver_id,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
	a.summa,
	a.commentary,
	a.is_deleted
   FROM data.addsums a 
   left join data.drivers d on d.id=a.driver_id
   where a.dispatcher_id = dispatcher_id_
  order by a.operdate;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_addsums(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 671 (class 1255 OID 16630)
-- Name: dispatcher_view_autocreate_logs(integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_autocreate_logs(dispatcher_id_ integer, pass_ text, code_ character varying) RETURNS TABLE(id bigint, datetime timestamp without time zone, type_name text, for_date date, orders_created integer, errors boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр логов автосоздания заказов
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT ac.id,
	ac.datetime,
	rc1.name,
	((ac.action_result->0)->>'date')::date,
    jsonb_array_length(((ac.action_result->0)->>'success')::jsonb),
	jsonb_array_length(ac.action_result)>1
   FROM data.autocreate_logs ac
   left join sysdata."SYS_AUTOCREATETYPES" sa on sa.id=type_id
   left join sysdata."SYS_RESOURCES" rc1 on rc1.resource_id=sa.resource_id and rc1.country_code=code_
   WHERE ac.dispatcher_id = dispatcher_id_;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_autocreate_logs(dispatcher_id_ integer, pass_ text, code_ character varying) OWNER TO postgres;

--
-- TOC entry 672 (class 1255 OID 16631)
-- Name: dispatcher_view_calendar(integer, text, integer, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_calendar(dispatcher_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying, OUT drivers_plan json, OUT routes_plan json, OUT has_records boolean) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр календаря на месяц.
*/

DECLARE first_date date;
DECLARE year_month character varying;
BEGIN

drivers_plan = '[]'::json;
routes_plan = '[]'::json;
has_records = false;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

year_month = (year_||'-'||TO_CHAR(month_,'fm00'))::character varying;
first_date = (year_month||'-01')::date;

with dates as
(
	select gs::date,extract(DAY from gs::date) gs_day from generate_series(first_date, (date_trunc('month', first_date) + interval '1 month' - interval '1 day')::date, interval '1 day') as gs
),
cals as
(
	select cal.id,cal.driver_id,cal.cdate,cal.route_id,cal.daytype_id from data.calendar cal where cal.dispatcher_id=dispatcher_id_ and to_char(cal.cdate, 'YYYY-MM')=year_month
),
drv as
(
	select d.id,d.family_name,d.name,d.second_name,d.calendar_index from data.drivers d
	where d.dispatcher_id=dispatcher_id_
),
rts as
(
	select dr.id,dr.name,dr.active from data.dispatcher_routes dr 
	where dr.dispatcher_id=dispatcher_id_
),								  								  
dp as
(
 select array_to_json(ARRAY( 
	select json_build_object('id',d.id,
	   						 'name',d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.',
       						 'calendar_index',d.calendar_index,	
							 'calendar_data',(select array_to_json(ARRAY( SELECT json_build_object('date',dates.gs,
									'day', dates.gs_day,
									'route_id',cals.route_id,
									'route_name',coalesce(r.name,''),
									'daytype_id',cals.daytype_id,
									'daytype_name',rc.name)
           FROM dates
		   left join cals on cals.driver_id=d.id and cals.cdate=dates.gs
		   left join rts r on r.id=cals.route_id
		   left join sysdata."SYS_DAYTYPES" dt on dt.id=cals.daytype_id
		   left join sysdata."SYS_RESOURCES" rc on rc.resource_id=dt.resource_id and rc.country_code=code_
						   )
					  ))
		)
	from drv d 
	order by d.calendar_index,d.family_name)) as dp_drivers
),
rp as
(
 select array_to_json(ARRAY( 
	select json_build_object('id',r.id,
	   						 'name',r.name,
							 'calendar_data',(select array_to_json(ARRAY( SELECT json_build_object('date',dates.gs,
									'day', dates.gs_day,
									'driver_id',cals.driver_id,
									'driver_name',coalesce(d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.',''),
									'cals_id',cals.id
									)
           FROM dates
		   left join cals on cals.route_id=r.id and cals.cdate=dates.gs
		   left join drv d on d.id=cals.driver_id
						   )
					  ))
		)
	from rts r
	order by r.name)) as rp_routes
)
select dp.dp_drivers,rp.rp_routes from dp,rp into drivers_plan,routes_plan;

has_records = exists(select 1 from data.calendar where dispatcher_id=dispatcher_id_);

END

$$;


ALTER FUNCTION api.dispatcher_view_calendar(dispatcher_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying, OUT drivers_plan json, OUT routes_plan json, OUT has_records boolean) OWNER TO postgres;

--
-- TOC entry 673 (class 1255 OID 16632)
-- Name: dispatcher_view_calendar_final(integer, text, integer, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_calendar_final(dispatcher_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying, OUT drivers_plan json, OUT routes_plan json) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр календаря на месяц.
*/

DECLARE first_date date;
DECLARE year_month character varying;
BEGIN

drivers_plan = '[]'::json;
routes_plan = '[]'::json;

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

year_month = (year_||'-'||TO_CHAR(month_,'fm00'))::character varying;
first_date = (year_month||'-01')::date;

with dates as
(
	select gs::date,extract(DAY from gs::date) gs_day from generate_series(first_date, (date_trunc('month', first_date) + interval '1 month' - interval '1 day')::date, interval '1 day') as gs
),
cals as
(
	select cal.id,cal.driver_id,cal.cdate,cal.route_id,cal.daytype_id from data.calendar_final cal where cal.dispatcher_id=dispatcher_id_ and to_char(cal.cdate, 'YYYY-MM')=year_month
),
drv as
(
	select d.id,d.family_name,d.name,d.second_name,d.calendar_index from data.drivers d
	where d.dispatcher_id=dispatcher_id_
),
rts as
(
	select dr.id,dr.name,dr.active from data.dispatcher_routes dr 
	where dr.dispatcher_id=dispatcher_id_
),								  								  
dp as
(
 select array_to_json(ARRAY( 
	select json_build_object('id',d.id,
	   						 'name',d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.',
       						 'calendar_index',d.calendar_index,	
							 'calendar_data',(select array_to_json(ARRAY( SELECT json_build_object('date',dates.gs,
									'day', dates.gs_day,
									'route_id',cals.route_id,
									'route_name',coalesce(r.name,''),
									'daytype_id',cals.daytype_id,
									'daytype_name',rc.name)
           FROM dates
		   left join cals on cals.driver_id=d.id and cals.cdate=dates.gs
		   left join rts r on r.id=cals.route_id
		   left join sysdata."SYS_DAYTYPES" dt on dt.id=cals.daytype_id
		   left join sysdata."SYS_RESOURCES" rc on rc.resource_id=dt.resource_id and rc.country_code=code_
						   )
					  ))
		)
	from drv d 
	order by d.calendar_index,d.family_name)) as dp_drivers
),
rp as
(
 select array_to_json(ARRAY( 
	select json_build_object('id',r.id,
	   						 'name',r.name,
							 'calendar_data',(select array_to_json(ARRAY( SELECT json_build_object('date',dates.gs,
									'day', dates.gs_day,
									'driver_id',cals.driver_id,
									'driver_name',coalesce(d.family_name||' '||upper(substring(d.name from 1 for 1))||'.'||upper(substring(d.second_name from 1 for 1))||'.',''),
									'cals_id',cals.id
									)
           FROM dates
		   left join cals on cals.route_id=r.id and cals.cdate=dates.gs
		   left join drv d on d.id=cals.driver_id
						   )
					  ))
		)
	from rts r
	order by r.name)) as rp_routes
)
select dp.dp_drivers,rp.rp_routes from dp,rp into drivers_plan,routes_plan;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_calendar_final(dispatcher_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying, OUT drivers_plan json, OUT routes_plan json) OWNER TO postgres;

--
-- TOC entry 674 (class 1255 OID 16633)
-- Name: dispatcher_view_clients(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_clients(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10 ROWS 100
    AS $$

BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 with dtc as
 ( 
	select dispatcher_id,client_id from data.dispatcher_to_client
 )
 select cl.id,
        cl.name
 from data.clients cl
 where cl.default_dispatcher_id=dispatcher_id_ 
 or exists(select 1 from dtc where dtc.dispatcher_id=dispatcher_id_ and dtc.client_id=cl.id)
 or (cl.default_dispatcher_id is null and not exists(select 1 from dtc where dtc.client_id=cl.id));
 
END

$$;


ALTER FUNCTION api.dispatcher_view_clients(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 675 (class 1255 OID 16634)
-- Name: dispatcher_view_contracts(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_contracts(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name text, description text, can_delete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$

BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 select ct.id,
        ct.name,
		ct.description,
		not exists(select 1 from data.drivers d where d.contract_id=ct.id)
 from data.contracts ct
 where ct.dispatcher_id=dispatcher_id_ ;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_contracts(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 676 (class 1255 OID 16635)
-- Name: dispatcher_view_cost_types(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_cost_types(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, can_delete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$

BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 select ct.id,
        ct.name,
		not exists(select 1 from data.order_costs oc where oc.cost_id=ct.id)
 from data.cost_types ct
 where ct.dispatcher_id=dispatcher_id_ ;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_cost_types(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 678 (class 1255 OID 16636)
-- Name: dispatcher_view_dashboard(integer, text, date, date, json); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_dashboard(dispatcher_id_ integer, pass_ text, date1_ date, date2_ date, json_id_ json) RETURNS TABLE(id bigint, from_time timestamp without time zone, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, carclass_id integer, carclass_name character varying, order_title character varying, client_id integer, client_name character varying, checkpoints json, hash text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр dashboard.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if json_id_ is null then
 RETURN QUERY  
 with alldata as
   (
	SELECT o.id,
	o.from_time,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.order_title,
	o.client_id,
	cl.name,
	array_to_json(ARRAY( SELECT json_build_object('id',ch.id,
									'to_addr_name',ch.to_addr_name,
									'visited_status',ch.visited_status,
									'visited_time',ch.visited_time,
									'by_driver',ch.by_driver,
									'photos', ch.photos,
									'accepted', ch.accepted,
									'position_in_order',ch.position_in_order
								    )
           FROM data.checkpoints ch
          WHERE ch.order_id = o.id
		  order by ch.position_in_order))  checkpoints
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
  WHERE o.dispatcher_id=dispatcher_id_ and not coalesce(o.is_deleted, false) and coalesce(o.visible, true)
   and o.from_time::date>=coalesce(date1_,o.from_time::date) and o.from_time::date<=coalesce(date2_,o.from_time::date)
 )
 select a.*,
 extract(epoch from a.from_time)::text||COALESCE(a.status_id, 0)::text||COALESCE(a.driver_id,0)::text||COALESCE(a.carclass_id,0)::text||md5(a.order_title::text)::text||a.client_id::text||md5(a.checkpoints::text)::text
 from alldata a;
else
 RETURN QUERY  
 with alldata as
   (
	SELECT o.id,
	o.from_time,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.order_title,
	o.client_id,
	cl.name,
	array_to_json(ARRAY( SELECT json_build_object('id',ch.id,
									'to_addr_name',ch.to_addr_name,
									'visited_status',ch.visited_status,
									'visited_time',ch.visited_time,
									'by_driver',ch.by_driver,
									'photos', ch.photos,
									'accepted', ch.accepted,
									'position_in_order',ch.position_in_order
								    )
           FROM data.checkpoints ch
          WHERE ch.order_id = o.id
		  order by ch.position_in_order))  checkpoints
   FROM data.orders o
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
  WHERE o.dispatcher_id=dispatcher_id_ and not coalesce(o.is_deleted, false) and coalesce(o.visible, true)
   and o.id::text in (select json_array_elements_text(json_id_))
 )
 select a.*,
 extract(epoch from a.from_time)::text||COALESCE(a.status_id, 0)::text||COALESCE(a.driver_id,0)::text||COALESCE(a.carclass_id,0)::text||md5(a.order_title::text)::text||a.client_id::text||md5(a.checkpoints::text)::text
 from alldata a;
end if;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_dashboard(dispatcher_id_ integer, pass_ text, date1_ date, date2_ date, json_id_ json) OWNER TO postgres;

--
-- TOC entry 679 (class 1255 OID 16637)
-- Name: dispatcher_view_dogovors(integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_dogovors(dispatcher_id_ integer, pass_ text, code_ character varying) RETURNS TABLE(id integer, name character varying, type_id integer, type_name text, archive boolean, archive_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр всех договоров.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT dd.id,
	dd.name,
	dd.type_id,
	rc1.name,
	dd.archive,
	rc2.name
   FROM data.dispatcher_dogovors dd
   LEFT JOIN sysdata."SYS_DOGOVOR_TYPES" dt on dt.id=dd.type_id
   left join sysdata."SYS_RESOURCES" rc1 on rc1.resource_id=dt.resource_id and rc1.country_code=code_
   left join sysdata."SYS_RESOURCES" rc2 on rc2.resource_id=(case when coalesce(dd.archive,false) then 1802 else 1801 end) and rc2.country_code=code_
  WHERE (dd.dispatcher_id = dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_dogovors(dispatcher_id_ integer, pass_ text, code_ character varying) OWNER TO postgres;

--
-- TOC entry 680 (class 1255 OID 16638)
-- Name: dispatcher_view_driver_cars(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_driver_cars(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS TABLE(id integer, carclass_id integer, carclass_name character varying, cartype_id integer, cartype_name character varying, carmodel character varying, weight_limit numeric, volume_limit numeric, trays_limit integer, pallets_limit integer, carnumber character varying, carcolor character varying, car_is_active boolean, car_is_default boolean, driver_id integer, driver_full_name text, driver_is_no_active boolean, has_tariff boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр машин по водителю/-ям.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if driver_id_=0 then
  driver_id_ = null;
end if;  

 RETURN QUERY  
 with cars_with_tariffs as
 (
	 select dct.driver_car_id, dct.tariff_id
	 from data.driver_car_tariffs dct
	 left join data.tariffs t on t.id=dct.tariff_id
	 where coalesce(t.begin_date,CURRENT_DATE)<=CURRENT_DATE and coalesce(t.end_date,CURRENT_DATE)>=CURRENT_DATE
 )
	SELECT dc.id,
	dc.carclass_id,
	cc.name,
	dc.cartype_id,
	ct.name,
	dc.carmodel,
	dc.weight_limit, 
	dc.volume_limit,
	dc.trays_limit, 
	dc.pallets_limit,
	dc.carnumber,
	dc.carcolor,
	dc.is_active,
	coalesce(dc.is_default,false),
	d.id,
	d.family_name||' '||d.name,
    not d.is_active,
	case when exists(select 1 from cars_with_tariffs where driver_car_id=dc.id) then true else false end
   FROM data.driver_cars dc
   left join data.drivers d on dc.driver_id=d.id
   left join sysdata."SYS_CARCLASSES" cc on dc.carclass_id=cc.id
   left join sysdata."SYS_CARTYPES" ct on dc.cartype_id=ct.id
   WHERE (dc.driver_id=coalesce(driver_id_,dc.driver_id) and d.dispatcher_id = dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_driver_cars(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 681 (class 1255 OID 16639)
-- Name: dispatcher_view_driver_costs(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_driver_costs(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр затрат по водителю.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

if (select d.dispatcher_id from data.drivers d where d.id = driver_id_)<>dispatcher_id_ then
 return null;
end if; 

RETURN (
with costs as
(
 select 'personal' cost_type, ct.id, ct.name, dc.percent
 FROM data.driver_costs dc 
 LEFT JOIN data.cost_types ct on dc.cost_id=ct.id 
 WHERE dc.driver_id = driver_id_	
	union all
 select 'tariff' cost_type, tc.id, t.name||' -> '||tc.name as name, tc.percent
 FROM data.tariff_costs tc 
 LEFT JOIN data.tariffs t on tc.tariff_id=t.id 
 LEFT JOIN data.driver_car_tariffs dct on dct.tariff_id=t.id 	
 LEFT JOIN data.driver_cars dc on dc.id=dct.driver_car_id 	
 WHERE dc.driver_id = driver_id_	
)
 select array_to_json(ARRAY( SELECT json_build_object('cost_type',c.cost_type,
                                       'cost_id',c.id,
									   'cost_name',c.name,
									   'driver_percent',c.percent)
                                   FROM costs c)
						  )::text
);  
END

$$;


ALTER FUNCTION api.dispatcher_view_driver_costs(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 682 (class 1255 OID 16640)
-- Name: dispatcher_view_drivers(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_drivers(dispatcher_id_ integer, pass_ text, level_id_ integer DEFAULT NULL::integer) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, full_name character varying, login character varying, level_id integer, level_name character varying, is_active boolean, date_of_birth date, full_age double precision, contact text, contact2 text, dispatcher_id integer, balance text, driver_cars text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается диспетчером.
Просмотр водителей (с балансами). 
Если указан уровень, то только этого уровня.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if coalesce(level_id_,0)>0 then
  RETURN QUERY  
	SELECT d.id,
    d.name,
	d.second_name,
	d.family_name,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
    d.login,
	d.level_id,
    dl.name AS level_name,
    d.is_active,
    d.date_of_birth,
    date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
    d.contact,
	d.contact2,
    d.dispatcher_id,
	(select api.get_balance(dispatcher_id_,d.id,pass_))::text,
	(select array_to_json(ARRAY( 
								 with cars_with_tariffs as
								 (
									 select dct.driver_car_id, dct.tariff_id
									 from data.driver_car_tariffs dct
									 left join data.tariffs t on t.id=dct.tariff_id
									 where coalesce(t.begin_date,CURRENT_DATE)<=CURRENT_DATE and coalesce(t.end_date,CURRENT_DATE)>=CURRENT_DATE
								 )

										SELECT json_build_object('id',dc.id,
									   'carclass_id',dc.carclass_id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active,
									   'has_tariff',case when exists(select 1 from cars_with_tariffs where driver_car_id=dc.id) then true else false end
																)
                                   FROM data.driver_cars dc
								   WHERE dc.driver_id = d.id)
						  )
	)::text
   FROM data.drivers d
   LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
   WHERE d.dispatcher_id=dispatcher_id_ and d.level_id=level_id_;
else 
        RETURN QUERY  
	      SELECT d.id,
          d.name,
	      d.second_name,
	      d.family_name,
	      cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
          d.login,
	      d.level_id,
          dl.name AS level_name,
          d.is_active,
          d.date_of_birth,
          date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
          d.contact,
	      d.contact2,
          d.dispatcher_id,
	      (select api.get_balance(dispatcher_id_,d.id,pass_))::text,
	      (select array_to_json(ARRAY( SELECT json_build_object('id',dc.id,
									   'carclass_id',dc.carclass_id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active,
									   'has_tariff',case when (dc.tariff_id is not null and coalesce(t.end_date,CURRENT_DATE)>=CURRENT_DATE) then true else false end)
                                       FROM data.driver_cars dc
									   left join data.tariffs t on dc.tariff_id=t.id
                                       WHERE dc.driver_id = d.id)
						         )::text
		  )
         FROM data.drivers d
         LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
         WHERE d.dispatcher_id=dispatcher_id_;
end if; 
END

$$;


ALTER FUNCTION api.dispatcher_view_drivers(dispatcher_id_ integer, pass_ text, level_id_ integer) OWNER TO postgres;

--
-- TOC entry 683 (class 1255 OID 16641)
-- Name: dispatcher_view_drivers_by_id(integer, text, json); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_drivers_by_id(dispatcher_id_ integer, pass_ text, json_id_ json) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, full_name character varying, login character varying, is_active boolean, date_of_birth date, full_age double precision, contact text, contact2 text, dispatcher_id integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается диспетчером.
Просмотр водителей (по списку id). 
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

        RETURN QUERY  
	      SELECT d.id,
          d.name,
	      d.second_name,
	      d.family_name,
	      cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
          d.login,
          d.is_active,
          d.date_of_birth,
          date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
          d.contact,
	      d.contact2,
          d.dispatcher_id
         FROM data.drivers d
         WHERE d.dispatcher_id=dispatcher_id_ and d.id::text in (select json_array_elements_text(json_id_));

END

$$;


ALTER FUNCTION api.dispatcher_view_drivers_by_id(dispatcher_id_ integer, pass_ text, json_id_ json) OWNER TO postgres;

--
-- TOC entry 684 (class 1255 OID 16642)
-- Name: dispatcher_view_empty_drivers(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_empty_drivers(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, full_name character varying, login character varying, level_id integer, level_name character varying, is_active boolean, date_of_birth date, full_age double precision, contact text, contact2 text, driver_cars text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается диспетчером.
Просмотр водителей без диспетчеров. 
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT d.id,
    d.name,
	d.second_name,
	d.family_name,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
    d.login,
	d.level_id,
    dl.name AS level_name,
    d.is_active,
    d.date_of_birth,
    date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
    d.contact,
	d.contact2,
	(select array_to_json(ARRAY( SELECT json_build_object('id',dc.id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active)
                                   FROM data.driver_cars dc
                                   WHERE dc.driver_id = d.id)
						  )
	)::text
   FROM data.drivers d
   LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
   WHERE d.dispatcher_id is null;
END

$$;


ALTER FUNCTION api.dispatcher_view_empty_drivers(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 685 (class 1255 OID 16643)
-- Name: dispatcher_view_feedbacks(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_feedbacks(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, opernumber integer, operdate date, dispatcher_id integer, driver_id integer, driver_name character varying, summa numeric, paid_date date, is_paid boolean, commentary text, is_deleted boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$
/*
Вызывается диспетчером.
Просмотр платежей по водителям.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT f.id,	
	f.opernumber,
	f.operdate::date,
    f.dispatcher_id,
    f.driver_id,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
	f.summa,
    f.paid,
	(CASE WHEN f.paid is null THEN false ELSE true END) is_paid, 
	f.commentary,
	f.is_deleted
   FROM data.feedback f 
   left join data.drivers d on d.id=f.driver_id
   where f.dispatcher_id = dispatcher_id_
  order by f.operdate;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_feedbacks(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 686 (class 1255 OID 16644)
-- Name: dispatcher_view_google_addresses(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_google_addresses(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, address text, google_address_id bigint, google_address text, latitude numeric, longitude numeric, edit_id bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр своих google-адресов.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT ga.id,
	ga.address,
	gor.id as google_address_id,
	gor.address as google_address,
	coalesce(gm.latitude,gor.latitude),	
	coalesce(gm.longitude,gor.longitude),	
	coalesce(gm.id,0)
   FROM data.google_addresses ga
   left join data.google_originals gor on ga.google_original=gor.id
   left join data.google_modifiers gm on gm.original_id=gor.id and gm.dispatcher_id=ga.dispatcher_id
  WHERE (ga.dispatcher_id = dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_google_addresses(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 687 (class 1255 OID 16645)
-- Name: dispatcher_view_money_requests(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_money_requests(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, driver_id integer, driver_full_name text, summa numeric, datetime timestamp without time zone, unread boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр запросов денег
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT mr.id,
	d.id,
	d.family_name||' '||d.name,
	mr.summa,
	mr.datetime,
	mr.unread
   FROM data.money_requests mr
   left join data.drivers d on mr.driver_id=d.id
   WHERE mr.dispatcher_id = dispatcher_id_;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_money_requests(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 688 (class 1255 OID 16646)
-- Name: dispatcher_view_options(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_options(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, section_id integer, section_name character varying, param_name text, param_view_name text, param_value_text text, param_value_integer integer, param_value_real real, param_value_json jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$

BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 select o.id,
        o.section_id,
		os.name,
        o.param_name,
        o.param_view_name,
        o.param_value_text,
		o.param_value_integer,
		o.param_value_real,
		o.param_value_json
 from data."options" o
 left join data.options_sections os on os.id=o.section_id
 where o.dispatcher_id=dispatcher_id_ ;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_options(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 689 (class 1255 OID 16647)
-- Name: dispatcher_view_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_orders(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, order_time timestamp without time zone, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, carclass_id integer, carclass_name character varying, paytype_id integer, paytype_name character varying, distance real, duration integer, notes character varying, order_title character varying, client_id integer, client_name character varying, selected bigint, favorite boolean, dfo_id bigint, first_offer_time timestamp without time zone, offers json, rating numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр всех заказов по диспетчеру.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.from_time,
    o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
/*    ARRAY( SELECT c.to_addr_name
           FROM data.checkpoints c
          WHERE c.order_id = o.id) AS to_addr_names,*/
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.paytype_id,
	coalesce(pt.name,'Любой'),
	o.distance,
	o.duration,
	o.notes,
	o.order_title,
	o.client_id,
	cl.name,
/*	array_to_json(ARRAY( SELECT json_build_object('id',orj.id,
									'driver_id',orj.driver_id,
									'driver_name',orjd.name||' '||orjd.second_name||' '||orjd.family_name,
								    'date',orj.reject_order)
           FROM data.orders_rejecting orj
		   left join data.drivers orjd on orjd.id=orj.driver_id
          WHERE orj.order_id = o.id
		  order by orj.reject_order)),

     array_to_json(ARRAY( SELECT json_build_object('id',orc.id,
									'driver_id',orc.driver_id,
									'driver_name',orcd.name||' '||orcd.second_name||' '||orcd.family_name,
									'date',orc.cancel_order)
           FROM data.orders_canceling orc
		   left join data.drivers orcd on orcd.id=orc.driver_id
          WHERE orc.order_id = o.id
		  order by orc.cancel_order)),

      array_to_json(ARRAY( SELECT json_build_object('id',orv.id,
									'driver_id',orv.driver_id,
									'driver_name',orvd.name||' '||orvd.second_name||' '||orvd.family_name,
									'timeview',orv.timeview)
           FROM data.order_views orv
		   left join data.drivers orvd on orvd.id=orv.driver_id
          WHERE orv.order_id = o.id
		  order by orv.timeview)),*/
	
	dso.id,
	coalesce(dfo.favorite,false),
	coalesce(dfo.id,0),
	o.first_offer_time,
	array_to_json(ARRAY( SELECT json_build_object('dsd_id',dsd.id,
									'driver_id',dsd.driver_id,
									'driver_name',dsdd.family_name||' '||dsdd.name||' '||dsdd.second_name,
								    'driver_first_name',dsdd.name,
									'driver_second_name',dsdd.second_name,
									'driver_family_name',dsdd.family_name,
									'offer_time',dsd.datetime,
									'first_view',dsd.first_view_time, /*(select min(ov.timeview::timestamp(0)) from data.order_views ov where ov.order_id=o.id and ov.driver_id=dsd.driver_id)*/
									'reject',dsd.reject_time /*(select min(orj.reject_order::timestamp(0)) from data.orders_rejecting orj where orj.order_id=o.id and orj.driver_id=dsd.driver_id)*/
								    )
           FROM data.dispatcher_selected_drivers dsd
		   left join data.drivers dsdd on dsdd.id=dsd.driver_id
          WHERE dsd.selected_id = dso.id
		  order by dsdd.family_name,dsdd.name,dsdd.second_name)),
	o.rating
		  
   FROM data.orders o
   LEFT JOIN data.dispatcher_selected_orders dso ON dso.order_id=o.id and dso.dispatcher_id=dispatcher_id_ and dso.is_active
   LEFT JOIN data.dispatcher_favorite_orders dfo ON dfo.order_id=o.id and dfo.dispatcher_id=dispatcher_id_
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
   LEFT JOIN sysdata."SYS_PAYTYPES" pt ON pt.id=o.paytype_id
  WHERE sysdata.order4dispatcher(o.id, dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_orders(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 574 (class 1255 OID 16649)
-- Name: dispatcher_view_pointgroups(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_pointgroups(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name text, description text, code character varying, points bigint, can_delete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$

BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 select pg.id,
        pg.name,
        pg.description,
		pg.code,
		(select count(*) from data.client_points cp where cp.group_id=pg.id) as points,
		case when points<1 then true else false end
 from data.client_point_groups pg
 where pg.dispatcher_id=dispatcher_id_ ;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_pointgroups(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 691 (class 1255 OID 16650)
-- Name: dispatcher_view_points(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_points(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, address character varying, google_original bigint, latitude numeric, longitude numeric, description text, code character varying, visible boolean, group_id integer, group_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр всех мест.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT cp.id,
	cp.name,
	cp.address,	
	cp.google_original,
    gor.latitude,
    gor.longitude,
    cp.description,
    cp.code,
	coalesce(cp.visible,true),
	gp.id,
	gp.name
   FROM data.client_points cp
   LEFT JOIN data.google_originals gor on gor.id=cp.google_original
   LEFT JOIN data.client_point_groups gp on gp.id=cp.group_id
   WHERE (cp.dispatcher_id = dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_points(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 692 (class 1255 OID 16651)
-- Name: dispatcher_view_routes(integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_routes(dispatcher_id_ integer, pass_ text, code_ character varying) RETURNS TABLE(id integer, name text, client_id integer, client_name character varying, load_data jsonb, load_time time without time zone, base_sum numeric, docs_next_day boolean, active boolean, description text, difficulty_id integer, difficulty_name text, difficulty_value numeric, restrictions jsonb, calc_date date, calc_type_id integer, calc_type_name text, calc_data jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр всех маршрутов.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
 with calculations as
 (
	 select drc.id,drc.route_id,drc.calc_date,drc.calc_type_id,rc.name calc_type_name,drc.calc_data 
     from data.dispatcher_route_calculations drc
     left join sysdata."SYS_ROUTECALC_TYPES" srt on srt.id = drc.calc_type_id
     left join sysdata."SYS_RESOURCES" rc on rc.resource_id=srt.resource_id and rc.country_code=code_
     where drc.id = (select drc2.id from data.dispatcher_route_calculations drc2 where drc.route_id=drc2.route_id order by drc2.calc_date desc limit 1)
 ) 
	SELECT r.id,
	r.name,
	r.client_id,
	cl.name,
	r.load_data,
	r.load_time,
	coalesce(r.base_sum,0),
	coalesce(r.docs_next_day,false),
	coalesce(r.active,true),
    r.description,
	rt.id,
	rc1.name,
	rt.difficulty,
	r.restrictions,
	c.calc_date,
	c.calc_type_id,
	c.calc_type_name,
	c.calc_data
   FROM data.dispatcher_routes r
   left join data.clients cl on cl.id=r.client_id
   LEFT JOIN sysdata."SYS_ROUTETYPES" rt on rt.id=r.difficulty_id
   left join sysdata."SYS_RESOURCES" rc1 on rc1.resource_id=rt.resource_id and rc1.country_code=code_
   left join calculations c on c.route_id=r.id
  WHERE (r.dispatcher_id = dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.dispatcher_view_routes(dispatcher_id_ integer, pass_ text, code_ character varying) OWNER TO postgres;

--
-- TOC entry 693 (class 1255 OID 16652)
-- Name: dispatcher_view_selected_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_selected_orders(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, order_time timestamp without time zone, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, carclass_id integer, carclass_name character varying, paytype_id integer, paytype_name character varying, distance real, duration integer, notes character varying, order_title character varying, client_id integer, client_name character varying, favorite boolean, dso_id bigint, dfo_id bigint, first_offer_time timestamp without time zone, offers json, rating numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Просмотр выбранных заказов по диспетчеру.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.from_time,
    o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
/*    ARRAY( SELECT c.to_addr_name
           FROM data.checkpoints c
          WHERE c.order_id = o.id) AS to_addr_names,*/
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.paytype_id,
	coalesce(pt.name,'Любой'),
	o.distance,
	o.duration,
	o.notes,
	o.order_title,
	o.client_id,
	cl.name,
	coalesce(dfo.favorite,false),
	dso.id,
	coalesce(dfo.id,0),
	o.first_offer_time,
	array_to_json(ARRAY( SELECT json_build_object('dsd_id',dsd.id,
									'driver_id',dsd.driver_id,
									'driver_name',dsdd.family_name||' '||dsdd.name||' '||dsdd.second_name,
								    'driver_first_name',dsdd.name,
									'driver_second_name',dsdd.second_name,
									'driver_family_name',dsdd.family_name,
									'offer_time',dsd.datetime,
									'first_view',dsd.first_view_time, /*(select min(ov.timeview::timestamp(0)) from data.order_views ov where ov.order_id=o.id and ov.driver_id=dsd.driver_id)*/
									'reject',dsd.reject_time /*(select min(orj.reject_order::timestamp(0)) from data.orders_rejecting orj where orj.order_id=o.id and orj.driver_id=dsd.driver_id)*/
								    )
           FROM data.dispatcher_selected_drivers dsd
		   left join data.drivers dsdd on dsdd.id=dsd.driver_id
          WHERE dsd.selected_id = dso.id
		  order by dsdd.family_name,dsdd.name,dsdd.second_name)),
	o.rating		  
	/*array_to_json(ARRAY( SELECT json_build_object('id',orj.id,
									'driver_id',orj.driver_id,
									'driver_name',orjd.name||' '||orjd.second_name||' '||orjd.family_name,
								    'date',orj.reject_order)
           FROM data.orders_rejecting orj
		   left join data.drivers orjd on orjd.id=orj.driver_id
          WHERE orj.order_id = o.id
		  order by orj.reject_order)),

     array_to_json(ARRAY( SELECT json_build_object('id',orc.id,
									'driver_id',orc.driver_id,
									'driver_name',orcd.name||' '||orcd.second_name||' '||orcd.family_name,
									'date',orc.cancel_order)
           FROM data.orders_canceling orc
		   left join data.drivers orcd on orcd.id=orc.driver_id
          WHERE orc.order_id = o.id
		  order by orc.cancel_order)),

      array_to_json(ARRAY( SELECT json_build_object('id',orv.id,
									'driver_id',orv.driver_id,
									'driver_name',orvd.name||' '||orvd.second_name||' '||orvd.family_name,
									'timeview',orv.timeview)
           FROM data.order_views orv
		   left join data.drivers orvd on orvd.id=orv.driver_id
          WHERE orv.order_id = o.id
		  order by orv.timeview))*/
		  
   FROM data.dispatcher_selected_orders dso
   LEFT JOIN data.orders o ON dso.order_id=o.id
   LEFT JOIN data.dispatcher_favorite_orders dfo ON dfo.order_id=o.id and dfo.dispatcher_id=dispatcher_id_
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
   LEFT JOIN sysdata."SYS_PAYTYPES" pt ON pt.id=o.paytype_id
   /*LEFT JOIN sysdata."SYS_CARTYPES" ct ON ct.id=o.driver_cartype_id*/
  WHERE dso.dispatcher_id=dispatcher_id_ and dso.is_active;
  
END

$$;


ALTER FUNCTION api.dispatcher_view_selected_orders(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 694 (class 1255 OID 16654)
-- Name: dispatcher_view_tariffs(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.dispatcher_view_tariffs(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name text, description text, begin_date date, end_date date, closed boolean, can_delete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$
BEGIN

   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if;	

 RETURN QUERY
 with otc as (
	 select distinct(tc.tariff_id) tariff_id from data.order_costs oc 
	 left join data.tariff_costs tc on tc.id=oc.tariff_cost_id
	 where tc.tariff_id is not null	 
 )
  
 select t.id,
        t.name,
        t.description,
		t.begin_date,
		t.end_date,
		case when t.end_date is null then false else (t.end_date<CURRENT_DATE) end,
		not exists(select 1 from data.driver_car_tariffs dct where dct.tariff_id=t.id) and not exists(select 1 from otc where otc.tariff_id=t.id)
 from data.tariffs t
 where t.dispatcher_id=dispatcher_id_ ;
 
END

$$;


ALTER FUNCTION api.dispatcher_view_tariffs(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 695 (class 1255 OID 16655)
-- Name: driver_add_checkpoints(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_checkpoints(driver_id_ integer, pass_ text, data_ jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Добавление посещенного чекпойнта.
Возврат успех/неуспех.
*/
DECLARE data_count INTEGER;
DECLARE i INTEGER;

DECLARE tim timestamp without time zone;
DECLARE o_id BIGINT DEFAULT NULL;
DECLARE c_id BIGINT DEFAULT NULL;
DECLARE address CHARACTER VARYING DEFAULT NULL;
DECLARE lat numeric;
DECLARE lng numeric;
DECLARE photos jsonb;

DECLARE json_result jsonb;
DECLARE json_string character varying;

DECLARE curr_status_id INT;
DECLARE curr_time timestamp without time zone;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return '[]'::jsonb;
end if;

json_result = '[]'::jsonb;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
	tim = cast(data_->i->>'time' as timestamp);
	o_id = cast(data_->i->>'order_id' as bigint);
	c_id = cast(data_->i->>'checkpoint_id' as bigint);
	address = cast(data_->i->>'address' as character varying);
	lat = cast(data_->i->>'lat' as numeric);
	lng = cast(data_->i->>'lng' as numeric);
	if data_->i->>'photos' is not null then
	  photos = cast(data_->i->>'photos' as jsonb);
	else
	  photos = null;
	end if;

    SELECT coalesce(o.status_id,0) FROM data.orders o 
    where o.id=o_id and o.driver_id=driver_id_
    into curr_status_id;

    IF curr_status_id<>110 then
	 continue;
    END IF;
  
  	json_string = null;
    curr_time = CURRENT_TIMESTAMP;
    insert into data.checkpoints(id,order_id,to_addr_name,to_addr_latitude,to_addr_longitude,visited_status,visited_time,position_in_order,by_driver,photos)
                        values(nextval('data.checkpoints_id_seq'),o_id,address,lat,lng,true,curr_time::timestamp(0),(select count(*)+1 from data.checkpoints c2 where c2.order_id=o_id), true, photos)
						returning '{"order":'||o_id||',"old":'||c_id||',"new":'||id||'}' into json_string
						;
						
	-- надо обновить заказ (вдруг там стоял почасовой режим)
	update data.orders set hours = null where id = o_id;

      if json_string is not null then
  	    json_result = json_result || json_string::jsonb;
	  end if;  

     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),o_id,driver_id_,curr_time,curr_status_id,curr_status_id,'Add checkpoint') 
     on conflict do nothing;
	
	end; /* for */ 
  END LOOP;	
							  
 return json_result;

END

$$;


ALTER FUNCTION api.driver_add_checkpoints(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 696 (class 1255 OID 16656)
-- Name: driver_add_correction(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_correction(driver_id_ integer, pass_ text, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Добавляет коррекцию по координатам точек и адресов.
*/
DECLARE _order_id bigint;
DECLARE _point_id integer;
DECLARE lat numeric;
DECLARE lng numeric;
DECLARE real_lat numeric;
DECLARE real_lng numeric;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER; --
DECLARE i INTEGER; --

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    real_lat = cast(data_->i->>'real_latitude' as numeric);
	real_lng = cast(data_->i->>'real_longitude' as numeric);
    if real_lat is null or real_lng is null then 
     continue;
    end if;
	 
    _order_id = cast(data_->i->>'order_id' as bigint);
    _point_id = cast(data_->i->>'point_id' as integer);
    lat = cast(data_->i->>'latitude' as numeric);
	lng = cast(data_->i->>'longitude' as numeric);	
	tim = cast(data_->i->>'time' as timestamp);
	
	if coalesce(_point_id,0) > 0 then
	    insert into data.driver_corrections (id,datetime,driver_id,order_id,point_id,latitude,longitude,real_latitude,real_longitude) 
		                                   values (nextval('data.drivers_corrections_id_seq'),tim,driver_id_,_order_id,_point_id,lat,lng,real_lat,real_lng)
										   on conflict do nothing;	
	end if;

	end; /* for */ 
  END LOOP;

return true;
end

$$;


ALTER FUNCTION api.driver_add_correction(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 698 (class 1255 OID 16657)
-- Name: driver_add_location(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Добавляет в историю локаций текущие данные.
*/
/*
DECLARE routing_order_id BIGINT DEFAULT 0;
DECLARE radius REAL DEFAULT 0;
*/
DECLARE lat numeric;
DECLARE long numeric;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER;
DECLARE i INTEGER;
DECLARE current_latitude numeric DEFAULT NULL;
DECLARE current_longitude numeric DEFAULT NULL;
DECLARE i_time timestamp without time zone default NULL;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

/*
select param_value_real from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
 into radius;
*/

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    lat = cast(data_->i->>'latitude' as numeric);
	long = cast(data_->i->>'longitude' as numeric);
    if lat is null or long is null then 
     continue;
    end if;
	
	tim = cast(data_->i->>'time' as timestamp);
	
	if i_time is NULL or i_time<tim then
	 begin
	  i_time = tim;
	  current_latitude = lat;
	  current_longitude = long;
	 end;
	end if;

    insert into data.driver_history_locations (driver_id,curr_latitude,curr_longitude,loc_time) 
	                                   values (driver_id_,lat,long,tim)
									   on conflict do nothing;	

	end; /* for */ 
  END LOOP;

  if i_time is not null and current_latitude is not null and current_longitude is not null then  
    insert into data.driver_current_locations (driver_id,latitude,longitude,loc_time) values (driver_id_,current_latitude,current_longitude,i_time) 
    on conflict(driver_id) do update set latitude=current_latitude, longitude=current_longitude, loc_time=i_time 
    where excluded.driver_id=driver_id_;
  end if; 
  

return true;
end

$$;


ALTER FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 699 (class 1255 OID 16658)
-- Name: driver_add_location(integer, text, jsonb, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, data_ jsonb, device_id_ text, device_name_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Добавляет в историю локаций текущие данные.
*/
/*
DECLARE routing_order_id BIGINT DEFAULT 0;
DECLARE radius REAL DEFAULT 0;
*/
DECLARE lat numeric;
DECLARE long numeric;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER;
DECLARE i INTEGER;
DECLARE current_latitude numeric DEFAULT NULL;
DECLARE current_longitude numeric DEFAULT NULL;
DECLARE i_time timestamp without time zone default NULL;

DECLARE device_record integer DEFAULT 0;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

/*
select param_value_real from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
 into radius;
*/

device_record = aggregator_api.add_driver_device(driver_id_,device_id_,device_name_);
if device_record<1 then
  device_record = null;
end if;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    lat = cast(data_->i->>'latitude' as numeric);
	long = cast(data_->i->>'longitude' as numeric);
    if lat is null or long is null then 
     continue;
    end if;
	
	tim = cast(data_->i->>'time' as timestamp);
	
	if i_time is NULL or i_time<tim then
	 begin
	  i_time = tim;
	  current_latitude = lat;
	  current_longitude = long;
	 end;
	end if;

    insert into data.driver_history_locations (driver_id,curr_latitude,curr_longitude,loc_time,device_id) 
	                                   values (driver_id_,lat,long,tim,device_record)
									   on conflict do nothing;	

	end; /* for */ 
  END LOOP;

  if i_time is not null and current_latitude is not null and current_longitude is not null then  
    insert into data.driver_current_locations (driver_id,latitude,longitude,loc_time) values (driver_id_,current_latitude,current_longitude,i_time) 
    on conflict(driver_id) do update set latitude=current_latitude, longitude=current_longitude, loc_time=i_time 
    where excluded.driver_id=driver_id_;
  end if; 
  

return true;
end

$$;


ALTER FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, data_ jsonb, device_id_ text, device_name_ text) OWNER TO postgres;

--
-- TOC entry 700 (class 1255 OID 16659)
-- Name: driver_add_location(integer, text, numeric, numeric, timestamp without time zone); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, latitude_ numeric, longitude_ numeric, loc_time_ timestamp without time zone DEFAULT CURRENT_TIMESTAMP) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Добавляет в историю локаций текущие данные.
*/
DECLARE routing_order_id BIGINT DEFAULT 0;
DECLARE radius REAL DEFAULT 0;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

if latitude_ is null or longitude_ is null then 
 return false;
end if;

insert into data.driver_history_locations (driver_id,curr_latitude,curr_longitude,loc_time) values (driver_id_,latitude_,longitude_,loc_time_);
insert into data.driver_current_locations (driver_id,latitude,longitude,loc_time) values (driver_id_,latitude_,longitude_,loc_time_) 
on conflict(driver_id) do update set latitude=latitude_, longitude=longitude_, loc_time=loc_time_ 
where excluded.driver_id=driver_id_;

select param_value_real from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
 into radius;

if /*coalesce(routing_order_id,0)>0 and*/ coalesce(radius,0)>0 then 
 begin
  update data.checkpoints set visited_status = true,
                              visited_time = loc_time_
  where not coalesce(visited_status,false)
    and order_id in (select o.id from data.orders o where o.status_id=1 and o.driver_id=driver_id_)
    and to_addr_latitude is not null and to_addr_longitude is not null
    and sysdata.get_distance(latitude_,longitude_,to_addr_latitude,to_addr_longitude)<radius;
 end;
end if;

return true;
end

$$;


ALTER FUNCTION api.driver_add_location(driver_id_ integer, pass_ text, latitude_ numeric, longitude_ numeric, loc_time_ timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 701 (class 1255 OID 16660)
-- Name: driver_add_log(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_log(driver_id_ integer, pass_ text, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Добавляет данных в лог.
*/
DECLARE log_action text;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER;
DECLARE i INTEGER;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

/*
select param_value_real from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
 into radius;
*/

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    log_action = cast(data_->i->>'action' as text);
	tim = cast(data_->i->>'time' as timestamp);

    insert into data.log (id,datetime,driver_id,user_action) 
	values (nextval('data.log_id_seq'),tim,driver_id_,log_action)
									   on conflict do nothing;	

	end; /* for */ 
  END LOOP;


return true;
end

$$;


ALTER FUNCTION api.driver_add_log(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 702 (class 1255 OID 16661)
-- Name: driver_add_rating_point(integer, text, integer, bigint, numeric, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_rating_point(driver_id_ integer, pass_ text, point_id_ integer, order_id_ bigint, rating_ numeric, commentary_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Выставление рейтинга точке.
*/

DECLARE order_driver_id integer default null;
DECLARE order_status_id integer default null;

DECLARE good_comment text;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select o.driver_id, o.status_id from data.orders o where o.id=order_id_
into order_driver_id, order_status_id;

if order_driver_id<>driver_id_ or order_status_id<110 then 
 return false;
end if;

good_comment = REPLACE(commentary_,'&quot;','"');
good_comment = REPLACE(good_comment,'<br>','\n');

insert into data.point_rating (id, point_id, driver_id, order_id, rating, commentary) 
values (nextval('data.point_rating_id_seq'),point_id_,driver_id_,order_id_,rating_,good_comment) 
on conflict (point_id,driver_id,order_id) do update set rating=rating_, commentary=good_comment ;

return true;
end

$$;


ALTER FUNCTION api.driver_add_rating_point(driver_id_ integer, pass_ text, point_id_ integer, order_id_ bigint, rating_ numeric, commentary_ text) OWNER TO postgres;

--
-- TOC entry 703 (class 1255 OID 16662)
-- Name: driver_add_stop(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_stop(driver_id_ integer, pass_ text, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Добавляет координаты остановки для заказа.
*/
DECLARE _order_id bigint;
DECLARE lat numeric;
DECLARE lng numeric;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER; --
DECLARE i INTEGER; --

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    lat = cast(data_->i->>'latitude' as numeric);
	lng = cast(data_->i->>'longitude' as numeric);	
    if lat is null or lng is null then 
     continue;
    end if;
	 
    _order_id = cast(data_->i->>'order_id' as bigint);
	tim = cast(data_->i->>'time' as timestamp);
	
    insert into data.driver_stops (id,datetime,driver_id,order_id,latitude,longitude) 
	                                   values (nextval('data.driver_stops_id_seq'),tim,driver_id_,_order_id,lat,lng)
									   on conflict do nothing;	

	end; /* for */ 
  END LOOP;

return true;

end

$$;


ALTER FUNCTION api.driver_add_stop(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 704 (class 1255 OID 16663)
-- Name: driver_add_visits(integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_visits(driver_id_ integer, pass_ text, data_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
АКТУАЛЬНАЯ ВЕРСИЯ
Вызывается водителем.
Добавляет в историю посещений чекпойнтов текущие данные.
*/
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER;
DECLARE i INTEGER;
DECLARE ch_id BIGINT DEFAULT NULL;
DECLARE json_photos jsonb;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
	tim = cast(data_->i->>'time' as timestamp);
	ch_id = cast(data_->i->>'checkpoint_id' as bigint);
	if data_->i->>'photos' is not null then
	  json_photos = cast(data_->i->>'photos' as jsonb);
	else
	  json_photos = null;
	end if;
	
    update data.checkpoints set visited_status = true,
                                visited_time = tim,
								photos = json_photos
       where id=ch_id;
		 

	end; /* for */ 
  END LOOP;

return true;
end

$$;


ALTER FUNCTION api.driver_add_visits(driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 705 (class 1255 OID 16664)
-- Name: driver_add_visits(bigint, integer, text, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_add_visits(order_id_ bigint, driver_id_ integer, pass_ text, data_ jsonb) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Добавляет в историю посещений чекпойнтов текущие данные.
*/
DECLARE radius REAL DEFAULT 0;

DECLARE lat numeric;
DECLARE long numeric;
DECLARE tim timestamp without time zone;
DECLARE data_count INTEGER;
DECLARE i INTEGER;
DECLARE ch_id BIGINT DEFAULT NULL;

begin
if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return -1;
end if;

select param_value_real/1000. from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
 into radius;

data_count = jsonb_array_length(data_);
  
  FOR i IN 0..(data_count-1) LOOP
   begin
    lat = cast(data_->i->>'latitude' as numeric);
	long = cast(data_->i->>'longitude' as numeric);
    if lat is null or long is null then 
     continue;
    end if;
	
	tim = cast(data_->i->>'time' as timestamp);
	
    update data.checkpoints set visited_status = true,
                                visited_time = tim
       where order_id = order_id_
	     and not coalesce(visited_status,false)
         and to_addr_latitude is not null and to_addr_longitude is not null
         and sysdata.get_distance(lat,long,to_addr_latitude,to_addr_longitude)<radius
		 and id=(
			           select ch.id from data.checkpoints ch where
			             order_id=order_id_
			             and not coalesce(ch.visited_status,false)
                         and ch.to_addr_latitude is not null and ch.to_addr_longitude is not null
                         and sysdata.get_distance(lat,long,ch.to_addr_latitude,ch.to_addr_longitude)<radius
			 			 order by position_in_order
			             limit 1
		               )
		 returning id into ch_id;
		 

	end; /* for */ 
  END LOOP;

return coalesce(ch_id,0);
end

$$;


ALTER FUNCTION api.driver_add_visits(order_id_ bigint, driver_id_ integer, pass_ text, data_ jsonb) OWNER TO postgres;

--
-- TOC entry 706 (class 1255 OID 16665)
-- Name: driver_available_cars(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_available_cars(driver_id_ integer, pass_ text, order_id_ bigint) RETURNS TABLE(id integer, cartype_id integer, cartype_name character varying, carclass_id integer, carclass_name character varying, carmodel character varying, carnumber character varying, carcolor character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Доступные автомобили для выполнения заказа order_id_.
*/
DECLARE order_class_id integer;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

order_class_id = null;
select o.carclass_id from data.orders o where o.id=order_id_ into order_class_id;

 
 RETURN QUERY  
	SELECT dc.id,	
	dc.cartype_id cartype_id,
	st.name cartype_name,
	dc.carclass_id carclass_id,
	sc.name carclass_name,
    dc.carmodel,
    dc.carnumber,
    dc.carcolor	
   FROM data.driver_cars dc
   LEFT JOIN sysdata."SYS_CARTYPES" st on dc.cartype_id=st.id
   LEFT JOIN sysdata."SYS_CARCLASSES" sc on dc.carclass_id=sc.id
  WHERE dc.is_active
    AND dc.driver_id=driver_id_
	AND coalesce(order_class_id,sc.id)=sc.id;
  
END

$$;


ALTER FUNCTION api.driver_available_cars(driver_id_ integer, pass_ text, order_id_ bigint) OWNER TO postgres;

--
-- TOC entry 707 (class 1255 OID 16666)
-- Name: driver_available_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_available_orders(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, carclass_id integer, paytype_id integer, notes character varying, order_title character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Новые, предложенные диспетчером
Проверяется, не отклонен ли этот заказ водителем раньше.
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 
 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
	o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	st.name_for_driver,
	o.carclass_id,
	o.paytype_id,
    o.notes,
	o.order_title
	from data.dispatcher_selected_drivers dsd
	left join data.dispatcher_selected_orders dso on dsd.selected_id=dso.id
	left join data.orders o on dso.order_id=o.id
	LEFT JOIN sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
	where dsd.driver_id = driver_id_ and dso.is_active and coalesce(o.status_id,0)=30
	AND NOT EXISTS(select 1 from data.orders_rejecting orj 
				   where orj.order_id=o.id and orj.driver_id=driver_id_)
	AND NOT EXISTS(select 1 from data.orders_canceling orc 
				   where orc.order_id=o.id and orc.driver_id=driver_id_);
  
END

$$;


ALTER FUNCTION api.driver_available_orders(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 708 (class 1255 OID 16667)
-- Name: driver_begin_execution(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_begin_execution(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Начало выполнения маршрута.
Возврат успех/неуспех.
*/

DECLARE order_id BIGINT;
DECLARE driver_id INT;
DECLARE curr_status_id INT;
DECLARE beg_time TIMESTAMP WITHOUT TIME ZONE;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,coalesce(o.status_id,0),coalesce(o.driver_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,curr_status_id,driver_id;

  IF order_id is null or curr_status_id<>60 or driver_id<>driver_id_ THEN
	 return false;
  ELSE
    BEGIN	
	 beg_time = CURRENT_TIMESTAMP;
     UPDATE data.orders set status_id=110, /*заказ выполняется*/
	                        begin_time=beg_time
	                    where id=order_id_;	
  
     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,beg_time,110,60,'Begin execution') 
     on conflict do nothing;
	 
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_begin_execution(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 711 (class 1255 OID 16668)
-- Name: driver_cancel_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_cancel_order(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Отмена выполняемого заказа. Статус (40/60)->30, водитель, параметры машины.
Диспетчер становится тем диспетчером, который был установлен клиентом.
История отмен записывается в data.orders_canceling .
*/

DECLARE order_id BIGINT;
DECLARE driver_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.driver_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,driver_id,curr_status_id;

  IF order_id is null or curr_status_id not in (40,60,110) or driver_id<>driver_id_ THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set driver_id=null,
	                        status_id=30, /* Новый заказ */
							dispatcher_id=client_dispatcher_id,
							driver_car_attribs=null
						where id=order_id_;
	 
	 insert into data.orders_canceling (id,order_id,driver_id,cancel_order) 
	                          values(nextval('data.orders_canceling_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP);

     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,30,curr_status_id,'Cancel') 
     on conflict do nothing;
							  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_cancel_order(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 712 (class 1255 OID 16669)
-- Name: driver_canceled_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_canceled_orders(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, carclass_id integer, paytype_id integer, notes character varying, order_title character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Отклоненные и отмененные заказы.
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 
 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
	o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.summa - (select sum(agg_cost+all_costs) from sysdata.calc_costs(o.id,driver_id_,0)),
    -40,
	'Отклонен'::character varying,
	o.carclass_id,
	o.paytype_id,
    o.notes,
	o.order_title
   FROM data.orders o
  WHERE EXISTS(select 1 from data.orders_rejecting orj where orj.order_id=o.id and orj.driver_id=driver_id_)
  
  UNION
  
  	SELECT o.id,	
	o.from_time,
	o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.summa - (select sum(agg_cost+all_costs) from sysdata.calc_costs(o.id,driver_id_,0)),
    -110,
	'Отменен'::character varying,
	o.carclass_id,
	o.paytype_id,
    o.notes,
	o.order_title
   FROM data.orders o
  WHERE EXISTS(select 1 from data.orders_canceling ocl where ocl.order_id=o.id and ocl.driver_id=driver_id_);
  
END

$$;


ALTER FUNCTION api.driver_canceled_orders(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 713 (class 1255 OID 16670)
-- Name: driver_check_notify(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_check_notify(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, summa numeric, status_id integer, status_name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Проверка заказов для нотификации.
Проверяется, не отклонен ли этот заказ водителем раньше.
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 
 RETURN QUERY    
	SELECT o.id,	
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	st.name_for_driver
	from data.dispatcher_selected_drivers dsd
	left join data.dispatcher_selected_orders dso on dsd.selected_id=dso.id
	left join data.orders o on dso.order_id=o.id
	LEFT JOIN sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
	where dsd.driver_id = driver_id_ and dso.is_active and coalesce(o.status_id,0)=30
	AND NOT EXISTS(select 1 from data.orders_rejecting orj 
				   where orj.order_id=o.id and orj.driver_id=driver_id_)
	AND NOT EXISTS(select 1 from data.orders_canceling orc 
				   where orc.order_id=o.id and orc.driver_id=driver_id_)
				   
	UNION
	
	SELECT o.id,	
    o.summa,
    o.status_id,
	st.name_for_driver
   FROM data.orders o
   LEFT JOIN sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
   WHERE o.driver_id = driver_id_ and (o.status_id=40 or o.status_id=50) /*принят или назначен*/
				   
	UNION
/*
--пуш о заказе пока не нужен
	SELECT o.id,	
    o.rating,
    -333,
	(select array_to_json(ARRAY( SELECT json_build_object('name',sp.name,
														  'value',ort.rating_value) 
								 from data.order_ratings ort 
								 left join sysdata."SYS_ROUTERATING_PARAMS" sp on sp.id=ort.rating_id
								 where ort.order_id=o.id
								)
						)
	 )::character varying
   FROM data.orders o
   WHERE o.driver_id = driver_id_ and o.status_id>=120 
   and o.end_time::date=CURRENT_DATE and o.rating is not null

	UNION
*/	
	
	SELECT cn.notify_id,	
    0,
    -444,
	cn.event_date::character varying
   FROM data.calendar_notifications cn
   WHERE cn.driver_id = driver_id_
   and cn.event_date>=CURRENT_DATE;

END

$$;


ALTER FUNCTION api.driver_check_notify(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 714 (class 1255 OID 16671)
-- Name: driver_confirm_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_confirm_order(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Подтверждение выхода на работу.
Возврат успех/неуспех.
*/

DECLARE order_id BIGINT;
DECLARE driver_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,coalesce(o.status_id,0),coalesce(o.driver_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,curr_status_id,driver_id;

  IF order_id is null or curr_status_id not in (40,50) or driver_id<>driver_id_ THEN
	 return false;
  ELSE
    BEGIN	
     UPDATE data.orders set status_id=60 /*подтвердил выход*/
	                    where id=order_id_;						  

     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,60,curr_status_id,'Confirm') 
     on conflict do nothing;
							
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_confirm_order(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 715 (class 1255 OID 16672)
-- Name: driver_create_cron_offer(integer, text, bigint, timestamp without time zone); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_create_cron_offer(driver_id_ integer, pass_ text, order_id_ bigint, offer_time_ timestamp without time zone) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Создание водителем задания для крона, если в этом еще есть нужда.
Возврат успех/неуспех.
*/
DECLARE curr_time TIMESTAMP;
DECLARE curr_driver INTEGER;
DECLARE curr_status_id INTEGER DEFAULT NULL;

DECLARE job_time TIMESTAMP;
DECLARE _minute_ INTEGER;
DECLARE _hour_ INTEGER;
DECLARE _day_ INTEGER;
DECLARE _month_ INTEGER;
DECLARE _timezone_ INTEGER;

DECLARE job_id BIGINT;

DECLARE job_nodename TEXT;
DECLARE job_schedule TEXT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

curr_time = now();
select o.driver_id,o.status_id from data.orders o where o.id=order_id_
into curr_driver,curr_status_id;

job_time = offer_time_ + interval '3 minutes';
if curr_time > job_time then -- нет смысла делать
 begin
    if curr_driver is null or curr_driver <> driver_id_ then
	  begin
	    if not exists(select 1 from data.orders_rejecting o where o.order_id=order_id_ and o.driver_id=driver_id_) then
		  begin
             insert into data.orders_rejecting (id,order_id,driver_id,reject_order) 
	                          values(nextval('data.orders_rejecting_id_seq'),order_id_,driver_id_,curr_time);
    
	         insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
             values (nextval('data.order_log_id_seq'),order_id_,driver_id_,curr_time,curr_status_id,curr_status_id,'Reject') 
             on conflict do nothing;	  
          end;	  
		end if;
	  end;
	end if;

    return true;
 end;
else
 begin
   --отнимем/добавим таймзону из-за pg_cron
   _timezone_ = (EXTRACT(TIMEZONE FROM now())/3600.0)::INTEGER;
   job_time = job_time - _timezone_ * interval '1 hour';
				 
   _minute_ = EXTRACT(MINUTE FROM job_time);
   _hour_ = EXTRACT(HOUR FROM job_time);
   _day_ = EXTRACT(DAY FROM job_time);
   _month_ = EXTRACT(MONTH FROM job_time);
  
   job_schedule = _minute_::text || ' ' || _hour_::text || ' ' || _day_::text || ' ' || _month_::text || ' *';
   job_nodename = (select param_value_string from sysdata."SYS_PARAMS" where param_name = 'CRON_NODENAME');
   job_id = cron.schedule(job_schedule, 'select count(*) from data.log');
   update cron.job set nodename = job_nodename,
                       command = 'select sysdata.cron_reject_order(' || order_id_::text || ',' || driver_id_::text || ',' || job_id || ')'
          where jobid = job_id;
 end;
end if;  

return true;

END

$$;


ALTER FUNCTION api.driver_create_cron_offer(driver_id_ integer, pass_ text, order_id_ bigint, offer_time_ timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 609 (class 1255 OID 16673)
-- Name: driver_del_driver_car(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_del_driver_car(driver_id_ integer, pass_ text, driver_car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE _driver_id integer default 0;

/*
 Вызывается водителем.
 Удаление автомобиля. Возвращает true/false; 
*/

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select coalesce(dc.driver_id,-1) from data.driver_cars dc
 where dc.id=driver_car_id_ into _driver_id;
  if _driver_id<>driver_id_ then
   return false;
  end if;
  

DELETE FROM data.driver_cars where id=driver_car_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION api.driver_del_driver_car(driver_id_ integer, pass_ text, driver_car_id_ integer) OWNER TO postgres;

--
-- TOC entry 717 (class 1255 OID 16674)
-- Name: driver_edit_driver(integer, text, character varying, character varying, character varying, character varying, character varying, boolean, date, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver(driver_id_ integer, pass_ text, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Редактирование себя.
Возвращает true/false.
*/

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  update data.drivers set name=driver_name_,
                   second_name=driver_second_name_,
				   family_name=driver_family_name_,
				   pass=coalesce(driver_pass_,pass),
				   is_active=driver_is_active_,
				   date_of_birth=driver_date_of_birth_,
				   contact=driver_contact_,
				   contact2=driver_contact2_
	 where id=driver_id_;	   
	 
return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver(driver_id_ integer, pass_ text, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text) OWNER TO postgres;

--
-- TOC entry 718 (class 1255 OID 16675)
-- Name: driver_edit_driver_bank(integer, text, text, text, text, text, text, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_bank(driver_id_ integer, pass_ text, driver_inn_ text, driver_kpp_ text, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Обновление информации о банке.
Возвращает true/false.
*/

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  update data.drivers set inn=driver_inn_,
				   kpp=driver_kpp_,
				   bank=driver_bank_,
				   bik=driver_bik_,
				   korrschet=driver_korrschet_,
				   rasschet=driver_rasschet_,
				   poluchatel=driver_poluchatel_
	 where id=driver_id_;	   
	 
return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver_bank(driver_id_ integer, pass_ text, driver_inn_ text, driver_kpp_ text, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text) OWNER TO postgres;

--
-- TOC entry 719 (class 1255 OID 16676)
-- Name: driver_edit_driver_bank_card(integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_bank_card(driver_id_ integer, pass_ text, driver_bank_card_ character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Обновление информации о банковской карте.
Возвращает true/false.
*/

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  update data.drivers set bank_card=driver_bank_card_
	 where id=driver_id_;	   
	 
return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver_bank_card(driver_id_ integer, pass_ text, driver_bank_card_ character varying) OWNER TO postgres;

--
-- TOC entry 720 (class 1255 OID 16677)
-- Name: driver_edit_driver_car(integer, text, integer, character varying, character varying, character varying, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_car(driver_id_ integer, pass_ text, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE car_id integer default 0;
DECLARE _driver_id integer default 0;

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_car_id_,0)>0 then /*редактирование*/
 begin
  select coalesce(dc.driver_id,-1) from data.driver_cars dc
  where dc.id=driver_car_id_ into _driver_id;
  
  if _driver_id<>driver_id_ then
   return -1;
  end if;
     
  update data.driver_cars set cartype_id=cartype_id_,
				   carmodel=carmodel_,
				   carnumber=carnumber_,
				   carcolor=carcolor_,
				   is_active=is_active_
	 where id=driver_car_id_
	 returning id into car_id;
 end;	 
else /*new car*/
  insert into data.driver_cars (id,driver_id,cartype_id,carmodel,carnumber,carcolor,is_active)
         values (nextval('data.driver_cars_id_seq'),driver_id_,cartype_id_,carmodel_,carnumber_,carcolor_,is_active_)
		 returning id into car_id;
end if; 

return car_id;

end

$$;


ALTER FUNCTION api.driver_edit_driver_car(driver_id_ integer, pass_ text, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 721 (class 1255 OID 16678)
-- Name: driver_edit_driver_car_docs(integer, text, integer, integer, text, text, date, date, date, boolean, jsonb); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_car_docs(driver_id_ integer, pass_ text, driver_car_id_ integer, doc_type_ integer, doc_serie_ text, doc_number_ text, doc_date_ date, start_date_ date, end_date_ date, add_doc_ boolean, files_ jsonb) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE _driver_id integer default 0;
DECLARE _doc_id integer default null;
DECLARE files_count integer default 0;
DECLARE add_files jsonb default null;
DECLARE i integer;

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select coalesce(dc.driver_id,-1) from data.driver_cars dc
where dc.id=driver_car_id_ into _driver_id;
if _driver_id<>driver_id_ then
 return false;
end if;

if not add_doc_ then
 begin
   select dcd.id from data.driver_car_docs dcd 
    where dcd.driver_car_id=driver_car_id_ and dcd.doc_type=doc_type_
    into _doc_id;
 
   delete from data.driver_car_files dcf 
   where not (files_ ? ('id'||dcf.id)::text ) and dcf.doc_id=_doc_id;
  end;
end if;  

if add_doc_ or coalesce(_doc_id,0)=0 then
 insert into data.driver_car_docs(id,doc_type,driver_car_id,doc_serie,doc_number,doc_date,start_date,end_date)
 values (nextval('data.driver_car_docs_id_seq'),doc_type_,driver_car_id_,doc_serie_,doc_number_,doc_date_,start_date_,end_date_)
 returning id into _doc_id;
end if;

if files_ is NULL or cast(files_ as text)='' or cast(files_ as text)='{}' or cast(files_ as text)='[]' then
 return true;
end if; 

add_files = (SELECT jsonb_object_agg(key, value)
  FROM jsonb_each(files_)
  WHERE
    key NOT LIKE 'id%'
    AND jsonb_typeof(value) != 'null');

	/*RAISE EXCEPTION 'res = %', add_files;*/
	
    insert into data.driver_car_files(id,doc_id,filename,filepath,filesize)
	 select nextval('data.driver_car_files_id_seq'),_doc_id,
	                cast(add_files->key->>'name' as text),
					cast(add_files->key->>'guid' as text),
					cast(add_files->key->>'size' as bigint)
	 FROM jsonb_each(add_files);
 return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver_car_docs(driver_id_ integer, pass_ text, driver_car_id_ integer, doc_type_ integer, doc_serie_ text, doc_number_ text, doc_date_ date, start_date_ date, end_date_ date, add_doc_ boolean, files_ jsonb) OWNER TO postgres;

--
-- TOC entry 722 (class 1255 OID 16679)
-- Name: driver_edit_driver_passport(integer, text, text, text, date, text, character varying, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_passport(driver_id_ integer, pass_ text, pass_serie text, pass_number text, pass_date date, pass_from text, reg_addresse_ character varying, fact_addresse_ character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE pass_id bigint default 0;
begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=1
into pass_id;

if coalesce(pass_id,0)>0 then
 update data.driver_docs set doc_serie=pass_serie,
				   doc_number=pass_number,
				   doc_date=pass_date,
				   doc_from=pass_from
	                where id=pass_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,doc_from)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,1,pass_serie,pass_number,pass_date,pass_from);
end if;						 

update data.drivers set reg_addresse=reg_addresse_,
                        fact_addresse=fact_addresse_
						where id=driver_id_;

return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver_passport(driver_id_ integer, pass_ text, pass_serie text, pass_number text, pass_date date, pass_from text, reg_addresse_ character varying, fact_addresse_ character varying) OWNER TO postgres;

--
-- TOC entry 723 (class 1255 OID 16680)
-- Name: driver_edit_driver_vu(integer, text, text, text, date, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_edit_driver_vu(driver_id_ integer, pass_ text, vu_serie text, vu_number text, vu_begin date, vu_end date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE vu_id bigint default 0;

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select coalesce(dd.id,0) from data.driver_docs dd where dd.driver_id=driver_id_ and dd.doc_type=10
into vu_id;

if coalesce(vu_id,0)>0 then
 update data.driver_docs set doc_serie=vu_serie,
                   doc_number=vu_number,
				   doc_date=vu_begin,
				   end_date=vu_end
	                where id=vu_id;
else				
 insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,10,vu_serie,vu_number,vu_begin,vu_end);
end if;						 

return true;

end

$$;


ALTER FUNCTION api.driver_edit_driver_vu(driver_id_ integer, pass_ text, vu_serie text, vu_number text, vu_begin date, vu_end date) OWNER TO postgres;

--
-- TOC entry 725 (class 1255 OID 16681)
-- Name: driver_finish_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_finish_order(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Завершение маршрута. 
*/ 
DECLARE order_id BIGINT;
DECLARE order_summa NUMERIC;
DECLARE driver_id INT;
DECLARE car_id INT;
DECLARE curr_status_id INT;

DECLARE from_date date;
DECLARE lat numeric;
DECLARE lng numeric;

DECLARE agg_summa numeric DEFAULT 0;
DECLARE agg_name text;

DECLARE job_id BIGINT;
DECLARE job_nodename TEXT;
DECLARE job_schedule TEXT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.driver_id,coalesce(o.status_id,0),o.summa,o.from_time::date,o.from_addr_latitude,o.from_addr_longitude,(o.driver_car_attribs->>'car_id')::int
  FROM data.orders o 
   where o.id=order_id_ FOR UPDATE
   into order_id,driver_id,curr_status_id,order_summa,from_date,lat,lng,car_id;

  IF order_id is null 
  or curr_status_id<>110 /* Заказ выполняется */ 
  or driver_id<>driver_id_ 
  THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id = 120, /* Заказ выполнен по мнению водителя */
	                    end_time = CURRENT_TIMESTAMP
						where id = order_id_;

   --PERFORM sysdata.fill_order_location(order_id_,driver_id_);
   job_schedule = '* * * * *';
   job_nodename = (select param_value_string from sysdata."SYS_PARAMS" where param_name = 'CRON_NODENAME');
   job_id = cron.schedule(job_schedule, 'select count(*) from data.log');
   update cron.job set nodename = job_nodename,
                       command = 'select sysdata.cron_fill_order_location(' || order_id_::text || ',' || driver_id_::text || ',' || job_id || ')'
          where jobid = job_id;


   select cc.name,round(cc.stavka*order_summa/100.) from aggregator_api.calc_commission(from_date,lat,lng) cc
	into agg_name,agg_summa;
	
	delete from data.order_costs o where o.order_id=order_id_;
	insert into data.order_costs(id,order_id,cost_id,summa)
	 select nextval('data.order_costs_id_seq'),order_id_,dc.cost_id,round(dc.percent*(order_summa-agg_summa)/100.)
	  from data.driver_costs dc where dc.driver_id=driver_id_ and dc.percent<>0;
	
	with calc_tariff_costs as
	(
		select tc.id,tc.percent from data.tariff_costs tc
		left join data.tariffs t on tc.tariff_id=t.id
		left join data.driver_car_tariffs dct on dct.tariff_id=tc.tariff_id
		left join data.driver_cars dc on dc.id=dct.driver_car_id
		where dc.id=car_id and dc.driver_id=driver_id_ 
		and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date
	)
	insert into data.order_costs(id,order_id,tariff_cost_id,summa)
	 select nextval('data.order_costs_id_seq'),order_id_,ctc.id,round(ctc.percent*(order_summa-agg_summa)/100.)
	  from calc_tariff_costs ctc where ctc.percent<>0;

	 delete from data.order_agg_costs o where o.order_id=order_id_;  
     if agg_summa<>0 then
	   insert into data.order_agg_costs(id,order_id,cost_name,summa)
	    values(nextval('data.order_agg_costs_id_seq'),order_id_,agg_name,agg_summa);
	 end if; 
/*
     insert into data.order_agg_costs(id,order_id,cost_name,summa)
	  select nextval('data.order_agg_costs_id_seq'),order_id_,cc.name,round(cc.stavka*order_summa/100.)
	   from aggregator_api.calc_commission(from_date,lat,lng) cc where cc.stavka<>0;
*/	
     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,120,curr_status_id,'Finish') 
     on conflict do nothing;
								  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_finish_order(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 726 (class 1255 OID 16682)
-- Name: driver_finish_order(bigint, integer, text, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_finish_order(order_id_ bigint, driver_id_ integer, pass_ text, device_id_ text, device_name_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Завершение маршрута. 
*/ 
DECLARE order_id BIGINT;
DECLARE order_summa NUMERIC;
DECLARE driver_id INT;
DECLARE car_id INT;
DECLARE curr_status_id INT;

DECLARE from_date date;
DECLARE lat numeric;
DECLARE lng numeric;

DECLARE agg_summa numeric DEFAULT 0;
DECLARE agg_name text;

DECLARE device_record integer DEFAULT 0;

DECLARE job_id BIGINT;
DECLARE job_nodename TEXT;
DECLARE job_schedule TEXT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

device_record = aggregator_api.add_driver_device(driver_id_,device_id_,device_name_);
if device_record<1 then
  device_record = null;
end if;

  SELECT o.id,o.driver_id,coalesce(o.status_id,0),o.summa,o.from_time::date,o.from_addr_latitude,o.from_addr_longitude,(o.driver_car_attribs->>'car_id')::int
  FROM data.orders o 
   where o.id=order_id_ FOR UPDATE
   into order_id,driver_id,curr_status_id,order_summa,from_date,lat,lng,car_id;

  IF order_id is null 
  or curr_status_id<>110 /* Заказ выполняется */ 
  or driver_id<>driver_id_ 
  THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id = 120, /* Заказ выполнен по мнению водителя */
	                    end_time = CURRENT_TIMESTAMP,
						end_device_id = device_record
						where id = order_id_;

   --PERFORM sysdata.fill_order_location(order_id_,driver_id_);
   job_schedule = '* * * * *';
   job_nodename = (select param_value_string from sysdata."SYS_PARAMS" where param_name = 'CRON_NODENAME');
   job_id = cron.schedule(job_schedule, 'select count(*) from data.log');
   update cron.job set nodename = job_nodename,
                       command = 'select sysdata.cron_fill_order_location(' || order_id_::text || ',' || driver_id_::text || ',' || job_id || ')'
          where jobid = job_id;

   select cc.name,round(cc.stavka*order_summa/100.) from aggregator_api.calc_commission(from_date,lat,lng) cc
	into agg_name,agg_summa;
	
	delete from data.order_costs o where o.order_id=order_id_;
	insert into data.order_costs(id,order_id,cost_id,summa)
	 select nextval('data.order_costs_id_seq'),order_id_,dc.cost_id,round(dc.percent*(order_summa-agg_summa)/100.)
	  from data.driver_costs dc where dc.driver_id=driver_id_ and dc.percent<>0;
	
	with calc_tariff_costs as
	(
		select tc.id,tc.percent from data.tariff_costs tc
		left join data.tariffs t on tc.tariff_id=t.id
		left join data.driver_car_tariffs dct on dct.tariff_id=tc.tariff_id
		left join data.driver_cars dc on dc.id=dct.driver_car_id
		where dc.id=car_id and dc.driver_id=driver_id_ 
		and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date
	)
	insert into data.order_costs(id,order_id,tariff_cost_id,summa)
	 select nextval('data.order_costs_id_seq'),order_id_,ctc.id,round(ctc.percent*(order_summa-agg_summa)/100.)
	  from calc_tariff_costs ctc where ctc.percent<>0;

	 delete from data.order_agg_costs o where o.order_id=order_id_;  
     if agg_summa<>0 then
	   insert into data.order_agg_costs(id,order_id,cost_name,summa)
	    values(nextval('data.order_agg_costs_id_seq'),order_id_,agg_name,agg_summa);
	 end if; 
/*
     insert into data.order_agg_costs(id,order_id,cost_name,summa)
	  select nextval('data.order_agg_costs_id_seq'),order_id_,cc.name,round(cc.stavka*order_summa/100.)
	   from aggregator_api.calc_commission(from_date,lat,lng) cc where cc.stavka<>0;
*/	
     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,120,curr_status_id,'Finish') 
     on conflict do nothing;
								  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_finish_order(order_id_ bigint, driver_id_ integer, pass_ text, device_id_ text, device_name_ text) OWNER TO postgres;

--
-- TOC entry 727 (class 1255 OID 16683)
-- Name: driver_get_driver(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_get_driver(driver_id_ integer, pass_ text, OUT personal_data text, OUT bank_data text, OUT documents_data text, OUT array_cars text, OUT balance text, OUT photo text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Просмотр данных водителя.
*/

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

select json_build_object(
		 'id',d.id,
	     'login',d.login,
	     'name',d.name,
	     'second_name',d.second_name,
	     'family_name',d.family_name,
	     'is_active',d.is_active,
	     'level_id',d.level_id,
	     'level_name',dl.name,
	     'dispatcher_id',d.dispatcher_id,
	     'dispatcher_phone',disp.phone,
         'date_of_birth',d.date_of_birth,	 
	     'contact',d.contact,
	     'contact2',d.contact2,
	     'cars_count',(select count(*) from data.driver_cars dcrs where dcrs.driver_id=d.id),
	     'balls', (select sum(da.balls) from data.driver_activities da where da.driver_id=d.id),
	 	 'rating', (
						with last_docs as
						(
							select o.rating from data.orders o 
							where o.driver_id=d.id and o.status_id>=120 
							and exists(select 1 from data.order_ratings r where r.order_id=o.id and r.rating_value is not null)
							order by o.from_time desc
							limit 10
						)
						select (avg(rating))::numeric(6,2) from last_docs
		 			)
),
 json_build_object(		 
	     'bank',d.bank,
	     'bik',d.bik,
	     'korrschet',d.korrschet,
	     'rasschet',d.rasschet,
	     'poluchatel',d.poluchatel,
	     'inn',d.inn,
	     'kpp',d.kpp,
         'bank_card',d.bank_card),
 json_build_object(		 
	     'passport', (select json_build_object( 
	     				'serie',pass.doc_serie,
	     				'number',pass.doc_number,
	     				'date',pass.doc_date,	 
			            'from',pass.doc_from,	 
	     				'addresse',d.reg_addresse,
	     				'fact_addresse',d.fact_addresse) 
					   from data.driver_docs pass
					   where pass.driver_id=d.id and pass.doc_type=1
					 ),
	     'contract', (select json_build_object( 
	     				'number',contract.doc_number,
	     				'date1',contract.start_date,	 
			            'date2',contract.end_date) 
					   from data.driver_docs contract
					   where contract.driver_id=d.id and contract.doc_type=6
					 ),

	     'license', (select json_build_object( 
	     				'serie',license.doc_serie,
	     				'number',license.doc_number,
	     				'date1',license.start_date,	 
			            'date2',license.end_date) 
					   from data.driver_docs license
					   where license.driver_id=d.id and license.doc_type=10
					 ),
	     'medical', (select json_build_object( 
	     				'number',medical.doc_number,
	     				'date1',medical.start_date,	 
			            'date2',medical.end_date) 
					   from data.driver_docs medical
					   where medical.driver_id=d.id and medical.doc_type=5
					 ),
	     'insurance', (select json_build_object( 
	     				'serie',insurance.doc_serie,
	     				'number',insurance.doc_number,
	     				'date1',insurance.start_date,	 
			            'date2',insurance.end_date) 
					   from data.driver_docs insurance
					   where insurance.driver_id=d.id and insurance.doc_type=4
					 )
         )  
  from data.drivers d
  left join data.dispatchers disp on disp.id=d.dispatcher_id
  left join sysdata."SYS_DRIVERLEVELS" dl on dl.id=d.level_id
  where d.id=driver_id_
  into personal_data, bank_data, documents_data;

select array_to_json(ARRAY( SELECT json_build_object('id',dc.id,
									   'carclass_id',dc.carclass_id,
	                                   'carclass_name',cc.name,
									   'cartype_id',dc.cartype_id,
									   'cartype_name',ct.name,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active,
									   'is_default',coalesce(dc.is_default,false))
           FROM data.driver_cars dc
		   left join data.drivers d on dc.driver_id=d.id
           left join sysdata."SYS_CARCLASSES" cc on dc.carclass_id=cc.id
           left join sysdata."SYS_CARTYPES" ct on dc.cartype_id=ct.id
          WHERE dc.driver_id = driver_id_)) into array_cars;

select coalesce(encode(df.filedata,'base64'),'')
  from data.driver_docs dd
  left join data.driver_files df on df.doc_id=dd.id
  where dd.driver_id=driver_id_ and dd.doc_type=9
  LIMIT 1
  into photo; 

select api.get_balance(null,driver_id_,pass_) into balance;

END

$$;


ALTER FUNCTION api.driver_get_driver(driver_id_ integer, pass_ text, OUT personal_data text, OUT bank_data text, OUT documents_data text, OUT array_cars text, OUT balance text, OUT photo text) OWNER TO postgres;

--
-- TOC entry 728 (class 1255 OID 16685)
-- Name: driver_get_order(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_get_order(driver_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT radius_to_checkpoint real, OUT json_checkpoints text, OUT json_activity json) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Просмотр заказа.
Запись о просмотре в таблицу order_views.
*/
DECLARE driver_dispatcher_id integer default 0;
DECLARE curr_time TIMESTAMP WITHOUT TIME ZONE;
DECLARE dso_id BIGINT;
DECLARE finish_costs NUMERIC DEFAULT 0;
DECLARE canceled_order boolean;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)>0 then
 begin
  if EXISTS(select 1 from data.orders_rejecting orj where orj.order_id=order_id_ and orj.driver_id=driver_id_)
   or EXISTS(select 1 from data.orders_canceling ocl where ocl.order_id=order_id_ and ocl.driver_id=driver_id_)
    then
	 canceled_order = true;
   else -- не отмененный
     begin	 
	  /*Проверю, что водитель может это видеть*/
	  select d.dispatcher_id from data.drivers d where d.id = driver_id_ 
	  into driver_dispatcher_id;

      if not sysdata.order4driver(order_id_,driver_id_,driver_dispatcher_id) then
	   return;
	  end if;

	  curr_time = CURRENT_TIMESTAMP;
  
	  insert into data.order_views(id,order_id,driver_id,timeview)
	  values(nextval('data.order_views_id_seq'),order_id_,driver_id_,curr_time);

	  select dso.id from data.dispatcher_selected_orders dso 
	  where dso.order_id=order_id_ and dso.dispatcher_id=driver_dispatcher_id
	  into dso_id;

	  update data.dispatcher_selected_drivers set first_view_time=least(first_view_time,curr_time::timestamp(0))
	  where selected_id=dso_id and driver_id=driver_id_;
	  
	  canceled_order = false;
	 end; -- не отменный
   end if; -- проверка на отмену  
 end; 
 else -- проверка на пароль
  return;
end if;

select json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'point_id',o.point_id,	
		 'point_name',p.name,
		 'from_time',o.from_time,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
	     'from_addr_longitude',o.from_addr_longitude,
	     'from_kontakt_name',o.from_kontakt_name,
	     'from_kontakt_phone',o.from_kontakt_phone,
	     'from_notes',o.from_notes,
	     'summa',o.summa,
		 'costs', (select sum(agg_cost+all_costs) from sysdata.calc_costs(o.id, driver_id_, case canceled_order when true then 0 else null end)),
		
/*	
		 'costs', case when o.status_id>=120 then finish_costs else 
	       (
			With agg as 
            (
              select round(cc.stavka*o.summa/100.) agg_summa from aggregator_api.calc_commission(o.from_time::date,o.from_addr_latitude,o.from_addr_longitude) cc
            )
	       select (select sum(round(dc.percent*(o.summa-agg.agg_summa)/100.)) from data.driver_costs dc
                   left join agg on agg.agg_summa<>0
                    where dc.driver_id=o.driver_id and dc.percent<>0)  +  
	              (select sum(agg.agg_summa) from agg)
			)
	      end,
*/	
		 'dispatcher_id',o.dispatcher_id,
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name_for_driver,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'carclass_name',coalesce(cc.name,'Любой'),
		 'paytype_id',coalesce(o.paytype_id,0),
		 'paytype_name',coalesce(pt.name,'Любой'),
		 'hours',coalesce(o.hours,0),
		 'client_id',o.client_id,
		 'client_name',cl.name,
		 'driver_car_attribs',o.driver_car_attribs,
		 'distance',o.distance,
		 'duration',o.duration,
		 'duration_calc',o.duration_calc,
		 'notes',o.notes,
         'last_status_change',(select json_build_object(
			                                  'time',l.datetime::timestamp(0),
			                                  'status',l.status_new)
							     from data.order_log l
							     where l.order_id=o.id and 
							           l.status_old<>l.status_new
							     order by l.datetime desc
							     limit 1),
	      'addcoords',(select array_to_json(ARRAY( SELECT json_build_object('latitude',cpc.latitude,
																			'longitude',cpc.longitude) 
												   from data.client_point_coordinates cpc 
												    where cpc.point_id=o.point_id
												  )
											)
		              )

      )
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join sysdata."SYS_PAYTYPES" pt on pt.id=o.paytype_id
 left join sysdata."SYS_CARCLASSES" cc on cc.id=o.carclass_id
 left join data.clients cl on cl.id=o.client_id
 left join data.drivers d on d.id=o.driver_id
  where o.id=order_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'order_id',c.order_id,
									   'to_point_id',c.to_point_id,
									   'to_point_name',p.name,
									   'to_addr_name',c.to_addr_name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'to_notes',c.notes,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'addcoords',(select array_to_json(ARRAY( SELECT json_build_object('latitude',cpc.latitude,
																			'longitude',cpc.longitude) 
												   from data.client_point_coordinates cpc where cpc.point_id=c.to_point_id
												                               )
											                              )
													),
									   'by_driver',c.by_driver,
									   'photos',c.photos,
		              				   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = order_id_
		  ORDER BY c.position_in_order)) 
		  into json_checkpoints;
		
radius_to_checkpoint = 0;		
select coalesce(param_value_real,0) from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT' 
limit 1 into radius_to_checkpoint;

with sp as (
  SELECT param_name as "type", param_value_integer as "value"
  FROM sysdata."SYS_PARAMS" where param_name like 'ACTIVITY_%'
)
select json_agg(sp) from sp into json_activity;
						   
END

$$;


ALTER FUNCTION api.driver_get_order(driver_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT radius_to_checkpoint real, OUT json_checkpoints text, OUT json_activity json) OWNER TO postgres;

--
-- TOC entry 729 (class 1255 OID 16687)
-- Name: driver_get_order_locations(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_get_order_locations(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS TABLE(datetime timestamp without time zone, latitude numeric, longitude numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
 select l.datetime,l.latitude,l.longitude
  from (select l.datetime,l.latitude,l.longitude, lag(l.latitude) over (order by l.datetime) as prev_latitude,lag(l.longitude) over (order by l.datetime) as prev_longitude
      from data.order_locations l
	  where l.order_id=order_id_ and l.driver_id=driver_id_
     ) l
 where l.prev_latitude is distinct from l.latitude and l.prev_longitude is distinct from l.longitude
 order by l.datetime;

END

$$;


ALTER FUNCTION api.driver_get_order_locations(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 730 (class 1255 OID 16688)
-- Name: driver_get_point_rating(integer, text, integer, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_get_point_rating(driver_id_ integer, pass_ text, point_id_ integer, order_id_ bigint) RETURNS TABLE(point_name character varying, point_address character varying, rating numeric, commentary text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Просмотр рейтинга точки по заказу.
*/

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT 
	cp.name,
	cp.address,
	coalesce(pr.rating,0),
	coalesce(pr.commentary,'')
   FROM data.client_points cp
   left join data.point_rating pr on pr.point_id=cp.id and pr.order_id=order_id_ and pr.driver_id = driver_id_
   where cp.id=point_id_;
  
END

$$;


ALTER FUNCTION api.driver_get_point_rating(driver_id_ integer, pass_ text, point_id_ integer, order_id_ bigint) OWNER TO postgres;

--
-- TOC entry 731 (class 1255 OID 16689)
-- Name: driver_get_rating_docs(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_get_rating_docs(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, from_addr_name character varying, order_title character varying, rating numeric, rating_detail json)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Список заказов дял рейтинга.
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
    o.from_addr_name,
	o.order_title,
	o.rating,
	(select array_to_json(ARRAY( SELECT json_build_object('id',ort.id,
														  'rating_id',ort.rating_id,
														  'rating_name',sp.name,
														  'rating_value',ort.rating_value) 
												   from data.order_ratings ort 
								                   left join sysdata."SYS_ROUTERATING_PARAMS" sp on sp.id=ort.rating_id
												    where ort.order_id=o.id
												  )
											)
		              )
   FROM data.orders o
  WHERE o.driver_id = driver_id_ and status_id>=120 and o.rating is not null
  order by o.from_time desc
  limit 10;
  
END

$$;


ALTER FUNCTION api.driver_get_rating_docs(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 732 (class 1255 OID 16690)
-- Name: driver_my_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_my_orders(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, carclass_id integer, paytype_id integer, notes character varying, order_title character varying, rating numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Мои заказы.
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
    o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.summa - (select sum(agg_cost+all_costs) from sysdata.calc_costs(o.id,driver_id_,null)),
    COALESCE(o.status_id, 0) AS status_id,
	st.name_for_driver,
	o.carclass_id,
	o.paytype_id,
    o.notes,
	o.order_title,
	o.rating		  
   FROM data.orders o
   LEFT JOIN sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
  WHERE o.driver_id = driver_id_ /*and (coalesce(o.status_id,0) in (40,50,60) )*/;
  
END

$$;


ALTER FUNCTION api.driver_my_orders(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 733 (class 1255 OID 16691)
-- Name: driver_reject_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_reject_order(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Отклонение возможного заказа. Только с заказами со статусами (30 (новый),50 (назначенный)).
История отмен записывается в data.orders_rejecting . После этого заказ выпадает из available_orders
*/

DECLARE order_id BIGINT;
DECLARE curr_status_id INTEGER;
DECLARE reject_balls INTEGER;
DECLARE curr_time TIMESTAMP WITHOUT TIME ZONE;
DECLARE dso_id BIGINT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,curr_status_id;
  
  select dso.id from data.dispatcher_selected_orders dso 
  where dso.order_id=order_id_ and dso.dispatcher_id=(select d.dispatcher_id from data.drivers d where d.id=driver_id_)
  into dso_id;
  
  if not exists(select 1 from data.dispatcher_selected_drivers dsd
				where dsd.selected_id = dso_id and dsd.driver_id = driver_id_
			   ) then
     return false;
  end if;

  IF coalesce(order_id,0)>0 and curr_status_id in (30,50) THEN /* Новый или назначенный */
	 curr_time = CURRENT_TIMESTAMP;

    insert into data.orders_rejecting (id,order_id,driver_id,reject_order) 
	                          values(nextval('data.orders_rejecting_id_seq'),order_id_,driver_id_,curr_time);
	
	update data.dispatcher_selected_drivers set reject_time=curr_time::timestamp(0)
	where selected_id=dso_id and driver_id=driver_id_;
    
	reject_balls = (select sp.param_value_integer from sysdata."SYS_PARAMS" sp 
							 where sp.param_name='ACTIVITY_CANCEL_ORDER');
			 
	insert into data.driver_activities (id, driver_id, datetime, balls, type_id)
			 				  values(nextval('data.driver_activities_id_seq'),driver_id_,curr_time, reject_balls, 2);
    
	insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,curr_time,curr_status_id,curr_status_id,'Reject') 
     on conflict do nothing;
								  
  END IF;  

  return true;

END

$$;


ALTER FUNCTION api.driver_reject_order(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 734 (class 1255 OID 16692)
-- Name: driver_request_money(integer, text, numeric); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_request_money(driver_id_ integer, pass_ text, summa_ numeric) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Запрос денег.
Возврат успех/неуспех.
*/

DECLARE driver_dispatcher_id INT DEFAULT NULL;
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

select d.dispatcher_id from data.drivers d 
where d.id = driver_id_
into driver_dispatcher_id;

if coalesce(driver_dispatcher_id,0)<1 then
 return false;
end if;

insert into data.money_requests(id,driver_id,dispatcher_id,summa,datetime,unread)
values (nextval('data.money_requests_id_seq'),driver_id_,driver_dispatcher_id,summa_,CURRENT_TIMESTAMP::timestamp(0),true);
							
return true;

END

$$;


ALTER FUNCTION api.driver_request_money(driver_id_ integer, pass_ text, summa_ numeric) OWNER TO postgres;

--
-- TOC entry 735 (class 1255 OID 16693)
-- Name: driver_set_car_active(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_set_car_active(driver_id_ integer, pass_ text, car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается водителем.
Обновление информации о банке.
Возвращает true/false.
*/

begin

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

if driver_id_<>(select dc.driver_id from data.driver_cars dc where dc.id=car_id_) then
  return false;
end if;

update data.driver_cars set is_default = case id when car_id_ then true else false end
where driver_id=driver_id_;	   
	 
return true;

end

$$;


ALTER FUNCTION api.driver_set_car_active(driver_id_ integer, pass_ text, car_id_ integer) OWNER TO postgres;

--
-- TOC entry 736 (class 1255 OID 16694)
-- Name: driver_take_order(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_take_order(order_id_ bigint, driver_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
ВЕРСИЯ >=2.1 (16)
Вызывается водителем.
Взятие заказа с записью в историю взятых заказов.
Возврат успех/неуспех.
*/

DECLARE order_id BIGINT;
DECLARE driver_id INT;
DECLARE curr_status_id INT;
DECLARE carclass_id INT;
DECLARE car_id INT;
DECLARE car_attribs JSONB;
DECLARE curr_time TIMESTAMP WITHOUT TIME ZONE;
DECLARE take_balls INT;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,coalesce(o.status_id,0),coalesce(o.driver_id,0),coalesce(o.carclass_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,curr_status_id,driver_id,carclass_id;

  IF order_id is null or curr_status_id<>30 or driver_id>0 
    or exists(select 1 from data.orders_rejecting o where o.order_id=order_id_ and o.driver_id=driver_id_) THEN
	 return false;
  END IF;
  
  if not exists(select 1 from data.dispatcher_selected_drivers dsd 
				    left join data.dispatcher_selected_orders dso on dso.id=dsd.selected_id
				where dso.order_id = order_id_ and dsd.driver_id = driver_id_ and coalesce(dso.is_active, true)
			   ) then
     return false;
  end if;
	
  if carclass_id > 0 then
    car_id = (select dc.id from data.driver_cars dc where dc.driver_id = driver_id_ and dc.carclass_id = carclass_id and dc.is_active order by coalesce(dc.is_default,false) desc limit 1);
  else
    car_id = (select dc.id from data.driver_cars dc where dc.driver_id = driver_id_ and dc.is_active and dc.is_default limit 1);
  end if;
	select json_build_object(
		 'car_id',dc.id,
	     'cartype_id',dc.cartype_id,
		 'cartype_name',ct.name,
		 'carclass_id',dc.carclass_id,
		 'carclass_name',cc.name,
		 'carmodel',dc.carmodel,
		 'carnumber',dc.carnumber,
		 'carcolor',dc.carcolor)
    from data.driver_cars dc
	left join sysdata."SYS_CARCLASSES" cc on cc.id=dc.carclass_id
	left join sysdata."SYS_CARTYPES" ct on ct.id=dc.cartype_id
	where dc.id = car_id into car_attribs;
	  
	curr_time = CURRENT_TIMESTAMP;
     UPDATE data.orders set driver_id=driver_id_,
	                        status_id=40, /*взят водителем*/
							dispatcher_id=(select d.dispatcher_id from data.drivers d where d.id=driver_id_), /* возможно, придется м поменять алгоритм */
	                        driver_car_attribs=car_attribs
	                    where id=order_id_;
						
	 insert into data.orders_taking (id,order_id,driver_id,take_order,driver_car_attribs) 
	                          values(nextval('data.orders_taking_id_seq'),order_id_,driver_id_,curr_time,car_attribs);
	
	take_balls = (select sp.param_value_integer from sysdata."SYS_PARAMS" sp 
							 where sp.param_name='ACTIVITY_GET_ORDER');
			 
	insert into data.driver_activities (id, driver_id, datetime, balls, type_id)
			 				  values(nextval('data.driver_activities_id_seq'),driver_id_,curr_time, take_balls, 1);

     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,curr_time,40,curr_status_id,'Take') 
     on conflict do nothing;
								  
							  
     return true;

END

$$;


ALTER FUNCTION api.driver_take_order(order_id_ bigint, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 737 (class 1255 OID 16695)
-- Name: driver_take_order(bigint, integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_take_order(order_id_ bigint, driver_id_ integer, pass_ text, car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
ВЕРСИЯ <=1.15 (15)
Вызывается водителем.
Взятие заказа с записью в историю взятых заказов.
Возврат успех/неуспех.
*/

DECLARE order_id BIGINT;
DECLARE driver_id INT;
DECLARE curr_status_id INT;
DECLARE car_attribs JSONB;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,coalesce(o.status_id,0),coalesce(o.driver_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,curr_status_id,driver_id;

  IF order_id is null or curr_status_id<>30 or driver_id>0 
    or exists(select 1 from data.orders_rejecting o where o.order_id=order_id_ and o.driver_id=driver_id_) THEN
	 return false;
  ELSE
    BEGIN
	
	select json_build_object(
		 'car_id',dc.id,
	     'cartype_id',dc.cartype_id,
		 'cartype_name',ct.name,
		 'carclass_id',dc.carclass_id,
		 'carclass_name',cc.name,
		 'carmodel',dc.carmodel,
		 'carnumber',dc.carnumber,
		 'carcolor',dc.carcolor)
    from data.driver_cars dc
	left join sysdata."SYS_CARCLASSES" cc on cc.id=dc.carclass_id
	left join sysdata."SYS_CARTYPES" ct on ct.id=dc.cartype_id
	where dc.id = car_id_ into car_attribs;
	  
     UPDATE data.orders set driver_id=driver_id_,
	                        status_id=40, /*взят водителем*/
							dispatcher_id=(select d.dispatcher_id from data.drivers d where d.id=driver_id_), /* возможно, придется м поменять алгоритм */
	                        driver_car_attribs=car_attribs
	                    where id=order_id_;
						
	 insert into data.orders_taking (id,order_id,driver_id,take_order,driver_car_attribs) 
	                          values(nextval('data.orders_taking_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,car_attribs);

     insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
     values (nextval('data.order_log_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP,40,curr_status_id,'Take') 
     on conflict do nothing;
								  
							  
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.driver_take_order(order_id_ bigint, driver_id_ integer, pass_ text, car_id_ integer) OWNER TO postgres;

--
-- TOC entry 739 (class 1255 OID 16696)
-- Name: driver_view_balance(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_view_balance(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, doc_type text, doc_date date, summa numeric, commentary character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается водителем.
Просмотр детализации денежных средств без комиссий.
*/
DECLARE query_dispatcher_id integer default 0;

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

select d.dispatcher_id from data.drivers d where d.id = driver_id_ 
into query_dispatcher_id;

RETURN QUERY  
select balance.* from (
select o.id, 'O' doc_type, 
	o.from_time::date doc_date, 
	o.summa - (select sum(agg_cost+all_costs) from sysdata.calc_costs(o.id,null,null)), 
	o.order_title commentary 
	from data.orders o where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_ and o.status_id>=120
 union all
select f.id, 'F' doc_type, f.paid::date doc_date, f.summa, ('Платежный документ №'||cast(f.opernumber as character varying)||' от '||cast(f.operdate::date as character varying)||'. '||coalesce(f.commentary,'')) commentary from data.feedback f where f.dispatcher_id = query_dispatcher_id and f.driver_id=driver_id_ and not f.paid is null and not coalesce(f.is_deleted,false)
 union all
select p.id, 'P' doc_type, p.operdate::date doc_date, p.summa, p.commentary commentary from data.addsums p where p.dispatcher_id = query_dispatcher_id and p.driver_id=driver_id_ and p.summa>0 and not coalesce(p.is_deleted,false)
 union all
select m.id, 'M' doc_type, m.operdate::date doc_date, m.summa, m.commentary commentary from data.addsums m where m.dispatcher_id = query_dispatcher_id and m.driver_id=driver_id_ and m.summa<0 and not coalesce(m.is_deleted,false)
	) as balance order by 3 desc,2;
END

$$;


ALTER FUNCTION api.driver_view_balance(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 740 (class 1255 OID 16697)
-- Name: driver_view_calendar(integer, text, integer, integer, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_view_calendar(driver_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying) RETURNS TABLE(cal_date date, cal_route_id integer, route_name text, daytype_id integer, daytype_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Просмотр календаря на месяц.
*/

DECLARE driver_dispatcher integer;
DECLARE first_date date;
DECLARE year_month character varying;
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

select d.dispatcher_id from data.drivers d where d.id=driver_id_ into driver_dispatcher;

year_month = (year_||'-'||TO_CHAR(month_,'fm00'))::character varying;
first_date = (year_month||'-01')::date;
RETURN QUERY  
	with dates as
(
	select gs::date from generate_series(first_date, (date_trunc('month', first_date) + interval '1 month' - interval '1 day')::date, interval '1 day') as gs
)
SELECT dates.gs,cals.route_id,coalesce(r.name,''),cals.daytype_id,rc.name
FROM dates
left join data.calendar_final cals on cals.cdate=dates.gs and cals.dispatcher_id=driver_dispatcher and cals.driver_id=driver_id_ and to_char(cals.cdate, 'YYYY-MM')=year_month
left join data.dispatcher_routes r on r.id=cals.route_id
left join sysdata."SYS_DAYTYPES" dt on dt.id=cals.daytype_id
left join sysdata."SYS_RESOURCES" rc on rc.resource_id=dt.resource_id and rc.country_code=code_;
--where cals.cdate is not null;
  
END

$$;


ALTER FUNCTION api.driver_view_calendar(driver_id_ integer, pass_ text, year_ integer, month_ integer, code_ character varying) OWNER TO postgres;

--
-- TOC entry 741 (class 1255 OID 16698)
-- Name: driver_view_point_ratings(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.driver_view_point_ratings(driver_id_ integer, pass_ text) RETURNS TABLE(id integer, point_id integer, point_name character varying, order_id bigint, rating numeric, commentary text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается водителем.
Просмотр своих рейтингов
*/

BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT pr.id,
	pr.point_id,
	cp.name,
	pr.order_id,
	pr.rating,
	pr.commentary
   FROM data.point_rating pr
   left join data.client_points cp on pr.point_id=cp.id
   WHERE pr.driver_id = driver_id_;
  
END

$$;


ALTER FUNCTION api.driver_view_point_ratings(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 742 (class 1255 OID 16699)
-- Name: exec_order_client(bigint, integer, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.exec_order_client(order_id_ bigint, client_id_ integer, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером или клиентом.
Установка статуса заказа, как окончательно выполненного. 
Только свои заказы.
*/ 
DECLARE order_id BIGINT;
DECLARE dispatcher_id INT;
DECLARE client_id INT;
DECLARE curr_status_id INT;
DECLARE is_dispatcher BOOLEAN DEFAULT FALSE;

BEGIN

if coalesce(dispatcher_id_,0) >0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return false;
   end if;
  is_dispatcher = true;
 end;
else
 begin
   if sysdata.check_id_client(client_id_,pass_)<1 then
    return false;
   end if;
  is_dispatcher = false;
 end;
end if; 

  SELECT o.id,o.dispatcher_id,o.client_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,dispatcher_id,client_id,curr_status_id;
  
  IF order_id is null or curr_status_id<>2 or (is_dispatcher and dispatcher_id<>dispatcher_id_) or (not is_dispatcher and client_id<>client_id_) THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id=3
						where id=order_id_;
	 
	 if is_dispatcher then					
	   insert into data.order_exec_clients(id,order_id,client_id,dispatcher_id,exec_order) 
	                            values(nextval('data.order_exec_clients_id_seq'),order_id_,null,dispatcher_id_,CURRENT_TIMESTAMP);
	 else
	   insert into data.order_exec_clients(id,order_id,client_id,dispatcher_id,exec_order) 
	                            values(nextval('data.order_exec_clients_id_seq'),order_id_,client_id_,null,CURRENT_TIMESTAMP);
	 end if;
	
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.exec_order_client(order_id_ bigint, client_id_ integer, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 743 (class 1255 OID 16700)
-- Name: exec_order_dispatcher(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.exec_order_dispatcher(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером.
Установка статуса заказа, как выполненного. 
Только свои заказы.
*/ 
DECLARE order_id BIGINT;
DECLARE dispatcher_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.dispatcher_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,dispatcher_id,curr_status_id;

  IF order_id is null or curr_status_id<>1 or dispatcher_id<>dispatcher_id_ THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id=2
						where id=order_id_;
	 insert into data.order_exec_dispatchers(id,order_id,dispatcher_id,exec_order) 
	                          values(nextval('data.order_exec_dispatchers_id_seq'),order_id_,dispatcher_id_,CURRENT_TIMESTAMP);
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.exec_order_dispatcher(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 724 (class 1255 OID 16701)
-- Name: executed_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.executed_orders(driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, from_time timestamp without time zone, order_title character varying, summa numeric, status_id integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается водителем.
Просмотр своих выполненных заказов (статус больше 1)
*/
BEGIN

if sysdata.check_id_driver(driver_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,	
	o.from_time,
    o.order_title,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id
   FROM data.orders o
  WHERE (o.driver_id = driver_id_) 
    AND (coalesce(o.status_id,0)>1);
  
END

$$;


ALTER FUNCTION api.executed_orders(driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 745 (class 1255 OID 16702)
-- Name: get_addsum(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ integer, OUT driver_id integer, OUT driver_name text, OUT operdate date, OUT commentary text, OUT summa numeric, OUT scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select a.driver_id,
        coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
	    a.operdate,
	    a.commentary,
		a.summa,
		cast(ARRAY( SELECT xmlforest(af.id,af.filename) 
			 from data.addsums_files af 
			  left join data.addsums_docs ad on af.doc_id=ad.id
			  where ad.addsum_id=a.id) as text)
 from data.addsums a
 left join data.drivers d on d.id=a.driver_id
 where a.id=addsum_id_ and a.dispatcher_id=dispatcher_id_
  into driver_id,
       driver_name,
	   operdate,
	   commentary,
	   summa,
	   scan;

END

$$;


ALTER FUNCTION api.get_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ integer, OUT driver_id integer, OUT driver_name text, OUT operdate date, OUT commentary text, OUT summa numeric, OUT scan text) OWNER TO postgres;

--
-- TOC entry 746 (class 1255 OID 16703)
-- Name: get_addsums_file(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE photo text;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select encode(af.filedata,'base64') from data.addsums_files af where af.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION api.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 747 (class 1255 OID 16704)
-- Name: get_balance(integer, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_balance(dispatcher_id_ integer, driver_id_ integer, pass_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается диспетчером или водителем.
Вернуть баланс в виде json
*/

DECLARE ok boolean default false; 
DECLARE res text;
DECLARE query_dispatcher_id integer default 0;

DECLARE _pay_date_ date;
DECLARE _days_in_month_ integer;
DECLARE _day_of_week_ integer;
DECLARE _year_ integer;
DECLARE _month_ integer;
DECLARE _day_ integer;

DECLARE get_sum numeric;
begin
if coalesce(dispatcher_id_,0)>0 then
 begin
   query_dispatcher_id = dispatcher_id_;
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 
     and (select d.dispatcher_id from data.drivers d where d.id=driver_id_)=dispatcher_id_ then
     ok = true;
   end if;
 end;
else
  begin
    if coalesce(driver_id_,0)>0 then
      begin	  
        if sysdata.check_id_driver(driver_id_,pass_)>0 then
          ok = true;
        end if;
		select d.dispatcher_id from data.drivers d where d.id = driver_id_ 
		into query_dispatcher_id;
       end;
	 end if;  
   end;
end if;  
  
if not ok then
 return NULL::text;
end if; 

_pay_date_ = CURRENT_DATE;
_year_ = extract(year from _pay_date_);
_month_ = extract(month from _pay_date_);
_day_ = extract(day from _pay_date_);
_days_in_month_ = DATE_PART('days', DATE_TRUNC('month', _pay_date_) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL);

if _day_>1 and _day_<7 then
 _day_ = 7;
elsif _day_<15 then
 _day_=15;
elsif _day_<22 then
 _day_=22;
elsif _day_<31 then
 _day_=_days_in_month_;
end if; 

_pay_date_ = make_date(_year_,_month_,_day_);
_day_of_week_ = extract(isodow from _pay_date_);

if _day_of_week_=6 or _day_of_week_=7 then
  _pay_date_ = _pay_date_ + interval '1 day' * (8 - _day_of_week_);
end if;

get_sum = coalesce((SELECT sum(summa) FROM data.feedback f where f.dispatcher_id = query_dispatcher_id and f.driver_id=driver_id_ and not f.paid is null and not coalesce(f.is_deleted,false)),0);

with work_dates as
(
	SELECT o.from_time::date work_date,sum(summa) work_sum FROM data.orders o 
	 where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_ and o.status_id>=120 group by 1 order by 1
),
 cost_dates as
(
 select costs.* from (
	SELECT o.from_time::date cost_date, sum(oc.summa) cost_sum FROM data.order_costs oc 
	left join data.orders o on oc.order_id=o.id where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_	
    group by 1
	 UNION ALL	
	SELECT o.from_time::date cost_date, sum(oac.summa) cost_sum FROM data.order_agg_costs oac 
	left join data.orders o on oac.order_id=o.id where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_
	group by 1
  ) as costs order by 1	 
),
 add_dates as
(
	SELECT a.operdate::date add_date,sum(a.summa) add_sum, case when a.summa<0 then -1 else 1 end as add_koeff FROM data.addsums a 
	 where a.dispatcher_id = query_dispatcher_id and a.driver_id=driver_id_ and not coalesce(a.is_deleted,false)
     group by 1,3 order by 3,1	
)
select json_build_object('work',
                         (SELECT sum(work_sum) FROM work_dates),
						 'last14',
                         (SELECT sum(work_sum) FROM work_dates where (CURRENT_DATE - work_date)<=14),						 
						 'cost',
                         (SELECT sum(cost_sum) FROM cost_dates),
						 'get',get_sum,
						 'plus',
						 (SELECT sum(add_sum) FROM add_dates where add_koeff=1),
						 'minus',
						 (SELECT sum(add_sum) FROM add_dates where add_koeff=-1),
						 'payDate',_pay_date_,
						 'paySum',( coalesce((SELECT sum(work_sum) FROM work_dates where (CURRENT_DATE - work_date)>14),0)
									- get_sum
									-coalesce((SELECT sum(cost_sum) FROM cost_dates where (CURRENT_DATE - cost_date)>14),0)
									+coalesce((SELECT sum(add_sum) FROM add_dates where (CURRENT_DATE - add_date)>14),0)
								)						 
                        ) into res;

return res;
 
end

$$;


ALTER FUNCTION api.get_balance(dispatcher_id_ integer, driver_id_ integer, pass_ text) OWNER TO postgres;

SET default_tablespace = '';

--
-- TOC entry 208 (class 1259 OID 16705)
-- Name: SYS_CARCLASSES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_CARCLASSES" (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE sysdata."SYS_CARCLASSES" OWNER TO postgres;

--
-- TOC entry 748 (class 1255 OID 16708)
-- Name: get_car_classes(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_car_classes() RETURNS SETOF sysdata."SYS_CARCLASSES"
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

select 
 cc.id,
 cc.name
 from sysdata."SYS_CARCLASSES" cc
 order by cc.id;

$$;


ALTER FUNCTION api.get_car_classes() OWNER TO postgres;

--
-- TOC entry 749 (class 1255 OID 16709)
-- Name: get_car_types(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_car_types() RETURNS TABLE(id integer, name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр типов автомобилей.
*/
BEGIN

  RETURN QUERY  
    select 
     st.id,
     st.name
     from sysdata."SYS_CARTYPES" st
     order by st.name; 
END

$$;


ALTER FUNCTION api.get_car_types() OWNER TO postgres;

--
-- TOC entry 750 (class 1255 OID 16710)
-- Name: get_checkpoint_history(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_checkpoint_history(dispatcher_id_ integer, pass_ text, get_rows integer DEFAULT NULL::integer) RETURNS TABLE(id bigint, name_long character varying, name_short character varying, latitude numeric, longitude numeric, kontakt_name character varying, kontakt_phone character varying, notes character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$
/*
Вызывается диспетчером.
Просмотр истории чекпойнтов (если указано get_rows, то количество не больше get_rows).
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if get_rows is null or get_rows=0 then
 begin
  RETURN QUERY  
	SELECT ch.id,	
	ch.name_long,
    ch.name_short,
    ch.latitude,
    ch.longitude,
    ch.kontakt_name,
    ch.kontakt_phone,
	ch.notes
   FROM data.checkpoint_history ch
  WHERE (ch.dispatcher_id = dispatcher_id_) order by ch.id desc;
 end;
else
 begin
  RETURN QUERY  
	SELECT ch.id,	
	ch.name_long,
    ch.name_short,
    ch.latitude,
    ch.longitude,
    ch.kontakt_name,
    ch.kontakt_phone,
	ch.notes
   FROM data.checkpoint_history ch
  WHERE (ch.dispatcher_id = dispatcher_id_) order by ch.id desc limit get_rows;
 end;
end if; 
 
END

$$;


ALTER FUNCTION api.get_checkpoint_history(dispatcher_id_ integer, pass_ text, get_rows integer) OWNER TO postgres;

--
-- TOC entry 751 (class 1255 OID 16711)
-- Name: get_checkpoints_in_order(text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_checkpoints_in_order(hash text, order_id_ bigint) RETURNS TABLE(id bigint, to_addr_name character varying, to_addr_latitude numeric, to_addr_longitude numeric, to_time_to timestamp without time zone, kontakt_name character varying, kontakt_phone character varying, notes character varying, distance_to real, duration_to integer, visited_status boolean, visited_time timestamp without time zone, position_in_order integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается кем угодно.
Просмотр чекпойнтов по заказу.
*/ 
BEGIN

if not sysdata.check_signing(hash) then
 return;
end if;

 RETURN QUERY  
	SELECT c.id,	
	c.to_addr_name,
    c.to_addr_latitude,
    c.to_addr_longitude,
    c.to_time_to,
	c.kontakt_name,
	c.kontakt_phone,
	c.notes,
	c.distance_to,
	c.duration_to,
	c.visited_status,
	c.visited_time,
	c.position_in_order
   FROM data.checkpoints c
  WHERE (c.order_id = order_id_) ORDER BY c.position_in_order;
  
END

$$;


ALTER FUNCTION api.get_checkpoints_in_order(hash text, order_id_ bigint) OWNER TO postgres;

--
-- TOC entry 752 (class 1255 OID 16712)
-- Name: get_dispatcher(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_dispatcher(dispatcher_id_ integer, pass_ text, OUT login character varying, OUT name character varying, OUT second_name character varying, OUT family_name character varying, OUT is_active boolean) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр своих данных (данных диспетчера).
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select d.login,
    d.name,
    d.second_name,
    d.family_name,
	d.is_active
  from data.dispatchers d
  where d.id=dispatcher_id_ 
  into login,
    name,
	second_name,
    family_name,
	is_active;

END

$$;


ALTER FUNCTION api.get_dispatcher(dispatcher_id_ integer, pass_ text, OUT login character varying, OUT name character varying, OUT second_name character varying, OUT family_name character varying, OUT is_active boolean) OWNER TO postgres;

--
-- TOC entry 753 (class 1255 OID 16713)
-- Name: get_dogovor_types(character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_dogovor_types(code_ character varying) RETURNS TABLE(id integer, name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр типов договоров.
*/
BEGIN

  RETURN QUERY  
    select 
     dt.id,
     rc.name
     from sysdata."SYS_DOGOVOR_TYPES" dt
	 left join sysdata."SYS_RESOURCES" rc on rc.resource_id=dt.resource_id and rc.country_code=code_
     order by dt.id; 
END

$$;


ALTER FUNCTION api.get_dogovor_types(code_ character varying) OWNER TO postgres;

--
-- TOC entry 738 (class 1255 OID 16714)
-- Name: get_driver(integer, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver(dispatcher_id_ integer, driver_id_ integer, pass_ text, OUT json_data text, OUT array_cars text, OUT balance jsonb, OUT costs text, OUT can_delete boolean, OUT photo text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается водителем или диспетчером.
Просмотр данных водителя.
*/

DECLARE ok boolean DEFAULT false;

BEGIN

if coalesce(dispatcher_id_,0)>0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
     ok = true;
   end if;
 end;
else
  begin
    if coalesce(driver_id_,0)>0 then
      begin
        if sysdata.check_id_driver(driver_id_,pass_)>0 then
          ok = true;
        end if;
       end;
	 end if;  
   end;
end if;  
  
if not ok then
 return;
end if; 
 
 select json_build_object(
		 'id',d.id,
	     'login',d.login,
	     'name',d.name,
	     'second_name',d.second_name,
	     'family_name',d.family_name,
	     'is_active',d.is_active,
	     'level_id',d.level_id,
	     'level_name',dl.name,
	     'contract_id',d.contract_id,
	 	 'restrictions',d.restrictions,
	     'dispatcher_id',d.dispatcher_id,
         'date_of_birth',d.date_of_birth,	 
	     'contact',d.contact,
	     'contact2',d.contact2,
	     'cars_count',(select count(*) from data.driver_cars dcrs where dcrs.driver_id=d.id),
	     'bank_card',d.bank_card,
	     'bank',d.bank,
	     'bik',d.bik,
	     'korrschet',d.korrschet,
	     'rasschet',d.rasschet,
	     'poluchatel',d.poluchatel,
	     'inn',d.inn,
	     'kpp',d.kpp,
	     'ogrnip',d.ogrnip,
	     'passport', (select json_build_object( 
	     				'serie',pass.doc_serie,
	     				'number',pass.doc_number,
	     				'date',pass.doc_date,	 
			            'from',pass.doc_from,	 
	     				'addresse',d.reg_addresse,
			            'reg_address_lat',d.reg_address_lat,
			            'reg_address_lon',d.reg_address_lng,
	     				'fact_addresse',d.fact_addresse,
			            'fact_address_lat',d.fact_address_lat,
			            'fact_address_lon',d.fact_address_lng
		                ) 
					   from data.driver_docs pass
					   where pass.driver_id=d.id and pass.doc_type=1
					 ),
	     'contract', (select json_build_object( 
	     				'number',contract.doc_number,
	     				'date1',contract.start_date,	 
			            'date2',contract.end_date) 
					   from data.driver_docs contract
					   where contract.driver_id=d.id and contract.doc_type=6
					 ),

	     'license', (select json_build_object( 
	     				'serie',license.doc_serie,
	     				'number',license.doc_number,
	     				'date1',license.start_date,	 
			            'date2',license.end_date) 
					   from data.driver_docs license
					   where license.driver_id=d.id and license.doc_type=10
					 ),
	     'medical', (select json_build_object( 
	     				'number',medical.doc_number,
	     				'date1',medical.start_date,	 
			            'date2',medical.end_date) 
					   from data.driver_docs medical
					   where medical.driver_id=d.id and medical.doc_type=5
					 ),
	     'insurance', (select json_build_object( 
	     				'serie',insurance.doc_serie,
	     				'number',insurance.doc_number,
	     				'date1',insurance.start_date,	 
			            'date2',insurance.end_date) 
					   from data.driver_docs insurance
					   where insurance.driver_id=d.id and insurance.doc_type=4
					 ),
	     'balls', (select sum(da.balls) from data.driver_activities da where da.driver_id=d.id)
         )  
  from data.drivers d
  left join sysdata."SYS_DRIVERLEVELS" dl on dl.id=d.level_id
  where d.id=driver_id_ and 
        (d.dispatcher_id=dispatcher_id_ or coalesce(dispatcher_id_,0)=0 or coalesce(d.dispatcher_id,0)=0 ) 
  into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',dc.id,
									   'carclass_id',dc.carclass_id,
	                                   'carclass_name',cc.name,
									   'cartype_id',dc.cartype_id,
									   'cartype_name',ct.name,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active)
           FROM data.driver_cars dc
		   left join data.drivers d on dc.driver_id=d.id
           left join sysdata."SYS_CARCLASSES" cc on dc.carclass_id=cc.id
           left join sysdata."SYS_CARTYPES" ct on dc.cartype_id=ct.id
          WHERE dc.driver_id = driver_id_)) into array_cars;

select array_to_json(ARRAY( SELECT json_build_object('cost_id',ct.id,
	                                   'cost_name',ct.name,
									   'percent',coalesce(dc.percent,0))
           FROM data.cost_types ct 
           left join data.driver_costs dc on dc.cost_id=ct.id and dc.driver_id = driver_id_
		   where ct.dispatcher_id=dispatcher_id_
		   order by ct.name)		   
			) into costs;

select coalesce(encode(df.filedata,'base64'),'')
  from data.driver_docs dd
  left join data.driver_files df on df.doc_id=dd.id
  where dd.driver_id=driver_id_ and dd.doc_type=9
  LIMIT 1
  into photo; 

select api.get_balance(dispatcher_id_,driver_id_,pass_) into balance;

can_delete = true;

if exists(select 1 from data.orders o where o.driver_id = driver_id_) then
 can_delete = false;
end if; 

if can_delete and exists(select 1 from data.dispatcher_selected_drivers dsd where dsd.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.addsums ad where ad.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.feedback f where f.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.money_requests mr where mr.driver_id = driver_id_) then
 can_delete = false;
end if; 

END

$$;


ALTER FUNCTION api.get_driver(dispatcher_id_ integer, driver_id_ integer, pass_ text, OUT json_data text, OUT array_cars text, OUT balance jsonb, OUT costs text, OUT can_delete boolean, OUT photo text) OWNER TO postgres;

--
-- TOC entry 744 (class 1255 OID 16716)
-- Name: get_driver(integer, integer, text, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver(dispatcher_id_ integer, driver_id_ integer, pass_ text, code_ character varying, OUT json_data text, OUT array_cars text, OUT balance jsonb, OUT costs text, OUT contract_templates jsonb, OUT can_delete boolean, OUT photo text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается водителем или диспетчером.
Просмотр данных водителя.
*/

DECLARE ok boolean DEFAULT false;

BEGIN

if coalesce(dispatcher_id_,0)>0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
     ok = true;
   end if;
 end;
else
  begin
    if coalesce(driver_id_,0)>0 then
      begin
        if sysdata.check_id_driver(driver_id_,pass_)>0 then
          ok = true;
        end if;
       end;
	 end if;  
   end;
end if;  
  
if not ok then
 return;
end if; 
 
 select json_build_object(
		 'id',d.id,
	     'login',d.login,
	     'name',d.name,
	     'second_name',d.second_name,
	     'family_name',d.family_name,
	     'is_active',d.is_active,
	     'level_id',d.level_id,
	     'level_name',dl.name,
	     'contract_id',d.contract_id,
	 	 'restrictions',d.restrictions,
	     'dispatcher_id',d.dispatcher_id,
         'date_of_birth',d.date_of_birth,	 
	     'contact',d.contact,
	     'contact2',d.contact2,
	     'cars_count',(select count(*) from data.driver_cars dcrs where dcrs.driver_id=d.id),
	     'bank_card',d.bank_card,
	     'bank',d.bank,
	     'bik',d.bik,
	     'korrschet',d.korrschet,
	     'rasschet',d.rasschet,
	     'poluchatel',d.poluchatel,
	     'inn',d.inn,
	     'kpp',d.kpp,
	     'ogrnip',d.ogrnip,
	     'passport', (select json_build_object( 
	     				'serie',pass.doc_serie,
	     				'number',pass.doc_number,
	     				'date',pass.doc_date,	 
			            'from',pass.doc_from,	 
	     				'addresse',d.reg_addresse,
			            'reg_address_lat',d.reg_address_lat,
			            'reg_address_lon',d.reg_address_lng,
	     				'fact_addresse',d.fact_addresse,
			            'fact_address_lat',d.fact_address_lat,
			            'fact_address_lon',d.fact_address_lng
		                ) 
					   from data.driver_docs pass
					   where pass.driver_id=d.id and pass.doc_type=1
					 ),
	     'contract', (select json_build_object( 
	     				'number',contract.doc_number,
	     				'date1',contract.start_date,	 
			            'date2',contract.end_date) 
					   from data.driver_docs contract
					   where contract.driver_id=d.id and contract.doc_type=6
					 ),

	     'license', (select json_build_object( 
	     				'serie',license.doc_serie,
	     				'number',license.doc_number,
	     				'date1',license.start_date,	 
			            'date2',license.end_date) 
					   from data.driver_docs license
					   where license.driver_id=d.id and license.doc_type=10
					 ),
	     'medical', (select json_build_object( 
	     				'number',medical.doc_number,
	     				'date1',medical.start_date,	 
			            'date2',medical.end_date) 
					   from data.driver_docs medical
					   where medical.driver_id=d.id and medical.doc_type=5
					 ),
	     'insurance', (select json_build_object( 
	     				'serie',insurance.doc_serie,
	     				'number',insurance.doc_number,
	     				'date1',insurance.start_date,	 
			            'date2',insurance.end_date) 
					   from data.driver_docs insurance
					   where insurance.driver_id=d.id and insurance.doc_type=4
					 ),
	     'balls', (select sum(da.balls) from data.driver_activities da where da.driver_id=d.id)
         )  
  from data.drivers d
  left join sysdata."SYS_DRIVERLEVELS" dl on dl.id=d.level_id
  where d.id=driver_id_ and 
        (d.dispatcher_id=dispatcher_id_ or coalesce(dispatcher_id_,0)=0 or coalesce(d.dispatcher_id,0)=0 ) 
  into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',dc.id,
									   'carclass_id',dc.carclass_id,
	                                   'carclass_name',cc.name,
									   'cartype_id',dc.cartype_id,
									   'cartype_name',ct.name,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'carweight_limit',dc.weight_limit,			 
									   'carvolume_limit',dc.volume_limit,			 
									   'cartrays_limit',dc.trays_limit,			 
									   'carpallets_limit',dc.pallets_limit,			 
									   'is_active',dc.is_active)
           FROM data.driver_cars dc
		   left join data.drivers d on dc.driver_id=d.id
           left join sysdata."SYS_CARCLASSES" cc on dc.carclass_id=cc.id
           left join sysdata."SYS_CARTYPES" ct on dc.cartype_id=ct.id
          WHERE dc.driver_id = driver_id_)) into array_cars;

select array_to_json(ARRAY( SELECT json_build_object('cost_id',ct.id,
	                                   'cost_name',ct.name,
									   'percent',coalesce(dc.percent,0))
           FROM data.cost_types ct 
           left join data.driver_costs dc on dc.cost_id=ct.id and dc.driver_id = driver_id_
		   where ct.dispatcher_id=dispatcher_id_
		   order by ct.name)		   
			) into costs;

select array_to_json(ARRAY( SELECT json_build_object('id',dd.id,
	                                   'type_name',dd.type_name,
									   'name',dd.name,
									   'files',(
												select array_to_json(ARRAY( SELECT json_build_object('id',ddf.id,
	                                   																 'filename',ddf.filename,
									   																 'filepath',ddf.filepath
									                                                                 )                 
                                                FROM data.dispatcher_dogovor_files ddf 
												where ddf.dogovor_id=dd.id and right(ddf.filename,5)='.docx')		   
																	)										   
									            )
									)
           FROM api.dispatcher_view_dogovors(dispatcher_id_,pass_,code_) as dd 
		   order by dd.type_id,dd.name)		   
			) into contract_templates;

select coalesce(encode(df.filedata,'base64'),'')
  from data.driver_docs dd
  left join data.driver_files df on df.doc_id=dd.id
  where dd.driver_id=driver_id_ and dd.doc_type=9
  LIMIT 1
  into photo; 

select api.get_balance(dispatcher_id_,driver_id_,pass_) into balance;

can_delete = true;

if exists(select 1 from data.orders o where o.driver_id = driver_id_) then
 can_delete = false;
end if; 

if can_delete and exists(select 1 from data.dispatcher_selected_drivers dsd where dsd.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.addsums ad where ad.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.feedback f where f.driver_id = driver_id_) then
 can_delete = false;
end if; 
if can_delete and exists(select 1 from data.money_requests mr where mr.driver_id = driver_id_) then
 can_delete = false;
end if; 

END

$$;


ALTER FUNCTION api.get_driver(dispatcher_id_ integer, driver_id_ integer, pass_ text, code_ character varying, OUT json_data text, OUT array_cars text, OUT balance jsonb, OUT costs text, OUT contract_templates jsonb, OUT can_delete boolean, OUT photo text) OWNER TO postgres;

--
-- TOC entry 544 (class 1255 OID 16718)
-- Name: get_driver_car_file(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE photo text;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select encode(df.filedata,'base64') from data.driver_car_files df where df.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION api.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 754 (class 1255 OID 16719)
-- Name: get_driver_dogovor(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
	    dd.doc_number,
	    dd.doc_date,
	    dd.end_date,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=6
  into dog_id,
       dog_number,
	   dog_begin,
	   dog_end,
	   dog_scan;

END

$$;


ALTER FUNCTION api.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) OWNER TO postgres;

--
-- TOC entry 755 (class 1255 OID 16720)
-- Name: get_driver_file(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$DECLARE photo text;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select encode(df.filedata,'base64') from data.driver_files df where df.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION api.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 756 (class 1255 OID 16721)
-- Name: get_driver_levels(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_levels() RETURNS TABLE(id integer, name character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
/*
Вызывается кем угодно.
Просмотр всех уровней водителей.
*/
begin
return query select sl.id,sl.name from sysdata."SYS_DRIVERLEVELS" sl order by sl.id;
end
$$;


ALTER FUNCTION api.get_driver_levels() OWNER TO postgres;

--
-- TOC entry 757 (class 1255 OID 16722)
-- Name: get_driver_med(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT med_id bigint, OUT med_serie text, OUT med_number text, OUT med_begin date, OUT med_end date, OUT med_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
	    dd.doc_serie,
	    dd.doc_number,
	    dd.doc_date,
	    dd.end_date,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=5
  into med_id,
       med_serie,
	   med_number,
	   med_begin,
	   med_end,
	   med_scan;

END

$$;


ALTER FUNCTION api.get_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT med_id bigint, OUT med_serie text, OUT med_number text, OUT med_begin date, OUT med_end date, OUT med_scan text) OWNER TO postgres;

--
-- TOC entry 758 (class 1255 OID 16723)
-- Name: get_driver_passport(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
        dd.doc_serie,
	    dd.doc_number,
	    dd.doc_date,
	    dd.doc_from,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=1
  into pass_id,
       pass_serie,
	   pass_number,
	   pass_date,
	   pass_from,
	   pass_scan;

END

$$;


ALTER FUNCTION api.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) OWNER TO postgres;

--
-- TOC entry 759 (class 1255 OID 16724)
-- Name: get_driver_photo(integer, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_photo(dispatcher_id_ integer, driver_id_ integer, pass_ text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$/*
Вызывается диспетчером или водителем.
Получение фото водителя в текстовом формате.
*/

DECLARE ok boolean default false; 
DECLARE photo text default '';
BEGIN

if coalesce(dispatcher_id_,0)>0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
     ok = true;
   end if;
 end;
else
  begin
    if coalesce(driver_id_,0)>0 then
      begin
        if sysdata.check_id_driver(driver_id_,pass_)>0 then
          ok = true;
        end if;
       end;
	 end if;  
   end;
end if;  
  
if not ok then
 return '';
end if; 
 
 select coalesce(encode(df.filedata,'base64'),'')
  from data.drivers d, data.driver_docs dd, data.driver_files df
  where d.id=driver_id_ and df.doc_id=dd.id and dd.driver_id=d.id and dd.doc_type=9
  LIMIT 1
  into photo;

return photo;

END

$$;


ALTER FUNCTION api.get_driver_photo(dispatcher_id_ integer, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 760 (class 1255 OID 16725)
-- Name: get_driver_strah(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT strah_id bigint, OUT strah_serie text, OUT strah_number text, OUT strah_begin date, OUT strah_end date, OUT strah_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
	    dd.doc_serie,
	    dd.doc_number,
	    dd.doc_date,
	    dd.end_date,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=4
  into strah_id,
       strah_serie,
	   strah_number,
	   strah_begin,
	   strah_end,
	   strah_scan;

END

$$;


ALTER FUNCTION api.get_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT strah_id bigint, OUT strah_serie text, OUT strah_number text, OUT strah_begin date, OUT strah_end date, OUT strah_scan text) OWNER TO postgres;

--
-- TOC entry 761 (class 1255 OID 16726)
-- Name: get_driver_vu(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT vu_id bigint, OUT vu_serie text, OUT vu_number text, OUT vu_begin date, OUT vu_end date, OUT vu_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
	    dd.doc_serie,
	    dd.doc_number,
	    dd.doc_date,
	    dd.end_date,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=10
  into vu_id,
       vu_serie,
	   vu_number,
	   vu_begin,
	   vu_end,
	   vu_scan;

END

$$;


ALTER FUNCTION api.get_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT vu_id bigint, OUT vu_serie text, OUT vu_number text, OUT vu_begin date, OUT vu_end date, OUT vu_scan text) OWNER TO postgres;

--
-- TOC entry 762 (class 1255 OID 16727)
-- Name: get_feedback_file(integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE photo text;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select encode(ff.filedata,'base64') from data.feedback_files ff where ff.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION api.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 763 (class 1255 OID 16728)
-- Name: get_hash(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_hash() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$/*
Вспомогательная функция.
Какой должен быть хэш сегодня.
*/

declare salt text;
declare hash text;
declare secret text default 'lkjdfgroeicjdhrovmdSlfkLoPOERjn123n';

begin
salt = cast(current_date as text);
hash = salt||':'||md5(salt||secret);
return hash;
end
$$;


ALTER FUNCTION api.get_hash() OWNER TO postgres;

--
-- TOC entry 764 (class 1255 OID 16729)
-- Name: get_invoice_options(integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if disp_data then
 begin
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'bank') into bank;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'bik') into bik;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'korrschet') into korrschet;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'rasschet') into rasschet;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'platelschik') into full_name;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'inn') into inn;
  select coalesce(param_value_text,'') from api.get_option('',dispatcher_id_,pass_,1,'kpp') into kpp;
 end;
else
 begin
  select coalesce(d.bank,''),
		 coalesce(d.bik,''),
		 coalesce(d.korrschet,''),
		 coalesce(d.rasschet,''),
		 coalesce(d.poluchatel,''),
		 coalesce(d.inn,''),
		 coalesce(d.kpp,'') from data.drivers d where d.id=driver_id_
  into bank,bik,korrschet,rasschet,full_name,inn,kpp;
 end;
end if; 

END

$$;


ALTER FUNCTION api.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) OWNER TO postgres;

--
-- TOC entry 765 (class 1255 OID 16730)
-- Name: get_min_app_version(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_min_app_version() RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE res integer default 0;

BEGIN

select sp.param_value_integer from sysdata."SYS_PARAMS" sp where sp.param_name='MIN_APP_VERSION' into res;
RETURN coalesce(res,0);
END;

$$;


ALTER FUNCTION api.get_min_app_version() OWNER TO postgres;

--
-- TOC entry 766 (class 1255 OID 16731)
-- Name: get_order(integer, integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_order(dispatcher_id_ integer, driver_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT json_checkpoints text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером или водителем.
Просмотр заказа.
Если просматривает водитель, то запись о просмотре в таблицу order_views.
*/
DECLARE is_dispatcher boolean default false;
DECLARE is_driver boolean default false;
BEGIN

if coalesce(dispatcher_id_,0)>0 and sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
 is_dispatcher=true;
end if;

if not is_dispatcher and coalesce(driver_id_,0)>0 and sysdata.check_id_driver(driver_id_,pass_)>0 then
 begin
  is_driver=true;
  insert into data.order_views(id,order_id,driver_id,timeview)
  values(nextval('data.order_views_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP);
 end; 
end if;

if not is_dispatcher and not is_driver then
 return;
end if;

select json_build_object(
		 'id',o.id,
	     'order_time',o.order_time,
		 'order_title',o.order_title,
		 'point_id',o.point_id,
		 'point_name',p.name,
		 'from_time',o.from_time,
	     'from_addr_name',o.from_addr_name,
		 'from_addr_latitude',o.from_addr_latitude,
	     'from_addr_longitude',o.from_addr_longitude,
	     'summa',o.summa,
		 'dispatcher_id',o.dispatcher_id,
		 'driver_id',coalesce(o.driver_id,0),
		 'driver_full_name',coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		 'status_id',coalesce(o.status_id,0),
		 'status_name',st.name,
		 'carclass_id',coalesce(o.carclass_id,0), 
		 'carclass_name',cc.name,
		 'paytype_id',coalesce(o.paytype_id,0),
		 'paytype_name',pt.name,
		 'client_id',o.client_id,
		 'client_name',cl.name,
		 'driver_cartype_id',o.driver_cartype_id,
		 'driver_cartype_name',cc2.name||' >> '||ct.name,
		 'driver_carmodel',o.driver_carmodel,
		 'driver_carnumber',o.driver_carnumber,
		 'driver_carcolor',o.driver_carcolor,
		 'is_deleted',o.is_deleted,
		 'del_time',o.del_time,
		 'distance',o.distance,
		 'duration',o.duration,
		 'notes',o.notes,
		 'visible',o.visible)
 from data.orders o 
 left join data.client_points p on p.id=o.point_id
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join sysdata."SYS_PAYTYPES" pt on pt.id=o.paytype_id
 left join sysdata."SYS_CARCLASSES" cc on cc.id=o.carclass_id
 left join sysdata."SYS_CARTYPES" ct on ct.id=o.driver_cartype_id
 left join sysdata."SYS_CARCLASSES" cc2 on cc2.id=ct.class_id
left join data.clients cl on cl.id=o.client_id
 left join data.drivers d on d.id=o.driver_id
  where o.id=order_id_ into json_data;

select array_to_json(ARRAY( SELECT json_build_object('id',c.id,
									   'to_point_id',c.to_point_id,
									   'to_addr_name',c.to_addr_name,
									   'to_point_name',p.name,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'to_notes',c.notes,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'distance_to',c.distance_to,
									   'duration_to',c.duration_to,
									   'by_driver',c.by_driver,
									   'photos',c.photos,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
		  left join data.client_points p on p.id=c.to_point_id
          WHERE c.order_id = order_id_
		  ORDER BY c.position_in_order)) 
		  into json_checkpoints;

END

$$;


ALTER FUNCTION api.get_order(dispatcher_id_ integer, driver_id_ integer, pass_ text, order_id_ bigint, OUT json_data text, OUT json_checkpoints text) OWNER TO postgres;

--
-- TOC entry 767 (class 1255 OID 16732)
-- Name: get_order_bak(integer, integer, text, bigint); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_order_bak(dispatcher_id_ integer, driver_id_ integer, pass_ text, order_id_ bigint, OUT order_time timestamp without time zone, OUT from_addr_name_long text, OUT from_addr_name_short text, OUT from_addr_latitude real, OUT from_addr_longitude real, OUT summa numeric, OUT driver_id integer, OUT driver_name character varying, OUT dispatcher_id integer, OUT status_id integer, OUT status_name character varying, OUT carclass_id integer, OUT paytype_id integer, OUT client_id integer, OUT driver_cartype_id integer, OUT driver_carmodel text, OUT driver_carnumber text, OUT driver_carcolor text, OUT is_deleted boolean, OUT del_time timestamp without time zone, OUT distance real, OUT duration integer, OUT from_time timestamp without time zone, OUT notes text, OUT order_title text, OUT visible boolean, OUT array_checkpoints jsonb[]) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером или водителем.
Просмотр заказа.
Если просматривает водитель, то запись о просмотре в таблицу order_views.
*/
DECLARE is_dispatcher boolean default false;
DECLARE is_driver boolean default false;
BEGIN

if coalesce(dispatcher_id_,0)>0 and sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 then
 is_dispatcher=true;
end if;

if not is_dispatcher and coalesce(driver_id_,0)>0 and sysdata.check_id_driver(driver_id_,pass_)>0 then
 begin
  is_driver=true;
  insert into data.order_views(id,order_id,driver_id,timeview)
  values(nextval('data.order_views_id_seq'),order_id_,driver_id_,CURRENT_TIMESTAMP);
 end; 
end if;

if not is_dispatcher and not is_driver then
 return;
end if;

 select o.order_time,
        o.from_addr_name_long,
		o.from_addr_name_short,
		o.from_addr_latitude,
		o.from_addr_longitude,
		o.summa,
		coalesce(o.driver_id,0),
		coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,''),
		o.dispatcher_id,
		coalesce(o.status_id,0),
		st.name,
		coalesce(o.carclass_id,0), 
		coalesce(o.paytype_id,0),
		o.client_id,
		o.driver_cartype_id,
		o.driver_carmodel,
		o.driver_carnumber,
		o.driver_carcolor,
		o.is_deleted,
		o.del_time,
		o.distance,
		o.duration,
		o.from_time,
		o.notes,
		o.order_title,
		o.visible
 from data.orders o 
 left join sysdata."SYS_ORDERSTATUS" st on st.id=o.status_id
 left join data.drivers d on d.id=o.driver_id
  where o.id=order_id_ into 
        order_time,
        from_addr_name_long,
		from_addr_name_short,
		from_addr_latitude,
		from_addr_longitude,
		summa,
		driver_id,
		driver_name,
		dispatcher_id,
		status_id,
		status_name,
		carclass_id,
		paytype_id,
		client_id,
		driver_cartype_id,
		driver_carmodel,
		driver_carnumber,
		driver_carcolor,
		is_deleted,
		del_time,
		distance,
		duration,
		from_time,
		notes,
		order_title,
		visible;

select ARRAY( SELECT json_build_object('id',c.id,
									   'to_addr_name_long',c.to_addr_name_long,
									   'to_addr_name_short',c.to_addr_name_short,
									   'to_addr_latitude',c.to_addr_latitude,
									   'to_addr_longitude',c.to_addr_longitude,
									   'to_time_from',c.to_time_from,
									   'to_time_to',c.to_time_to,
									   'kontakt_name',c.kontakt_name,
									   'kontakt_phone',c.kontakt_phone,
									   'notes',c.notes,
									   'visited_status',c.visited_status,
									   'visited_time',c.visited_time,
									   'position_in_order',c.position_in_order)
           FROM data.checkpoints c
          WHERE c.order_id = order_id_) into array_checkpoints;

END

$$;


ALTER FUNCTION api.get_order_bak(dispatcher_id_ integer, driver_id_ integer, pass_ text, order_id_ bigint, OUT order_time timestamp without time zone, OUT from_addr_name_long text, OUT from_addr_name_short text, OUT from_addr_latitude real, OUT from_addr_longitude real, OUT summa numeric, OUT driver_id integer, OUT driver_name character varying, OUT dispatcher_id integer, OUT status_id integer, OUT status_name character varying, OUT carclass_id integer, OUT paytype_id integer, OUT client_id integer, OUT driver_cartype_id integer, OUT driver_carmodel text, OUT driver_carnumber text, OUT driver_carcolor text, OUT is_deleted boolean, OUT del_time timestamp without time zone, OUT distance real, OUT duration integer, OUT from_time timestamp without time zone, OUT notes text, OUT order_title text, OUT visible boolean, OUT array_checkpoints jsonb[]) OWNER TO postgres;

--
-- TOC entry 768 (class 1255 OID 16733)
-- Name: get_order_history(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_order_history(dispatcher_id_ integer, pass_ text, get_rows integer DEFAULT NULL::integer) RETURNS TABLE(id bigint, order_title character varying, point_id integer, from_name character varying, summa numeric, latitude numeric, longitude numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается диспетчером.
Просмотр истории заказов (если указано get_rows, то количество не больше get_rows).
*/
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if get_rows is null or get_rows=0 then
 begin
  RETURN QUERY  
	SELECT oh.id,	
	oh.order_title,
	oh.point_id,
	oh.from_name,
    oh.summa,
    oh.latitude,
    oh.longitude
   FROM data.order_history oh
  WHERE (oh.dispatcher_id = dispatcher_id_) order by oh.id desc;
 end;
else
 begin
  RETURN QUERY  
	SELECT oh.id,	
	oh.order_title,
	oh.point_id,
	oh.from_name,
    oh.summa,
    oh.latitude,
    oh.longitude
   FROM data.order_history oh
  WHERE (oh.dispatcher_id = dispatcher_id_) order by oh.id desc limit get_rows;
 end;
end if; 
 
END

$$;


ALTER FUNCTION api.get_order_history(dispatcher_id_ integer, pass_ text, get_rows integer) OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 16734)
-- Name: SYS_PAYTYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_PAYTYPES" (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE sysdata."SYS_PAYTYPES" OWNER TO postgres;

--
-- TOC entry 769 (class 1255 OID 16737)
-- Name: get_pay_types(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_pay_types() RETURNS SETOF sysdata."SYS_PAYTYPES"
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

select 
 pt.id,
 pt.name
 from sysdata."SYS_PAYTYPES" pt
 order by pt.id;

$$;


ALTER FUNCTION api.get_pay_types() OWNER TO postgres;

--
-- TOC entry 770 (class 1255 OID 16738)
-- Name: get_route_condition_types(character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_route_condition_types(code_ character varying) RETURNS TABLE(id integer, name text, value_type_id integer, value_type_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр видов условий для маршрута.
*/
BEGIN

  RETURN QUERY  
    select 
     rct.id,
     rc1.name,
	 rct.value_type_id,
     rc2.name
     from sysdata."SYS_ROUTE_CONDITION_TYPES" rct
	 left join sysdata."SYS_RESOURCES" rc1 on rc1.resource_id=rct.resource_id and rc1.country_code=code_
	 left join sysdata."SYS_CONDITION_VALUE_TYPES" cvt ON cvt.id = rct.value_type_id
	 left join sysdata."SYS_RESOURCES" rc2 on rc2.resource_id=cvt.resource_id and rc2.country_code=code_
     order by rct.id; 
END

$$;


ALTER FUNCTION api.get_route_condition_types(code_ character varying) OWNER TO postgres;

--
-- TOC entry 771 (class 1255 OID 16739)
-- Name: get_routecalc_types(character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_routecalc_types(code_ character varying) RETURNS TABLE(id integer, name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр типов калькуляции маршрутов.
*/
BEGIN

  RETURN QUERY  
    select 
     rct.id,
     rc.name
     from sysdata."SYS_ROUTECALC_TYPES" rct
	 left join sysdata."SYS_RESOURCES" rc on rc.resource_id=rct.resource_id and rc.country_code=code_
     order by rct.id; 
END

$$;


ALTER FUNCTION api.get_routecalc_types(code_ character varying) OWNER TO postgres;

--
-- TOC entry 772 (class 1255 OID 16740)
-- Name: get_routerestrictions(character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_routerestrictions(code_ character varying) RETURNS TABLE(id integer, name_for_route text, name_for_driver text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр ограничений маршрутов.
*/
BEGIN

  RETURN QUERY  
    select 
     rr.id,
     rc1.name,
	 rc2.name
     from sysdata."SYS_ROUTERESTRICTIONS" rr
	 left join sysdata."SYS_RESOURCES" rc1 on rc1.resource_id=rr.route_resource_id and rc1.country_code=code_
	 left join sysdata."SYS_RESOURCES" rc2 on rc2.resource_id=rr.driver_resource_id and rc2.country_code=code_
     order by rr.id; 
END

$$;


ALTER FUNCTION api.get_routerestrictions(code_ character varying) OWNER TO postgres;

--
-- TOC entry 773 (class 1255 OID 16741)
-- Name: get_routetypes(character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_routetypes(code_ character varying) RETURNS TABLE(id integer, name text, difficulty numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр типов маршрутов.
*/
BEGIN

  RETURN QUERY  
    select 
     rt.id,
     rc.name,
	 rt.difficulty
     from sysdata."SYS_ROUTETYPES" rt
	 left join sysdata."SYS_RESOURCES" rc on rc.resource_id=rt.resource_id and rc.country_code=code_
     order by rt.id; 
END

$$;


ALTER FUNCTION api.get_routetypes(code_ character varying) OWNER TO postgres;

--
-- TOC entry 774 (class 1255 OID 16742)
-- Name: get_statuses(); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_statuses() RETURNS TABLE(id integer, name character varying, name_for_driver character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается кем угодно.
Просмотр статусов заказов.
*/
BEGIN

  RETURN QUERY  
    select 
     st.id,
     st.name,
	 st.name_for_driver
     from sysdata."SYS_ORDERSTATUS" st
     order by st.id; 
END

$$;


ALTER FUNCTION api.get_statuses() OWNER TO postgres;

--
-- TOC entry 775 (class 1255 OID 16743)
-- Name: get_win_app_params(text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.get_win_app_params(hash text, OUT server_name text, OUT server_port text, OUT win_app_login text, OUT win_app_pass text, OUT win_app_min_version real, OUT win_app_ava_version real, OUT win_app_link text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$BEGIN

if not sysdata.check_signing(hash) then
 return;
end if;

 server_name = '46.229.212.155';
 server_port = '5432';
 win_app_login = 'win_app_user';
 win_app_pass ='dxDhTils74o3247n6';
 win_app_min_version = 0.66;
 win_app_ava_version = 0.71;
 win_app_link = 'ftp://46.229.212.155/files/update_dc_071.exe';

END

$$;


ALTER FUNCTION api.get_win_app_params(hash text, OUT server_name text, OUT server_port text, OUT win_app_login text, OUT win_app_pass text, OUT win_app_min_version real, OUT win_app_ava_version real, OUT win_app_link text) OWNER TO postgres;

--
-- TOC entry 776 (class 1255 OID 16744)
-- Name: not_exec_order_dispatcher(bigint, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.not_exec_order_dispatcher(order_id_ bigint, dispatcher_id_ integer, pass_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка сброс статуса выполненного заказа. Заказ становится в работе.
Только свои заказы.
*/ 
DECLARE order_id BIGINT;
DECLARE dispatcher_id INT;
DECLARE curr_status_id INT;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

  SELECT o.id,o.dispatcher_id,coalesce(o.status_id,0) FROM data.orders o 
  where o.id=order_id_ FOR UPDATE
  into order_id,dispatcher_id,curr_status_id;

  IF order_id is null or curr_status_id<>2 or dispatcher_id<>dispatcher_id_ THEN
	 return false;
  ELSE
    BEGIN
     UPDATE data.orders set status_id=1
						where id=order_id_;
	 insert into data.order_not_exec_dispatchers(id,order_id,dispatcher_id,not_exec_order) 
	                          values(nextval('data.order_not_exec_dispatchers_id_seq'),order_id_,dispatcher_id_,CURRENT_TIMESTAMP);
     return true;
	END;
  END IF;  

END

$$;


ALTER FUNCTION api.not_exec_order_dispatcher(order_id_ bigint, dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 777 (class 1255 OID 16745)
-- Name: set_client_pass(integer, text, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_client_pass(dispatcher_id_ integer, pass_ text, client_id_ integer, client_pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Установка пароля клиента. (Потом надо поменять, чтб не кждый диспетчер мог это делать)
Возврат id или -1.
*/
DECLARE client_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.clients
   set pass=client_pass_ 
   where id=client_id_
   returning id into client_id;

RETURN client_id;
END

$$;


ALTER FUNCTION api.set_client_pass(dispatcher_id_ integer, pass_ text, client_id_ integer, client_pass_ text) OWNER TO postgres;

--
-- TOC entry 778 (class 1255 OID 16746)
-- Name: set_dispatcher_pass(integer, text, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_dispatcher_pass(dispatcher_id_ integer, pass_ text, dispatcher_pass_ text, edit_id_ integer DEFAULT '-1'::integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Установка своего пароля.
Возврат id или -1.
*/
DECLARE dispatcher_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if edit_id_=-1 then
 edit_id_ = dispatcher_id_;
end if; 
  
  update data.dispatchers
   set pass=dispatcher_pass_ 
   where id=edit_id_
   returning id into dispatcher_id;
  
RETURN dispatcher_id;
END

$$;


ALTER FUNCTION api.set_dispatcher_pass(dispatcher_id_ integer, pass_ text, dispatcher_pass_ text, edit_id_ integer) OWNER TO postgres;

--
-- TOC entry 779 (class 1255 OID 16747)
-- Name: set_driver_activity(integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_activity(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка активности водителя.
Возврат id или -1.
*/
DECLARE driver_id integer DEFAULT 0;

BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.drivers set is_active=driver_is_active_ 
  where id=driver_id_ and dispatcher_id=dispatcher_id_ 
  returning id into driver_id;

RETURN coalesce(driver_id,0);
END

$$;


ALTER FUNCTION api.set_driver_activity(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 780 (class 1255 OID 16748)
-- Name: set_driver_birthdate(integer, text, integer, date); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_birthdate(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_date_of_birth_ date) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка дата рождения водителя.
Возврат id или -1.
*/
DECLARE driver_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.drivers
   set date_of_birth=driver_date_of_birth_ 
   where id=driver_id_ and dispatcher_id=dispatcher_id_ 
   returning id into driver_id;

RETURN driver_id;
END

$$;


ALTER FUNCTION api.set_driver_birthdate(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_date_of_birth_ date) OWNER TO postgres;

--
-- TOC entry 781 (class 1255 OID 16749)
-- Name: set_driver_car_activity(integer, text, integer, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_car_activity(dispatcher_id_ integer, pass_ text, car_id_ integer, car_is_active_ boolean) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Установка активности машины водителя.
Возврат id или -1.
*/
DECLARE car_id integer DEFAULT 0;

BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.driver_cars set is_active=car_is_active_ 
  where id=car_id_
  returning id into car_id;

RETURN coalesce(car_id,0);
END

$$;


ALTER FUNCTION api.set_driver_car_activity(dispatcher_id_ integer, pass_ text, car_id_ integer, car_is_active_ boolean) OWNER TO postgres;

--
-- TOC entry 782 (class 1255 OID 16750)
-- Name: set_driver_contacts(integer, text, integer, text, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_contacts(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_contact_ text, driver_contact2_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка контактов водителя.
Возврат id или -1.
*/
DECLARE driver_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.drivers
   set contact=driver_contact_,contact2=driver_contact2_
   where id=driver_id_ and dispatcher_id=dispatcher_id_ 
   returning id into driver_id;

RETURN driver_id;
END

$$;


ALTER FUNCTION api.set_driver_contacts(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_contact_ text, driver_contact2_ text) OWNER TO postgres;

--
-- TOC entry 783 (class 1255 OID 16751)
-- Name: set_driver_dogovor(integer, text, integer, bigint, text, date, date, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ text, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ text, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ text, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ text, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE dog_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if dog_id_>0 then
 begin
  update data.driver_docs set doc_number=dog_number,
				   doc_date=dog_begin,
				   end_date=dog_end
	where id=dog_id_ and driver_id=driver_id_ and doc_type=6
	returning id into dog_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,6,dog_number,dog_begin,dog_end)
	 returning id into dog_id;
end if;	 

    delete from data.driver_files ddf where ddf.doc_id=dog_id 
	 and ddf.id<>dog_file_id1_ and ddf.id<>dog_file_id2_ and ddf.id<>dog_file_id3_ and ddf.id<>dog_file_id4_ and ddf.id<>dog_file_id5_;

     if coalesce(dog_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name1_,decode(dog_file_data1_,'base64'));		 
     end if; 
     if coalesce(dog_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name2_,decode(dog_file_data2_,'base64'));		 
     end if; 
     if coalesce(dog_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name3_,decode(dog_file_data3_,'base64'));		 
     end if; 
     if coalesce(dog_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name4_,decode(dog_file_data4_,'base64'));		 
     end if; 
     if coalesce(dog_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name5_,decode(dog_file_data5_,'base64'));		 
     end if; 

return true;

end

$$;


ALTER FUNCTION api.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ text, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ text, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ text, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ text, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ text) OWNER TO postgres;

--
-- TOC entry 784 (class 1255 OID 16752)
-- Name: set_driver_level(integer, text, integer, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_level(dispatcher_id_ integer, pass_ text, driver_id_ integer, level_id_ integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка уровня водителя.
Возврат id или -1.
*/
DECLARE driver_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.drivers set level_id=level_id_ 
 where id=driver_id_ and dispatcher_id=dispatcher_id_ 
 returning id into driver_id;

RETURN driver_id;
END

$$;


ALTER FUNCTION api.set_driver_level(dispatcher_id_ integer, pass_ text, driver_id_ integer, level_id_ integer) OWNER TO postgres;

--
-- TOC entry 785 (class 1255 OID 16753)
-- Name: set_driver_med(integer, text, integer, bigint, text, text, date, date, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, med_id_ bigint, med_serie text, med_number text, med_begin date, med_end date, med_file_id1_ bigint, med_file_name1_ character varying, med_file_data1_ text, med_file_id2_ bigint, med_file_name2_ character varying, med_file_data2_ text, med_file_id3_ bigint, med_file_name3_ character varying, med_file_data3_ text, med_file_id4_ bigint, med_file_name4_ character varying, med_file_data4_ text, med_file_id5_ bigint, med_file_name5_ character varying, med_file_data5_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE med_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if med_id_>0 then
 begin
  update data.driver_docs set doc_serie=med_serie,
                   doc_number=med_number,
				   doc_date=med_begin,
				   end_date=med_end
	where id=med_id_ and driver_id=driver_id_ and doc_type=5
	returning id into med_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,5,med_serie,med_number,med_begin,med_end)
	 returning id into med_id;
end if;	 

    delete from data.driver_files ddf where ddf.doc_id=med_id 
	 and ddf.id<>med_file_id1_ and ddf.id<>med_file_id2_ and ddf.id<>med_file_id3_ and ddf.id<>med_file_id4_ and ddf.id<>med_file_id5_;

     if coalesce(med_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),med_id,med_file_name1_,decode(med_file_data1_,'base64'));		 
     end if; 
     if coalesce(med_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),med_id,med_file_name2_,decode(med_file_data2_,'base64'));		 
     end if; 
     if coalesce(med_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),med_id,med_file_name3_,decode(med_file_data3_,'base64'));		 
     end if; 
     if coalesce(med_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),med_id,med_file_name4_,decode(med_file_data4_,'base64'));		 
     end if; 
     if coalesce(med_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),med_id,med_file_name5_,decode(med_file_data5_,'base64'));		 
     end if; 

return true;

end

$$;


ALTER FUNCTION api.set_driver_med(dispatcher_id_ integer, pass_ text, driver_id_ integer, med_id_ bigint, med_serie text, med_number text, med_begin date, med_end date, med_file_id1_ bigint, med_file_name1_ character varying, med_file_data1_ text, med_file_id2_ bigint, med_file_name2_ character varying, med_file_data2_ text, med_file_id3_ bigint, med_file_name3_ character varying, med_file_data3_ text, med_file_id4_ bigint, med_file_name4_ character varying, med_file_data4_ text, med_file_id5_ bigint, med_file_name5_ character varying, med_file_data5_ text) OWNER TO postgres;

--
-- TOC entry 786 (class 1255 OID 16754)
-- Name: set_driver_pass(integer, text, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_pass(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_pass_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка пароля водителя.
Возврат id или -1.
*/
DECLARE driver_id integer DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.drivers
   set pass=driver_pass_ 
   where id=driver_id_ and dispatcher_id=dispatcher_id_ 
   returning id into driver_id;

RETURN driver_id;
END

$$;


ALTER FUNCTION api.set_driver_pass(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_pass_ text) OWNER TO postgres;

--
-- TOC entry 788 (class 1255 OID 16755)
-- Name: set_driver_passport(integer, text, integer, bigint, text, text, date, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, character varying, character varying); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ text, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ text, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ text, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ text, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ text, reg_addresse_ character varying DEFAULT ''::character varying, fact_addresse_ character varying DEFAULT ''::character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE pass_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

update data.drivers set reg_addresse=replace(reg_addresse_,'&quot;','"'),
                        fact_addresse=replace(fact_addresse_,'&quot;','"')
						where id=driver_id_;
						
if pass_id_>0 then
 begin
  update data.driver_docs set doc_serie=pass_serie,
				   doc_number=pass_number,
				   doc_date=pass_date,
				   doc_from=replace(pass_from,'&quot;','"')
	where id=pass_id_ and driver_id=driver_id_ and doc_type=1
	returning id into pass_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,doc_from)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,1,pass_serie,pass_number,pass_date,replace(pass_from,'&quot;','"'))
	 returning id into pass_id;
end if;	 

    delete from data.driver_files ddf where ddf.doc_id=pass_id 
	 and ddf.id<>pass_file_id1_ and ddf.id<>pass_file_id2_ and ddf.id<>pass_file_id3_ and ddf.id<>pass_file_id4_ and ddf.id<>pass_file_id5_;

     if coalesce(pass_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name1_,decode(pass_file_data1_,'base64'));		 
     end if; 
     if coalesce(pass_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name2_,decode(pass_file_data2_,'base64'));		 
     end if; 
     if coalesce(pass_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name3_,decode(pass_file_data3_,'base64'));		 
     end if; 
     if coalesce(pass_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name4_,decode(pass_file_data4_,'base64'));		 
     end if; 
     if coalesce(pass_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name5_,decode(pass_file_data5_,'base64'));		 
     end if; 

return true;

end

$$;


ALTER FUNCTION api.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ text, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ text, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ text, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ text, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ text, reg_addresse_ character varying, fact_addresse_ character varying) OWNER TO postgres;

--
-- TOC entry 789 (class 1255 OID 16756)
-- Name: set_driver_photo(integer, text, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_photo(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_photo_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$/*
Вызывается диспетчером или водителем.
Установка фото водителя.
Возврат id или -1.
*/
DECLARE driver_doc_id bigint DEFAULT 0;
DECLARE driver_file_id bigint DEFAULT 0;
BEGIN 

if coalesce(dispatcher_id_,0)>0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return -1;
   end if;
 end;
else
 begin
   if sysdata.check_id_driver(driver_id_,pass_)<1 then
    return -1;
   end if;
  end; 
end if;

if driver_photo_='' then
 begin
  delete from data.driver_docs where doc_type=9 and driver_id=driver_id_;
  return driver_id_;
 end;
end if;

select coalesce(dd.id,0) from data.driver_docs dd 
 where dd.doc_type=9 and driver_id=driver_id_
 LIMIT 1
 into driver_doc_id;
 
if driver_doc_id>0 then
 begin
   select coalesce(df.id,0) from data.driver_files df 
     where df.doc_id=driver_doc_id
     LIMIT 1
     into driver_file_id;
	 
	 if driver_file_id>0 then/*нужно обновлять*/
	   update data.driver_files set filedata=decode(driver_photo_,'base64') 
	       where id=driver_file_id;
	 else /*нужно нового заводить*/	   
	   insert into data.driver_files (id,doc_id,filedata) 
	              values (nextval('data.driver_files_id_seq'),driver_doc_id,decode(driver_photo_,'base64'));
	 end if;
	 
 end;
else
  begin
     insert into data.driver_docs (id,doc_type,driver_id) 
         values(nextval('data.driver_docs_id_seq'),9,driver_id_)
		 returning id into driver_doc_id;
	 insert into data.driver_files (id,doc_id,filedata) 
	              values (nextval('data.driver_files_id_seq'),driver_doc_id,decode(driver_photo_,'base64')); 
  end;	 
end if;

return driver_id_;
   
END

$$;


ALTER FUNCTION api.set_driver_photo(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_photo_ text) OWNER TO postgres;

--
-- TOC entry 790 (class 1255 OID 16757)
-- Name: set_driver_strah(integer, text, integer, bigint, text, text, date, date, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text, bigint, character varying, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, strah_id_ bigint, strah_serie text, strah_number text, strah_begin date, strah_end date, strah_file_id1_ bigint, strah_file_name1_ character varying, strah_file_data1_ text, strah_file_id2_ bigint, strah_file_name2_ character varying, strah_file_data2_ text, strah_file_id3_ bigint, strah_file_name3_ character varying, strah_file_data3_ text, strah_file_id4_ bigint, strah_file_name4_ character varying, strah_file_data4_ text, strah_file_id5_ bigint, strah_file_name5_ character varying, strah_file_data5_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE strah_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if strah_id_>0 then
 begin
  update data.driver_docs set doc_serie=strah_serie,
                   doc_number=strah_number,
				   doc_date=strah_begin,
				   end_date=strah_end
	where id=strah_id_ and driver_id=driver_id_ and doc_type=4
	returning id into strah_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,4,strah_serie,strah_number,strah_begin,strah_end)
	 returning id into strah_id;
end if;	 

    delete from data.driver_files ddf where ddf.doc_id=strah_id 
	 and ddf.id<>strah_file_id1_ and ddf.id<>strah_file_id2_ and ddf.id<>strah_file_id3_ and ddf.id<>strah_file_id4_ and ddf.id<>strah_file_id5_;

     if coalesce(strah_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),strah_id,strah_file_name1_,decode(strah_file_data1_,'base64'));		 
     end if; 
     if coalesce(strah_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),strah_id,strah_file_name2_,decode(strah_file_data2_,'base64'));		 
     end if; 
     if coalesce(strah_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),strah_id,strah_file_name3_,decode(strah_file_data3_,'base64'));		 
     end if; 
     if coalesce(strah_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),strah_id,strah_file_name4_,decode(strah_file_data4_,'base64'));		 
     end if; 
     if coalesce(strah_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),strah_id,strah_file_name5_,decode(strah_file_data5_,'base64'));		 
     end if; 

return true;

end

$$;


ALTER FUNCTION api.set_driver_strah(dispatcher_id_ integer, pass_ text, driver_id_ integer, strah_id_ bigint, strah_serie text, strah_number text, strah_begin date, strah_end date, strah_file_id1_ bigint, strah_file_name1_ character varying, strah_file_data1_ text, strah_file_id2_ bigint, strah_file_name2_ character varying, strah_file_data2_ text, strah_file_id3_ bigint, strah_file_name3_ character varying, strah_file_data3_ text, strah_file_id4_ bigint, strah_file_name4_ character varying, strah_file_data4_ text, strah_file_id5_ bigint, strah_file_name5_ character varying, strah_file_data5_ text) OWNER TO postgres;

--
-- TOC entry 791 (class 1255 OID 16758)
-- Name: set_driver_vu(integer, text, integer, bigint, text, text, date, date, bigint, character varying, text, bigint, character varying, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, vu_id_ bigint, vu_serie text, vu_number text, vu_begin date, vu_end date, vu_file_id1_ bigint, vu_file_name1_ character varying, vu_file_data1_ text, vu_file_id2_ bigint, vu_file_name2_ character varying, vu_file_data2_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE vu_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if vu_id_>0 then
 begin
  update data.driver_docs set doc_serie=vu_serie,
                   doc_number=vu_number,
				   doc_date=vu_begin,
				   end_date=vu_end
	where id=vu_id_ and driver_id=driver_id_ and doc_type=10
	returning id into vu_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,10,vu_serie,vu_number,vu_begin,vu_end)
	 returning id into vu_id;
end if;	 

    delete from data.driver_files ddf where ddf.doc_id=vu_id 
	 and ddf.id<>vu_file_id1_ and ddf.id<>vu_file_id2_;

     if coalesce(vu_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),vu_id,vu_file_name1_,decode(vu_file_data1_,'base64'));		 
     end if; 
     if coalesce(vu_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),vu_id,vu_file_name2_,decode(vu_file_data2_,'base64'));		 
     end if; 

return true;

end

$$;


ALTER FUNCTION api.set_driver_vu(dispatcher_id_ integer, pass_ text, driver_id_ integer, vu_id_ bigint, vu_serie text, vu_number text, vu_begin date, vu_end date, vu_file_id1_ bigint, vu_file_name1_ character varying, vu_file_data1_ text, vu_file_id2_ bigint, vu_file_name2_ character varying, vu_file_data2_ text) OWNER TO postgres;

--
-- TOC entry 792 (class 1255 OID 16759)
-- Name: set_order_visibility(integer, text, bigint, boolean); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.set_order_visibility(dispatcher_id integer, pass_ text, order_id_ bigint, visibility_ boolean) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
/*
Вызывается диспетчером.
Установка видимости заказа.
Возврат id или -1.
*/
DECLARE order_id BIGINT DEFAULT 0;
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

update data.orders
      set visible=visibility_ 
	  where id=order_id_ and dispatcher_id=dispatcher_id_ 
	  returning id into order_id;

RETURN order_id;
END

$$;


ALTER FUNCTION api.set_order_visibility(dispatcher_id integer, pass_ text, order_id_ bigint, visibility_ boolean) OWNER TO postgres;

--
-- TOC entry 793 (class 1255 OID 16760)
-- Name: test_dispatcher_view_orders(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.test_dispatcher_view_orders(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id bigint, order_time timestamp without time zone, from_time timestamp without time zone, point_id integer, from_addr_name character varying, from_addr_latitude numeric, from_addr_longitude numeric, summa numeric, status_id integer, status_name character varying, driver_id integer, driver_name text, dispatcher_id integer, carclass_id integer, carclass_name character varying, paytype_id integer, paytype_name character varying, distance real, duration integer, notes character varying, order_title character varying, client_id integer, client_name character varying, selected bigint, favorite boolean, dfo_id bigint, first_offer_time timestamp without time zone, offers json)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

/*
Вызывается диспетчером.
Просмотр всех заказов по диспетчеру.
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 RETURN QUERY  
	SELECT o.id,
	o.order_time,
	o.from_time,
    o.point_id,
    o.from_addr_name,
    o.from_addr_latitude,
    o.from_addr_longitude,
    o.summa,
    COALESCE(o.status_id, 0) AS status_id,
	sts.name,			  
    o.driver_id,
    coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as driver_name,				  
    o.dispatcher_id,
	o.carclass_id,
	coalesce(cc.name,'Любой'),
	o.paytype_id,
	coalesce(pt.name,'Любой'),
	o.distance,
	o.duration,
	o.notes,
	o.order_title,
	o.client_id,
	cl.name,
	dso.id,
	coalesce(dfo.favorite,false),
	coalesce(dfo.id,0),
	o.first_offer_time,	
	array_to_json(ARRAY( SELECT json_build_object('dsd_id',dsd.id,
									'driver_id',dsd.driver_id,
									'driver_name',dsdd.family_name||' '||dsdd.name||' '||dsdd.second_name,
								    'driver_first_name',dsdd.name,
									'driver_second_name',dsdd.second_name,
									'driver_family_name',dsdd.family_name,
									'offer_time',dsd.datetime/*,
									'first_view',(select min(ov.timeview::timestamp(0)) from data.order_views ov where ov.order_id=o.id and ov.driver_id=dsd.driver_id),
									'reject',(select min(orj.reject_order::timestamp(0)) from data.orders_rejecting orj where orj.order_id=o.id and orj.driver_id=dsd.driver_id)															 
												  */
								    )
           FROM data.dispatcher_selected_drivers dsd
		   left join data.drivers dsdd on dsdd.id=dsd.driver_id
          WHERE dsd.selected_id = dso.id
		  order by dsdd.family_name,dsdd.name,dsdd.second_name))
		  
   FROM data.orders o
   LEFT JOIN data.dispatcher_selected_orders dso ON dso.order_id=o.id and dso.dispatcher_id=dispatcher_id_ and dso.is_active
   LEFT JOIN data.dispatcher_favorite_orders dfo ON dfo.order_id=o.id and dfo.dispatcher_id=dispatcher_id_
   LEFT JOIN data.drivers d ON d.id=o.driver_id			  
   LEFT JOIN data.clients cl ON cl.id=o.client_id
   LEFT JOIN sysdata."SYS_ORDERSTATUS" sts ON sts.id=coalesce(o.status_id,0)
   LEFT JOIN sysdata."SYS_CARCLASSES" cc ON cc.id=o.carclass_id
   LEFT JOIN sysdata."SYS_PAYTYPES" pt ON pt.id=o.paytype_id
  WHERE sysdata.order4dispatcher(o.id, dispatcher_id_);
  
END

$$;


ALTER FUNCTION api.test_dispatcher_view_orders(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 794 (class 1255 OID 16761)
-- Name: test_func(integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.test_func(a integer) RETURNS text
    LANGUAGE plpgsql
    AS $$begin
return current_user;
end
$$;


ALTER FUNCTION api.test_func(a integer) OWNER TO postgres;

--
-- TOC entry 795 (class 1255 OID 16762)
-- Name: view_addsums(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS TABLE(id bigint, operdate timestamp without time zone, dispatcher_id integer, driver_id integer, driver_name character varying, summa_plus numeric, summa_minus numeric, commentary text, scan_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT a.id,	
	a.operdate,
    a.dispatcher_id,
    a.driver_id,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
	case when a.summa>0 then a.summa else null end,
	case when a.summa<0 then a.summa else null end,
	a.commentary,
	(select count(ad.id) from data.addsums_docs ad where ad.addsum_id=a.id)
   FROM data.addsums a 
   left join data.drivers d on d.id=a.driver_id
  WHERE (a.driver_id = coalesce(driver_id_,a.driver_id) or 1>coalesce(driver_id_,0)) and not coalesce(a.is_deleted,false)
  order by a.operdate;
 
END

$$;


ALTER FUNCTION api.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 796 (class 1255 OID 16763)
-- Name: view_balance(integer, integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.view_balance(dispatcher_id_ integer, driver_id_ integer, pass_ text) RETURNS TABLE(id bigint, doc_type text, doc_date date, summa numeric, commentary character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается диспетчером или водителем.
Просмотр детализации денежных средств.
*/
DECLARE ok boolean default false; 
DECLARE query_dispatcher_id integer default 0;


BEGIN

if coalesce(dispatcher_id_,0)>0 then
 begin
   query_dispatcher_id = dispatcher_id_;
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)>0 
     and (select d.dispatcher_id from data.drivers d where d.id=driver_id_)=dispatcher_id_ then
     ok = true;
   end if;
 end;
else
  begin    
    if coalesce(driver_id_,0)>0 then
      begin	    
        if sysdata.check_id_driver(driver_id_,pass_)>0 then
          ok = true;
        end if;
		select d.dispatcher_id from data.drivers d where d.id = driver_id_ 
		into query_dispatcher_id;
       end;
	 end if;  
   end;
end if;  
  
if not ok then
 return;
end if; 

  RETURN QUERY  
select balance.* from (
select o.id, 'O' doc_type, o.from_time::date doc_date, o.summa, o.order_title commentary from data.orders o where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_ and o.status_id>=120
 union all
/*	
select o.id, 'OC' doc_type, o.from_time::date doc_date, (select sum(oc.summa) from data.order_costs oc where oc.order_id=o.id) oc_summa, ('Обслуживание '||o.order_title) commentary from data.orders o where exists(select 1 from data.order_costs occ where occ.order_id=o.id)
 union all*/
select o.id, 'OC' doc_type, o.from_time::date doc_date, oc.summa, coalesce(ct.name,tc.name) from data.order_costs oc 
	left join data.orders o on oc.order_id=o.id 
	left join data.cost_types ct on ct.id=oc.cost_id 
	left join data.tariff_costs tc on tc.id=oc.tariff_cost_id 
    where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_
 union all
select o.id, 'OC' doc_type, o.from_time::date doc_date, oac.summa, oac.cost_name from data.order_agg_costs oac left join data.orders o on oac.order_id=o.id where o.dispatcher_id = query_dispatcher_id and o.driver_id=driver_id_
 union all
select f.id, 'F' doc_type, f.paid::date doc_date, f.summa, ('Платежный документ №'||cast(f.opernumber as character varying)||' от '||cast(f.operdate::date as character varying)||'. '||coalesce(f.commentary,'')) commentary from data.feedback f where f.dispatcher_id = query_dispatcher_id and f.driver_id=driver_id_ and not f.paid is null and not coalesce(f.is_deleted,false)
 union all
select p.id, 'P' doc_type, p.operdate::date doc_date, p.summa, p.commentary commentary from data.addsums p where p.dispatcher_id = query_dispatcher_id and p.driver_id=driver_id_ and p.summa>0 and not coalesce(p.is_deleted,false)
 union all
select m.id, 'M' doc_type, m.operdate::date doc_date, m.summa, m.commentary commentary from data.addsums m where m.dispatcher_id = query_dispatcher_id and m.driver_id=driver_id_ and m.summa<0 and not coalesce(m.is_deleted,false)
	) as balance order by 3 desc,2;
END

$$;


ALTER FUNCTION api.view_balance(dispatcher_id_ integer, driver_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 797 (class 1255 OID 16764)
-- Name: view_clients(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.view_clients(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, email character varying)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

/*
Вызывается диспетчером.
Просмотр клиентов. 
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT cl.id,
    cl.name,
    cl.email
   FROM data.clients cl
   where cl.is_active;

END

$$;


ALTER FUNCTION api.view_clients(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 798 (class 1255 OID 16765)
-- Name: view_dispatchers(integer, text); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.view_dispatchers(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, full_name character varying, login character varying, is_active boolean, is_admin boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается диспетчером с админскими правами.
Просмотр диспетчеров. 
*/

DECLARE can_admin boolean default false;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

select d.is_admin from data.dispatchers d where d.id=dispatcher_id_ into can_admin;
if not coalesce(can_admin,false) then
 return;
end if; 

  RETURN QUERY  
	SELECT d.id,
    d.name,
	d.second_name,
	d.family_name,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
    d.login,
    d.is_active,
    d.is_admin    
   FROM data.dispatchers d;
END

$$;


ALTER FUNCTION api.view_dispatchers(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 799 (class 1255 OID 16766)
-- Name: view_drivers(integer, text, integer); Type: FUNCTION; Schema: api; Owner: postgres
--

CREATE FUNCTION api.view_drivers(dispatcher_id_ integer, pass_ text, level_id_ integer DEFAULT NULL::integer) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, full_name character varying, login character varying, level_id integer, level_name character varying, is_active boolean, date_of_birth date, full_age double precision, contact text, contact2 text, bank text, bik text, korrschet text, rasschet text, poluchatel text, inn text, kpp text, reg_addresse character varying, fact_addresse character varying, dispatcher_id integer, balance jsonb, driver_cars json[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$/*
Вызывается диспетчером.
Просмотр водителей (с балансами). 
Если указан уровень, то только этого уровня.
Если уровень==-1, то с дополнительной записью id=0, name="<..Любой водитель..>"
*/

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if coalesce(level_id_,0)>0 then
  RETURN QUERY  
	SELECT d.id,
    d.name,
	d.second_name,
	d.family_name,
	cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
    d.login,
	d.level_id,
    dl.name AS level_name,
    d.is_active,
    d.date_of_birth,
    date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
    d.contact,
	d.contact2,
	d.bank,
	d.bik,
	d.korrschet,
	d.rasschet,
	d.poluchatel,
	d.inn,
	d.kpp,
	d.reg_addresse,
	d.fact_addresse,
    d.dispatcher_id,
	(select api.get_balance(dispatcher_id_,d.id,pass_)),
	(select ARRAY( SELECT json_build_object('id',dc.id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active))
           FROM data.driver_cars dc
          WHERE dc.driver_id = d.id)
   FROM data.drivers d
   LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
   WHERE d.dispatcher_id=dispatcher_id_ and d.level_id=level_id_;
else 
	begin
	  if level_id_=-1 then
        RETURN QUERY  
	      SELECT 0,
          '<..Любой водитель..>',
	      null,
	      null,
	      '<..Любой водитель..>',
          null,
	      null,
          null,
          true,
          null,
          null,
          null,
	      null,
	      null,
	      null,
	      null,
	      null,
	      null,
	      null,
	      null,
		  null,
		  null,
          dispatcher_id_,
	      null,
	      null
		   union all	  
	      SELECT d.id,
          d.name,
	      d.second_name,
	      d.family_name,
	      cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
          d.login,
	      d.level_id,
          dl.name AS level_name,
          d.is_active,
          d.date_of_birth,
          date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
          d.contact,
	      d.contact2,
	      d.bank,
	      d.bik,
	      d.korrschet,
	      d.rasschet,
	      d.poluchatel,
	      d.inn,
	      d.kpp,
		  d.reg_addresse,
		  d.fact_addresse,
          d.dispatcher_id,
	      (select api.get_balance(dispatcher_id_,d.id,pass_)),
	      (select ARRAY( SELECT json_build_object('id',dc.id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active)
                 FROM data.driver_cars dc
                WHERE dc.driver_id = d.id))
         FROM data.drivers d
         LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
         WHERE d.dispatcher_id=dispatcher_id_;			  
	  else			  
        RETURN QUERY  
	      SELECT d.id,
          d.name,
	      d.second_name,
	      d.family_name,
	      cast(coalesce(d.family_name,'')||' '||coalesce(d.name,'')||' '||coalesce(d.second_name,'') as character varying),
          d.login,
	      d.level_id,
          dl.name AS level_name,
          d.is_active,
          d.date_of_birth,
          date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
          d.contact,
	      d.contact2,
	      d.bank,
	      d.bik,
	      d.korrschet,
	      d.rasschet,
	      d.poluchatel,
	      d.inn,
	      d.kpp,
		  d.reg_addresse,
		  d.fact_addresse,
          d.dispatcher_id,
	      (select api.get_balance(dispatcher_id_,d.id,pass_)),
	      (select ARRAY( SELECT json_build_object('id',dc.id,
									   'cartype_id',dc.cartype_id,
									   'carmodel',dc.carmodel,
									   'carnumber',dc.carnumber,
									   'carcolor',dc.carcolor,
									   'is_active',dc.is_active)
                 FROM data.driver_cars dc
                WHERE dc.driver_id = d.id))
         FROM data.drivers d
         LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
         WHERE d.dispatcher_id=dispatcher_id_;
	  end if;				
	end;					
end if; 
END

$$;


ALTER FUNCTION api.view_drivers(dispatcher_id_ integer, pass_ text, level_id_ integer) OWNER TO postgres;

--
-- TOC entry 787 (class 1255 OID 16768)
-- Name: calc_distance_koeff(real); Type: FUNCTION; Schema: assignment; Owner: postgres
--

CREATE FUNCTION assignment.calc_distance_koeff(distance_ real) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
if coalesce(distance_,0) = 0 then
 return 0;
elsif distance_ <= 10 then
 return 1;
elsif distance_ <= 20 then
 return 0.95;
elsif distance_ <= 30 then
 return 0.90;
elsif distance_ <= 40 then
 return 0.85;
elsif distance_ <= 50 then
 return 0.80;
elsif distance_ <= 60 then
 return 0.75;
elsif distance_ <= 70 then
 return 0.70;
elsif distance_ <= 80 then
 return 0.65;
elsif distance_ <= 90 then
 return 0.60;
elsif distance_ <= 100 then
 return 0.55;
elsif distance_ <= 110 then
 return 0.50;
elsif distance_ <= 120 then
 return 0.45;
elsif distance_ <= 130 then
 return 0.40;
elsif distance_ <= 140 then
 return 0.35;
elsif distance_ <= 150 then
 return 0.30;
elsif distance_ <= 160 then
 return 0.25;
elsif distance_ <= 170 then
 return 0.20;
elsif distance_ <= 180 then
 return 0.15;
elsif distance_ <= 190 then
 return 0.10;
elsif distance_ <= 200 then
 return 0.05;
else
 return 0.01;
end if; 
END
$$;


ALTER FUNCTION assignment.calc_distance_koeff(distance_ real) OWNER TO postgres;

--
-- TOC entry 800 (class 1255 OID 16769)
-- Name: calc_object_function(integer, bigint, integer); Type: FUNCTION; Schema: assignment; Owner: postgres
--

CREATE FUNCTION assignment.calc_object_function(driver_id_ integer, order_id_ bigint, route_id_ integer) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE count_value integer;
BEGIN

/* проверим, чтобы у водителя не было ограничений, которые есть на маршруте */
with cte1 as
(
select dr.value,rr.value from jsonb_array_elements((select d.restrictions from data.drivers d where d.id=driver_id_)) dr
left join jsonb_array_elements((select r.restrictions from data.routes r where r.id=route_id_)) rr on dr.value=rr.value
where rr.value is not null
)
select count(*) from cte1 into count_value;

if count_value>0 then
  return 0;
end if;

END
$$;


ALTER FUNCTION assignment.calc_object_function(driver_id_ integer, order_id_ bigint, route_id_ integer) OWNER TO postgres;

--
-- TOC entry 801 (class 1255 OID 16770)
-- Name: deny_update_login(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.deny_update_login() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN 
IF (OLD.login<>NEW.login) THEN 
    raise 'Login changing is denied!';
ELSE 
    return new;
END IF; 
END;
$$;


ALTER FUNCTION data.deny_update_login() OWNER TO postgres;

--
-- TOC entry 802 (class 1255 OID 16771)
-- Name: driver_insert_calendar_index(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.driver_insert_calendar_index() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
 NEW.calendar_index = NEW.id;
 RETURN NEW;
END; 
$$;


ALTER FUNCTION data.driver_insert_calendar_index() OWNER TO postgres;

--
-- TOC entry 803 (class 1255 OID 16772)
-- Name: driver_route_delete_assignment(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.driver_route_delete_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$BEGIN
if OLD.driver_id is not null then
  begin
	  	with last_route as 
		 (
			 select r.id,r.type_id from data.orders o 
			 left join data.routes r on r.client_id = OLD.client_id and upper(r.name) = upper(o.order_title)
			 where o.driver_id = OLD.driver_id and o.id <> OLD.id and o.from_time = (select max(oo.from_time) from data.orders oo where oo.id <> OLD.id and oo.driver_id=OLD.driver_id)
			 limit 1
		 )
		  insert into assignment.driver_last_route (id, driver_id, route_id, routetype_id)
		   select nextval('assignment.driver_last_route_id_seq'),OLD.driver_id,lr.id,lr.type_id from last_route lr 
		   where lr.id is not null
		   on conflict (driver_id) do update set (route_id, routetype_id) = (select id,type_id from last_route limit 1);
  end;
end if;  

return OLD;
END;
$$;


ALTER FUNCTION data.driver_route_delete_assignment() OWNER TO postgres;

--
-- TOC entry 804 (class 1255 OID 16773)
-- Name: driver_route_update_assignment(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.driver_route_update_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$BEGIN
if (coalesce(OLD.driver_id,0) <> coalesce(NEW.driver_id,0)) and (NEW.driver_id is not null or OLD.driver_id is not null) then
  begin
  	if OLD.driver_id is not null then
	  begin
	  	with last_route as 
		 (
			 select r.id,r.type_id from data.orders o 
			 left join data.routes r on r.client_id = OLD.client_id and upper(r.name) = upper(o.order_title)
			 where o.driver_id = OLD.driver_id and o.id <> NEW.id and o.from_time = (select max(oo.from_time) from data.orders oo where oo.id <> NEW.id and oo.driver_id=OLD.driver_id)
			 limit 1
		 )
		  insert into assignment.driver_last_route (id, driver_id, route_id, routetype_id)
		   select nextval('assignment.driver_last_route_id_seq'),OLD.driver_id,lr.id,lr.type_id from last_route lr 
		   where lr.id is not null
		   on conflict (driver_id) do update set (route_id, routetype_id) = (select id,type_id from last_route limit 1);
	  end;
	end if;  
  	if NEW.driver_id is not null then
	  begin
	  	with new_route as 
		 (
			 select r.id,r.type_id from data.routes r
			 where r.client_id = NEW.client_id and upper(r.name) = upper(NEW.order_title)
			 limit 1
		 )
		  insert into assignment.driver_last_route (id, driver_id, route_id, routetype_id)
		   select nextval('assignment.driver_last_route_id_seq'),NEW.driver_id,nr.id,nr.type_id from new_route nr 
		   where nr.id is not null
		   on conflict (driver_id) do update set (route_id, routetype_id) = (select id,type_id from new_route limit 1);
	  end;
	end if;  
  end;
end if;  

return NEW;
END;
$$;


ALTER FUNCTION data.driver_route_update_assignment() OWNER TO postgres;

--
-- TOC entry 805 (class 1255 OID 16774)
-- Name: driver_update_assignment(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.driver_update_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$BEGIN
delete from assignment.distance_for_load where driver_id = NEW.id;
if NEW.fact_address_lat is not null and NEW.fact_address_lng is not null then
  begin
	with need_orders as
	 (
		 select dso.order_id,o.from_addr_latitude,o.from_addr_longitude,o.status_id from data.dispatcher_selected_orders dso
		 left join data.orders o on o.id=dso.order_id
		 where dso.dispatcher_id=NEW.dispatcher_id and coalesce(dso.is_active,true) and o.status_id=30
	 )
	insert into assignment.distance_for_load(id,order_id,driver_id,koeff)
	 select nextval('assignment.distance_for_load_id_seq'),o.order_id,NEW.id,assignment.calc_distance_koeff(sysdata.get_distance(o.from_addr_latitude,o.from_addr_longitude,NEW.fact_address_lat,NEW.fact_address_lng))
	  from need_orders o
	  on conflict do nothing;
  end;
end if;  
return NEW;
END;$$;


ALTER FUNCTION data.driver_update_assignment() OWNER TO postgres;

--
-- TOC entry 806 (class 1255 OID 16775)
-- Name: dso_update_assignment(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.dso_update_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE load_lat numeric default null;
DECLARE load_lng numeric default null;
BEGIN
delete from assignment.distance_for_load where order_id = NEW.order_id;

if coalesce(NEW.is_active, true) then
  begin
	
	select o.from_addr_latitude,o.from_addr_longitude from data.orders o where o.id = NEW.order_id and o.status_id = 30
	into load_lat,load_lng;

	if load_lat is not null and load_lng is not null then
	  begin
		with need_drivers as
		 (
			 select d.id,d.fact_address_lat,d.fact_address_lng from data.drivers d
			 where d.fact_address_lat is not null and d.fact_address_lng is not null and d.dispatcher_id = NEW.dispatcher_id
		 )
		insert into assignment.distance_for_load(id,order_id,driver_id,koeff)
		 select nextval('assignment.distance_for_load_id_seq'),NEW.order_id,d.id,assignment.calc_distance_koeff(sysdata.get_distance(load_lat,load_lng,d.fact_address_lat,d.fact_address_lng))
		  from need_drivers d
		  on conflict do nothing;
	  end;
	end if;
	
  end;
end if;
return NEW;
END;
$$;


ALTER FUNCTION data.dso_update_assignment() OWNER TO postgres;

--
-- TOC entry 807 (class 1255 OID 16776)
-- Name: order_update_assignment(); Type: FUNCTION; Schema: data; Owner: postgres
--

CREATE FUNCTION data.order_update_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$BEGIN
delete from assignment.distance_for_load where order_id = NEW.id;
if NEW.status_id = 30 then
  begin
	with need_drivers as
	 (
		 select d.id,d.fact_address_lat,d.fact_address_lng from data.drivers d
		 where d.fact_address_lat is not null and d.fact_address_lng is not null and d.dispatcher_id in (select dso.dispatcher_id from data.dispatcher_selected_orders dso where dso.order_id=NEW.id and coalesce(dso.is_active,true) )
	 )
	insert into assignment.distance_for_load(id,order_id,driver_id,koeff)
	 select nextval('assignment.distance_for_load_id_seq'),NEW.id,d.id,assignment.calc_distance_koeff(sysdata.get_distance(NEW.from_addr_latitude,NEW.from_addr_longitude,d.fact_address_lat,d.fact_address_lng))
	  from need_drivers d
	  on conflict do nothing;
  end;
end if;
/*
if (OLD.driver_id <> NEW.driver_id) and (NEW.driver_id is not null or OLD.driver_id is not null) then
  begin
  	if OLD.driver_id is not null then
	  begin
	  	with last_route as 
		 (
			 select r.id,r.type_id from data.orders o 
			 left join data.routes r on upper(r.name) = upper(o.order_title)
			 where o.driver_id = OLD.driver_id and o.id <> NEW.id and o.from_time = (select max(oo.from_time) from data.orders oo where oo.id <> NEW.id and oo.driver_id=OLD.driver_id)
			 limit 1
		 )
		  insert into assignment.driver_last_route (id, driver_id, route_id, routetype_id)
		   select nextval('assignment.driver_last_route_id_seq'),OLD.driver_id,lr.id,lr.type_id from last_route lr 
		   where lr.id is not null
		   on conflict (driver_id) do update set (route_id, routetype_id) = (select id,type_id from last_route limit 1);
	  end;
	end if;  
  	if NEW.driver_id is not null then
	  begin
	  	with new_route as 
		 (
			 select r.id,r.type_id from data.routes r
			 where upper(r.name) = upper(NEW.order_title)
			 limit 1
		 )
		  insert into assignment.driver_last_route (id, driver_id, route_id, routetype_id)
		   select nextval('assignment.driver_last_route_id_seq'),NEW.driver_id,nr.id,nr.type_id from new_route nr 
		   where nr.id is not null
		   on conflict (driver_id) do update set (route_id, routetype_id) = (select id,type_id from new_route limit 1);
	  end;
	end if;  
  end;
end if;  
*/

return NEW;
END;
$$;


ALTER FUNCTION data.order_update_assignment() OWNER TO postgres;

--
-- TOC entry 808 (class 1255 OID 16777)
-- Name: before_delete_driver_level(); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.before_delete_driver_level() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN 
IF (OLD.id=1) THEN 
    return NULL;
ELSE 
    return old;
END IF; 
END;
$$;


ALTER FUNCTION sysdata.before_delete_driver_level() OWNER TO postgres;

--
-- TOC entry 809 (class 1255 OID 16778)
-- Name: before_update_driver_level(); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.before_update_driver_level() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN 
IF (OLD.id=1 and NEW.id<>1) THEN 
    return NULL;
ELSE 
    return new;
END IF; 
END;

$$;


ALTER FUNCTION sysdata.before_update_driver_level() OWNER TO postgres;

--
-- TOC entry 839 (class 1255 OID 16779)
-- Name: calc_costs(bigint, integer, integer); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.calc_costs(order_id_ bigint, driver_id_ integer, driver_car_id_ integer, OUT agg_cost numeric, OUT all_costs numeric) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE order_summa NUMERIC;
DECLARE order_driver_id INT;
DECLARE order_car_id INT;
DECLARE order_status_id INT;
DECLARE order_carclass_id INT;

DECLARE from_date date;
DECLARE lat numeric;
DECLARE lng numeric;

BEGIN

--если 0, то по умолчанию
if driver_car_id_ = 0 then
  select dc.id from data.driver_cars dc where dc.is_default and dc.driver_id = driver_id_
   into driver_car_id_;
end if;

--raise 'car = %',driver_car_id_;

--если не указаны водитель и машина, достать из записи
SELECT coalesce(driver_id_,o.driver_id),coalesce(o.status_id,0),o.summa,o.from_time::date,o.from_addr_latitude,o.from_addr_longitude,coalesce(driver_car_id_,(o.driver_car_attribs->>'car_id')::int),o.carclass_id
  FROM data.orders o 
   where o.id=order_id_
   into order_driver_id,order_status_id,order_summa,from_date,lat,lng,order_car_id,order_carclass_id;

if (order_status_id > 30 and order_status_id < 120)
  or EXISTS(select 1 from data.orders_rejecting orj where orj.order_id=order_id_ and orj.driver_id=order_driver_id)
  or EXISTS(select 1 from data.orders_canceling ocl where ocl.order_id=order_id_ and ocl.driver_id=order_driver_id)
then
 begin
  agg_cost = (select round(cc.stavka*order_summa/100.) from aggregator_api.calc_commission(from_date,lat,lng) cc);
  all_costs = coalesce((select sum(round(dc.percent*(order_summa-agg_cost)/100.))
	   from data.driver_costs dc where dc.driver_id=order_driver_id and dc.percent<>0),0);
/*	
  all_costs	= all_costs + coalesce((select sum(round(tc.percent*(order_summa-agg_cost)/100.)) 
  		from data.tariff_costs tc
		left join data.tariffs t on tc.tariff_id=t.id
		left join data.driver_cars dc on dc.tariff_id=t.id
		where dc.id=order_car_id and dc.driver_id=order_driver_id 
		and coalesce(t.begin_date,from_date)>=from_date and coalesce(t.end_date,from_date)<=from_date),0);
*/
  
  all_costs	= all_costs + coalesce((select sum(round(tc.percent*(order_summa-agg_cost)/100.)) 
		from data.tariff_costs tc									
		left join data.tariffs t on t.id=tc.tariff_id
		left join data.driver_car_tariffs dct on dct.tariff_id=tc.tariff_id
		left join data.driver_cars dc on dc.id=dct.driver_car_id
		where dc.id=order_car_id and dc.driver_id=order_driver_id 
		and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date),0);
		
 end;
elsif order_status_id = 30 then
 begin
  agg_cost = (select round(cc.stavka*order_summa/100.) from aggregator_api.calc_commission(from_date,lat,lng) cc);

	if coalesce(order_carclass_id,0)>0 then
	  begin
		/*
		  all_costs	= all_costs + coalesce((select sum(round(tc.percent*(order_summa-agg_cost)/100.)) from data.tariff_costs tc
				left join data.tariffs t on tc.tariff_id=t.id
				left join data.driver_cars dc on dc.tariff_id=t.id
				where dc.carclass_id=order_carclass_id and dc.driver_id=order_driver_id 
				and coalesce(t.begin_date,from_date)>=from_date and coalesce(t.end_date,from_date)<=from_date),0);
		*/			
		  with unique_car as
		  (
			  select dct.driver_car_id,dct.tariff_id 
			  from data.driver_car_tariffs dct
			  left join data.tariffs t on t.id=dct.tariff_id
			  left join data.driver_cars dc on dc.id=dct.driver_car_id
			  where dc.carclass_id=order_carclass_id and dc.driver_id=order_driver_id
			  and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date
		  )
		  select sum(round(tc.percent*(order_summa-agg_cost)/100.)) 
			from data.tariff_costs tc									
			where tc.tariff_id in (select u.tariff_id from unique_car order by u.driver_car_id limit 1)
			into all_costs;
	  end;
	else
/*	
	  all_costs	= all_costs + coalesce((select sum(round(tc.percent*(order_summa-agg_cost)/100.)) from data.tariff_costs tc
			left join data.tariffs t on tc.tariff_id=t.id
			left join data.driver_cars dc on dc.tariff_id=t.id
			where dc.is_default and dc.driver_id=order_driver_id 
			and coalesce(t.begin_date,from_date)>=from_date and coalesce(t.end_date,from_date)<=from_date),0);
*/
	  select sum(round(tc.percent*(order_summa-agg_cost)/100.)) 
			from data.tariff_costs tc									
			left join data.tariffs t on t.id=tc.tariff_id
			left join data.driver_car_tariffs dct on dct.tariff_id=tc.tariff_id
			left join data.driver_cars dc on dc.id=dct.driver_car_id
			where dc.is_default and dc.driver_id=order_driver_id 
			and coalesce(t.begin_date,from_date)<=from_date and coalesce(t.end_date,from_date)>=from_date
			into all_costs;

	end if;	

	all_costs = coalesce(all_costs,0) + coalesce((select sum(round(dc.percent*(order_summa-agg_cost)/100.))
	   from data.driver_costs dc where dc.driver_id=order_driver_id and dc.percent<>0),0);


 end;
else 
 begin
   agg_cost = coalesce((select sum(oac.summa) from data.order_agg_costs oac where oac.order_id = order_id_),0);
   all_costs  = coalesce((select sum(oc.summa) from data.order_costs oc where oc.order_id = order_id_),0);
 end;
end if;

END

$$;


ALTER FUNCTION sysdata.calc_costs(order_id_ bigint, driver_id_ integer, driver_car_id_ integer, OUT agg_cost numeric, OUT all_costs numeric) OWNER TO postgres;

--
-- TOC entry 810 (class 1255 OID 16780)
-- Name: check_id_client(integer, text); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.check_id_client(id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE res integer :=0;

BEGIN

select cl.id from data.clients cl 
 where cl.id=id_ and cl.password=pass_ and cl.is_active=true into res;

RETURN coalesce(res,0);
END;

$$;


ALTER FUNCTION sysdata.check_id_client(id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 811 (class 1255 OID 16781)
-- Name: check_id_dispatcher(integer, text, boolean); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.check_id_dispatcher(id_ integer, pass_ text, without_pass_ boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE res integer :=0;

BEGIN

if without_pass_ then
 select d.id from data.dispatchers d 
  where d.id=id_ and d.is_active=true into res;
else
 select d.id from data.dispatchers d 
  where d.id=id_ and d.pass=pass_ and d.is_active=true into res;
end if;

RETURN 0; --coalesce(res,0);
END;

$$;


ALTER FUNCTION sysdata.check_id_dispatcher(id_ integer, pass_ text, without_pass_ boolean) OWNER TO postgres;

--
-- TOC entry 812 (class 1255 OID 16782)
-- Name: check_id_driver(integer, text); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.check_id_driver(id_ integer, pass_ text) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE res integer :=0;

BEGIN

select d.id from data.drivers d 
 where d.id=id_ and d.pass=pass_ and d.is_active=true into res;

RETURN coalesce(res,0);
END;

$$;


ALTER FUNCTION sysdata.check_id_driver(id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 813 (class 1255 OID 16783)
-- Name: check_signing(text); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.check_signing(text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$declare salt text;
declare hash text;
declare md5hash text;
declare saltdate date;
declare secret text default 'lkjdfgroeicjdhrovmdSlfkLoPOERjn123n';

begin
salt = split_part($1,':',1);

saltdate = cast(salt as date);
if saltdate<>current_date then
 return false;
end if;

hash = split_part($1,':',2);
md5hash = md5(salt||secret);
if md5hash=hash then
 return true;
else
 return false;
end if;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

end

$_$;


ALTER FUNCTION sysdata.check_signing(text) OWNER TO postgres;

--
-- TOC entry 814 (class 1255 OID 16784)
-- Name: cron_every_hour(); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.cron_every_hour() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE day_of_week integer;
DECLARE hour_of_day integer;
DECLARE cdate date;
DECLARE ctime timestamp without time zone;
BEGIN

cdate = CURRENT_DATE;
ctime = CURRENT_TIMESTAMP;

day_of_week = extract(dow from cdate);
hour_of_day = extract(hour from ctime);

with disps as
(
	select o.dispatcher_id d_id,
	d.pass d_pass
	from data.options o
	left join data.dispatchers d on d.id=o.dispatcher_id
	where param_name='create_orders_by_schedule' and param_value_integer=1
),
settings as
(
	select d_id,
	d_pass,
	(select (param_value_json::text like '%"'||day_of_week||'"%') from data.options where dispatcher_id=d_id and param_name='days_create_orders_by_schedule') sday,
	(select (param_value_integer=hour_of_day) from data.options where dispatcher_id=d_id and param_name='time_create_orders_by_schedule') stime
	from disps
)
insert into data.autocreate_logs(id,dispatcher_id,datetime,type_id,action_result)
 select nextval('data.autocreate_logs_id_seq'),d_id,ctime,1,(select api.dispatcher_add_by_schedule(d_id, d_pass, cdate))
  from settings where sday and stime;

--insert into data.log(id,datetime,dispatcher_id,user_action)
 --select nextval('data.log_id_seq'),CURRENT_TIMESTAMP,d_id,'Выполняется создание заказов по планировщику' 
 --from settings where sday and stime;
  

END;

$$;


ALTER FUNCTION sysdata.cron_every_hour() OWNER TO postgres;

--
-- TOC entry 815 (class 1255 OID 16785)
-- Name: cron_fill_order_location(bigint, integer, bigint); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.cron_fill_order_location(order_id_ bigint, driver_id_ integer, job_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

BEGIN

if sysdata.fill_order_location(order_id_,driver_id_) then
 begin
   -- сразу удаляю задание
   if exists(select 1 from cron.job where jobid=job_id_) then
	   PERFORM cron.unschedule(job_id_) ;				  
   end if;
   return true;
 end;
end if; 

return false;

END;

$$;


ALTER FUNCTION sysdata.cron_fill_order_location(order_id_ bigint, driver_id_ integer, job_id_ bigint) OWNER TO postgres;

--
-- TOC entry 840 (class 1255 OID 16786)
-- Name: cron_reject_order(bigint, integer, bigint); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.cron_reject_order(order_id_ bigint, driver_id_ integer, job_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE curr_driver INTEGER;
DECLARE curr_status_id INTEGER DEFAULT NULL;
DECLARE curr_time TIMESTAMP WITHOUT TIME ZONE;
DECLARE reject_balls INTEGER;
DECLARE dso_id BIGINT;

BEGIN

-- сразу удаляю задание
if exists(select 1 from cron.job where jobid=job_id_) then
	PERFORM cron.unschedule(job_id_) ;				  
end if;

select o.driver_id,o.status_id from data.orders o where o.id=order_id_
into curr_driver,curr_status_id;

  if curr_driver is null or curr_driver<>driver_id_ then --только если пользователь другой (или null)
    begin
	    if not exists(select 1 from data.orders_rejecting o where o.order_id=order_id_ and o.driver_id=driver_id_) then
		  begin
		     curr_time = CURRENT_TIMESTAMP;
			 
			 select dso.id from data.dispatcher_selected_orders dso 
			 where dso.order_id=order_id_ and dso.dispatcher_id=(select d.dispatcher_id from data.drivers d where d.id=driver_id_)
  			 into dso_id;
			 
			 if not exists(select 1 from data.dispatcher_selected_drivers dsd
				where dsd.selected_id = dso_id and dsd.driver_id = driver_id_
			   ) then
				 return false;
			  end if;

             insert into data.orders_rejecting (id,order_id,driver_id,reject_order) 
	                          values(nextval('data.orders_rejecting_id_seq'),order_id_,driver_id_,curr_time);
			 
			 update data.dispatcher_selected_drivers set reject_time=curr_time::timestamp(0)
			 where selected_id=dso_id and driver_id=driver_id_;							  
			 
			 reject_balls = (select sp.param_value_integer from sysdata."SYS_PARAMS" sp 
							 where sp.param_name='ACTIVITY_CANCEL_ORDER');
			 
			 insert into data.driver_activities (id, driver_id, datetime, balls, type_id)
			 				  values(nextval('data.driver_activities_id_seq'),driver_id_,curr_time, reject_balls, 2);
			     
	         insert into data.order_log(id,order_id,driver_id,datetime,status_new,status_old,action_string)
             values (nextval('data.order_log_id_seq'),order_id_,driver_id_,curr_time,curr_status_id,curr_status_id,'Reject') 
             on conflict do nothing;
			 
			 return true;
          end;	  
		end if;	  
	end;
  end if;

  
  return false;

END;

$$;


ALTER FUNCTION sysdata.cron_reject_order(order_id_ bigint, driver_id_ integer, job_id_ bigint) OWNER TO postgres;

--
-- TOC entry 816 (class 1255 OID 16787)
-- Name: fill_order_location(bigint, integer); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.fill_order_location(order_id_ bigint, driver_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE order_device_id INT DEFAULT NULL;
DECLARE order_status_id INT DEFAULT 0;
DECLARE radius REAL DEFAULT 0;

BEGIN

select o.status_id,o.end_device_id from data.orders o where o.id=order_id_
into order_status_id, order_device_id;

if coalesce(order_status_id)<120 then
  return false;
end if;

if driver_id_ is null then
 delete from data.order_locations where order_id=order_id_;
else 
 delete from data.order_locations where order_id=order_id_ and driver_id=driver_id_;
end if; 
  
 if coalesce(order_device_id,0) > 0 then
  insert into data.order_locations (id,order_id,driver_id,datetime,latitude,longitude)  
	select nextval('data.order_locations_id_seq'),o.id,o.driver_id,dhl.loc_time,dhl.curr_latitude,dhl.curr_longitude 
	 from data.orders o
	 left join data.driver_history_locations dhl 
	 on dhl.driver_id=o.driver_id and dhl.loc_time>=o.begin_time and dhl.loc_time<=o.end_time and dhl.device_id=order_device_id
	 where o.id=order_id_;
 else	 
  insert into data.order_locations (id,order_id,driver_id,datetime,latitude,longitude)  
	select nextval('data.order_locations_id_seq'),o.id,o.driver_id,dhl.loc_time,dhl.curr_latitude,dhl.curr_longitude 
	 from data.orders o
	 left join data.driver_history_locations dhl 
	 on dhl.driver_id=o.driver_id and dhl.loc_time>=o.begin_time and dhl.loc_time<=o.end_time
	 where o.id=order_id_;
 end if;	 

-- Прописывание рейтинга по постоянности геолокации
with res_table10 as
 (
  select (1. - (EXTRACT(epoch FROM bad_interval) / EXTRACT(epoch FROM all_interval)))*100. as rating_value
   from (select sum(case when (sums.prev_datetime is not null and sums.datetime - sums.prev_datetime>'00:00:40') then sums.datetime - sums.prev_datetime else '00:00:00' end ) bad_interval,
        (select o.end_time-o.begin_time from data.orders o where o.id=order_id_) all_interval  
          from (select l.datetime, lag(l.datetime) over (order by l.datetime) as prev_datetime
                 from data.order_locations l
                 where l.order_id=order_id_
	            ) sums
	   ) res   
 )
insert into data.order_ratings (id,order_id,rating_id,rating_value)
 select nextval('data.order_ratings_id_seq'),order_id_,10,(select rating_value from res_table10)
 on conflict (order_id,rating_id) do update set rating_value=(select rating_value from res_table10);   

-- Прописывание рейтинга по отметкам и времени
with res_table20 as
 (
   select sum(case when c.visited_status and (c.prev_visited_time is null or (c.visited_time - c.prev_visited_time)>'00:10:00') then 1 else 0 end) as plus_checkpoints,
	(select count(*) from data.checkpoints where order_id=order_id_) as total_checkpoints
    from 
     (
       select c.visited_status,c.visited_time,lag(c.visited_time) over (order by c.visited_time) as prev_visited_time 
        from data.checkpoints c where c.order_id=order_id_
         order by c.visited_time  
     ) c
 )
insert into data.order_ratings (id,order_id,rating_id,rating_value)
 select nextval('data.order_ratings_id_seq'),order_id_,20,(select (case when total_checkpoints>0 then plus_checkpoints::real/total_checkpoints::real*100. else null end) from res_table20)
 on conflict (order_id,rating_id) do update set rating_value=(select (case when total_checkpoints>0 then plus_checkpoints::real/total_checkpoints::real*100. else null end) from res_table20);   

-- Прописывание рейтинга по соответствию остановок по геолокации
radius = (select param_value_real from sysdata."SYS_PARAMS" where param_name='RADIUS_TO_CHECKPOINT');
with res_table30 as
(
 select count(res.*) as plus_checkpoints,
 (select count(*) from data.checkpoints where order_id=order_id_ and visited_status) as total_checkpoints	
	from
 (
   select c.id check_id,
	   lag(c.id) over (order by c.id) as prev_id,
	   sysdata.get_distance(ds.latitude,ds.longitude,c.to_addr_latitude,c.to_addr_longitude)
   from data.driver_stops ds,data.checkpoints c 
   where ds.order_id=order_id_ and c.order_id=order_id_ and c.visited_status
   and sysdata.get_distance(ds.latitude,ds.longitude,c.to_addr_latitude,c.to_addr_longitude)<(radius/1000.)
   order by c.id
  ) res
  where res.prev_id is distinct from res.check_id
 )
insert into data.order_ratings (id,order_id,rating_id,rating_value)
 select nextval('data.order_ratings_id_seq'),order_id_,30,(select (case when total_checkpoints>0 then plus_checkpoints::real/total_checkpoints::real*100. else null end) from res_table30)
 on conflict (order_id,rating_id) do update set rating_value=(select (case when total_checkpoints>0 then plus_checkpoints::real/total_checkpoints::real*100. else null end) from res_table30);   

-- Прописывание столбца рейтинг
with rating_sum as
(
 select sum(srp.weight) summa from data.order_ratings rr 
 left join sysdata."SYS_ROUTERATING_PARAMS" srp on srp.id=rr.rating_id
 where rr.order_id = order_id_ and rr.rating_value is not null
 )
update data.orders set rating = 
 (
  select (sum(r.rating_value*srp.weight)/rs.summa)::numeric(6,2)
   		from rating_sum rs,data.order_ratings r
   		left join sysdata."SYS_ROUTERATING_PARAMS" srp on srp.id=r.rating_id
   		where r.rating_value is not null and r.order_id = order_id_
   		group by rs.summa
 )
where id = order_id_;

return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;

END

$$;


ALTER FUNCTION sysdata.fill_order_location(order_id_ bigint, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 817 (class 1255 OID 16789)
-- Name: get_distance(numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.get_distance(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) RETURNS real
    LANGUAGE plpgsql IMMUTABLE
    AS $$BEGIN

if (lat1 IS null) or (lat2 IS null) or (lng1 IS null) or (lng2 IS null) THEN
RETURN 0;
END IF;

if (lat1=lat2) and (lng1=lng2) then
 RETURN 0;
end if;
--RAISE NOTICE '%-% %-%',lat1,lng1,lat2,lng2;
RETURN 6371.000 * acos( cos(radians(lat1))*cos(radians(lat2))*cos(radians(lng1)-radians(lng2)) + sin(radians(lat1))*sin(radians(lat2)) );
END

$$;


ALTER FUNCTION sysdata.get_distance(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) OWNER TO postgres;

--
-- TOC entry 847 (class 1255 OID 16790)
-- Name: order4dispatcher(bigint, integer); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.order4dispatcher(order_id_ bigint, dispatcher_id_ integer) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$BEGIN

  if exists( 
	         select 1 from data.orders o 
	                  where o.id = order_id_ and o.status_id>=30 and not coalesce(o.is_deleted,false) and coalesce(o.visible,true) and coalesce(o.client_id,0)>0 and
	                  ( o.dispatcher_id = dispatcher_id_ or
					    (o.dispatcher_id is null and
						  ( exists(select 1 from data.dispatcher_to_client dtc where dtc.dispatcher_id=dispatcher_id_ and dtc.client_id=o.client_id)
						     or 
						    not exists(select 1 from data.dispatcher_to_client dtc where dtc.client_id=o.client_id)
						  )
						)
					  )
            )
	and not exists(
		           select 1 from data.dispatcher_selected_orders dso 
		            where dso.order_id = order_id_ and dso.dispatcher_id<>dispatcher_id_ 
		              and dso.is_active
	              )		
			then return true;
  end if;
  
  return false;

END;

$$;


ALTER FUNCTION sysdata.order4dispatcher(order_id_ bigint, dispatcher_id_ integer) OWNER TO postgres;

--
-- TOC entry 818 (class 1255 OID 16791)
-- Name: order4driver(bigint, integer, integer); Type: FUNCTION; Schema: sysdata; Owner: postgres
--

CREATE FUNCTION sysdata.order4driver(order_id_ bigint, driver_id_ integer, driver_dispatcher_id_ integer) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

  if exists( 
	         select 1 from data.orders o 
	                  where o.id = order_id_ and not coalesce(o.is_deleted,false) and coalesce(o.visible,true) and
	                  ( (coalesce(o.dispatcher_id,0) = driver_dispatcher_id_ and coalesce(o.driver_id,driver_id_)=driver_id_) or				   
					    (o.dispatcher_id is null and 
						  ( exists(select 1 from data.dispatcher_to_client dtc where dtc.dispatcher_id=driver_dispatcher_id_ and dtc.client_id=o.client_id)
						     or 
						    not exists(select 1 from data.dispatcher_to_client dtc where dtc.client_id=o.client_id)
						  )
						)
					  )
            )
			then return true;
  end if;
  
  return false;

END;

$$;


ALTER FUNCTION sysdata.order4driver(order_id_ bigint, driver_id_ integer, driver_dispatcher_id_ integer) OWNER TO postgres;

--
-- TOC entry 819 (class 1255 OID 16792)
-- Name: check_login_dispatcher(text, text, text); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.check_login_dispatcher(hash text, disp_name text, disp_pass text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE res integer :=0;

BEGIN

if not sysdata.check_signing(hash) then
 return 0;
end if;

select d.id from data.dispatchers d 
 where d.login=disp_name and d.pass=disp_pass and d.is_active=true into res;

RETURN coalesce(res,0);
END;

$$;


ALTER FUNCTION winapp.check_login_dispatcher(hash text, disp_name text, disp_pass text) OWNER TO postgres;

--
-- TOC entry 820 (class 1255 OID 16793)
-- Name: delete_addsum(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.delete_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.addsums where id=addsum_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION winapp.delete_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) OWNER TO postgres;

--
-- TOC entry 821 (class 1255 OID 16794)
-- Name: delete_driver(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.delete_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.drivers where id=driver_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION winapp.delete_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 822 (class 1255 OID 16795)
-- Name: delete_driver_car(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.delete_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.driver_cars where id=driver_car_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION winapp.delete_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) OWNER TO postgres;

--
-- TOC entry 823 (class 1255 OID 16796)
-- Name: delete_feedback(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.delete_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

DELETE FROM data.feedback where id=feedback_id_;
return true;

EXCEPTION
WHEN OTHERS THEN 
  RETURN false;
end

$$;


ALTER FUNCTION winapp.delete_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) OWNER TO postgres;

--
-- TOC entry 849 (class 1255 OID 16797)
-- Name: edit_addsum(integer, text, integer, bigint, timestamp without time zone, real, text, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.edit_addsum(dispatcher_id_ integer, pass_ text, driver_id_ integer, addsum_id_ bigint, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE fact_addsum_id bigint default 0;
DECLARE attach_doc_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(addsum_id_,0)>0 then
 begin
  update data.addsums set driver_id=driver_id_,
				   operdate=operdate_,
				   summa=summa_,
				   commentary=commentary_
	 where id=addsum_id_ and dispatcher_id=dispatcher_id_
	 returning id into fact_addsum_id;

    delete from data.addsums_docs ad
	where ad.addsum_id=fact_addsum_id and
	      (not exists (select af.id from data.addsums_files af
		           where af.doc_id=ad.id and 
				         (af.id=file_id1_ or 
				         af.id=file_id2_ or 
				         af.id=file_id3_ or 
				         af.id=file_id4_ or 
				         af.id=file_id5_) ) 
					  );
	
   end;   
  else
   insert into data.addsums(id,dispatcher_id,driver_id,operdate,summa,commentary)
     values(nextval('data.addsums_id_seq'),dispatcher_id_,driver_id_,operdate_,summa_,commentary_)
	returning id into fact_addsum_id;
  end if; 

  if coalesce(file_id1_,0)<0 then /*only new*/
   begin   
	insert into data.addsums_docs(id,addsum_id)		
			values(nextval('data.addsums_docs_id_seq'),fact_addsum_id)
			returning id into attach_doc_id;
	insert into data.addsums_files(id,doc_id,filedata,filename)		
			values(nextval('data.addsums_files_id_seq'),attach_doc_id,file_data1_,file_name1_);
   end;
  end if;			
			
  if coalesce(file_id2_,0)<0 then /*only new*/
   begin   
	insert into data.addsums_docs(id,addsum_id)		
			values(nextval('data.addsums_docs_id_seq'),fact_addsum_id)
			returning id into attach_doc_id;
	insert into data.addsums_files(id,doc_id,filedata,filename)		
			values(nextval('data.addsums_files_id_seq'),attach_doc_id,file_data2_,file_name2_);
   end;
  end if;			
  
  if coalesce(file_id3_,0)<0 then /*only new*/
   begin   
	insert into data.addsums_docs(id,addsum_id)		
			values(nextval('data.addsums_docs_id_seq'),fact_addsum_id)
			returning id into attach_doc_id;
	insert into data.addsums_files(id,doc_id,filedata,filename)		
			values(nextval('data.addsums_files_id_seq'),attach_doc_id,file_data3_,file_name3_);
   end;
  end if;			
			
  if coalesce(file_id4_,0)<0 then /*only new*/
   begin   
	insert into data.addsums_docs(id,addsum_id)		
			values(nextval('data.addsums_docs_id_seq'),fact_addsum_id)
			returning id into attach_doc_id;
	insert into data.addsums_files(id,doc_id,filedata,filename)		
			values(nextval('data.addsums_files_id_seq'),attach_doc_id,file_data4_,file_name4_);
   end;
  end if;			
			
  if coalesce(file_id5_,0)<0 then /*only new*/
   begin   
	insert into data.addsums_docs(id,addsum_id)		
			values(nextval('data.addsums_docs_id_seq'),fact_addsum_id)
			returning id into attach_doc_id;
	insert into data.addsums_files(id,doc_id,filedata,filename)		
			values(nextval('data.addsums_files_id_seq'),attach_doc_id,file_data5_,file_name5_);
   end;
  end if;			

return fact_addsum_id;

end

$$;


ALTER FUNCTION winapp.edit_addsum(dispatcher_id_ integer, pass_ text, driver_id_ integer, addsum_id_ bigint, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) OWNER TO postgres;

--
-- TOC entry 850 (class 1255 OID 16798)
-- Name: edit_driver(integer, text, integer, character varying, character varying, character varying, character varying, character varying, boolean, integer, date, text, text, bytea, text, text, text, text, text, text, text); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_photo bytea, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_inn_ text, driver_kpp_ text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE fact_driver_id integer default -1;
DECLARE driver_doc_id integer default -1;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_id_,0) > 0 then
 begin
    update data.drivers set name=driver_name_,
	               second_name=driver_second_name_,
				   family_name=driver_family_name_,
				   is_active=driver_is_active_,
				   level_id=driver_level_id_,
				   date_of_birth=driver_date_of_birth_,
				   contact=driver_contact_,
				   contact2=driver_contact2_,
				   bank=driver_bank_,
				   bik=driver_bik_,
				   korrschet=driver_korrschet_,
				   rasschet=driver_rasschet_,
				   poluchatel=driver_poluchatel_,
				   inn=driver_inn_,
				   kpp=driver_kpp_
	 where id=driver_id_ and dispatcher_id=dispatcher_id_
	 returning id into fact_driver_id;	   

     if fact_driver_id>0 then 
	  begin
	   delete from data.driver_docs where doc_type=9 and driver_id=fact_driver_id;
	  end;
	 end if;
	 
 end;
else
 begin

    insert into data.drivers (id,login,name,second_name,family_name,pass,is_active,level_id,dispatcher_id,date_of_birth,contact,contact2,bank,bik,korrschet,rasschet,poluchatel,inn,kpp)
         values (nextval('data.drivers_id_seq'),driver_login_,driver_name_,driver_second_name_,driver_family_name_,driver_pass_,driver_is_active_,driver_level_id_,dispatcher_id_,driver_date_of_birth_,driver_contact_,driver_contact2_,driver_bank_,driver_bik_,driver_korrschet_,driver_rasschet_,driver_poluchatel_,driver_inn_,driver_kpp_) 
		 returning id into fact_driver_id;
    
  end; /*new driver*/
end if;  

	if (not driver_photo is null) and (fact_driver_id>0) then		 
     begin
      insert into data.driver_docs(id,doc_type,driver_id)  
           values(nextval('data.driver_docs_id_seq'),9,fact_driver_id)
	  	   returning id into driver_doc_id;
       if driver_doc_id>0 then
	    insert into data.driver_files(id,doc_id,filedata)
	    values(nextval('data.driver_files_id_seq'),driver_doc_id,driver_photo);
	   end if;
     end; 
    end if; /*driver_id >0*/

return coalesce(fact_driver_id,-1);

end

$$;


ALTER FUNCTION winapp.edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_photo bytea, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_inn_ text, driver_kpp_ text) OWNER TO postgres;

--
-- TOC entry 851 (class 1255 OID 16799)
-- Name: edit_driver_car(integer, text, integer, integer, character varying, character varying, character varying, integer, boolean, character varying, character varying, bigint, character varying, bytea, bigint, character varying, bytea, character varying, character varying, bigint, character varying, bytea, bigint, character varying, bytea); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean, ptsserie_ character varying, ptsnumber_ character varying, pts_file_id1_ bigint, pts_file_name1_ character varying, pts_file_data1_ bytea, pts_file_id2_ bigint, pts_file_name2_ character varying, pts_file_data2_ bytea, stsserie_ character varying, stsnumber_ character varying, sts_file_id1_ bigint, sts_file_name1_ character varying, sts_file_data1_ bytea, sts_file_id2_ bigint, sts_file_name2_ character varying, sts_file_data2_ bytea) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE car_id integer default 0;
DECLARE attach_doc_id bigint default 0;
DECLARE pts_must_insert bool;
DECLARE sts_must_insert bool;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(driver_car_id_,0)>0 then
 begin
  update data.driver_cars set cartype_id=cartype_id_,
				   carmodel=carmodel_,
				   carnumber=carnumber_,
				   carcolor=carcolor_,
				   is_active=is_active
	 where id=driver_car_id_ and driver_id=driver_id_
	 returning id into car_id;

  attach_doc_id=0;
  select id from data.driver_car_docs where driver_car_id=car_id and doc_type=2 into attach_doc_id;
  if coalesce(attach_doc_id,0)>0 then
   begin
    update data.driver_car_docs set doc_serie=ptsserie_,doc_number=ptsnumber_
	where driver_car_id=car_id and doc_type=2;

    delete from data.driver_car_files where doc_id=attach_doc_id and id<>pts_file_id1_ and id<>pts_file_id2_;

     if coalesce(pts_file_id1_,0)<0 then /*only new*/
      insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,pts_file_name1_,pts_file_data1_);		 
     end if; 
     if coalesce(pts_file_id2_,0)<0 then 
      insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,pts_file_name2_,pts_file_data2_);
     end if; 

     pts_must_insert=false;

   end;   
  else
   pts_must_insert=true;
  end if; 

  attach_doc_id=0;
  select id from data.driver_car_docs where driver_car_id=car_id and doc_type=3 into attach_doc_id;
  if coalesce(attach_doc_id,0)>0 then
   begin
    update data.driver_car_docs set doc_serie=stsserie_,doc_number=stsnumber_
	where driver_car_id=car_id and doc_type=3;

    delete from data.driver_car_files where doc_id=attach_doc_id and id<>sts_file_id1_ and id<>sts_file_id2_;

     if coalesce(sts_file_id1_,0)<0 then /*only new*/
      insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,sts_file_name1_,sts_file_data1_);		 
     end if; 
     if coalesce(sts_file_id2_,0)<0 then 
      insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,sts_file_name2_,sts_file_data2_);
     end if; 

     sts_must_insert=false;

   end;   
  else
   sts_must_insert=true;
  end if; 

	 
 end;
else /*new car*/
 begin 
  insert into data.driver_cars (id,driver_id,cartype_id,carmodel,carnumber,carcolor,is_active)
         values (nextval('data.driver_cars_id_seq'),driver_id_,cartype_id_,carmodel_,carnumber_,carcolor_,is_active_) 
		 returning id into car_id;
 end; 
end if;

if pts_must_insert then
 begin
  insert into data.driver_car_docs (id,driver_car_id,doc_type,doc_serie,doc_number)
         values (nextval('data.driver_car_docs_id_seq'),car_id,2,ptsserie_,ptsnumber_)		 
		 returning id into attach_doc_id;
  
  if not pts_file_id1_ is null then
   insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,pts_file_name1_,pts_file_data1_);		 
  end if; 
  if not pts_file_id2_ is null then 
   insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,pts_file_name2_,pts_file_data2_);
  end if; 
  
 end;
end if; /*pts_must_insert*/ 

if sts_must_insert then
 begin
  insert into data.driver_car_docs (id,driver_car_id,doc_type,doc_serie,doc_number)
         values (nextval('data.driver_car_docs_id_seq'),car_id,3,stsserie_,stsnumber_)		 
		 returning id into attach_doc_id;
  
  if not sts_file_id1_ is null then
   insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,sts_file_name1_,sts_file_data1_);		 
  end if; 
  if not sts_file_id2_ is null then 
   insert into data.driver_car_files (id,doc_id,filename,filedata) values (nextval('data.driver_car_files_id_seq'),attach_doc_id,sts_file_name2_,sts_file_data2_);
  end if; 
  
 end;
end if; /*sts_must_insert*/ 



return car_id;

end

$$;


ALTER FUNCTION winapp.edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean, ptsserie_ character varying, ptsnumber_ character varying, pts_file_id1_ bigint, pts_file_name1_ character varying, pts_file_data1_ bytea, pts_file_id2_ bigint, pts_file_name2_ character varying, pts_file_data2_ bytea, stsserie_ character varying, stsnumber_ character varying, sts_file_id1_ bigint, sts_file_name1_ character varying, sts_file_data1_ bytea, sts_file_id2_ bigint, sts_file_name2_ character varying, sts_file_data2_ bytea) OWNER TO postgres;

--
-- TOC entry 852 (class 1255 OID 16800)
-- Name: edit_feedback(integer, text, integer, bigint, integer, timestamp without time zone, real, text, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.edit_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer, feedback_id_ bigint, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$DECLARE fact_feedback_id bigint default 0;
DECLARE attach_doc_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return -1;
end if;

if coalesce(feedback_id_,0)>0 then
 begin
  update data.feedback set driver_id=driver_id_,
				   opernumber=opernumber_,
				   operdate=operdate_,
				   summa=summa_,
				   commentary=commentary_
	 where id=feedback_id_ and dispatcher_id=dispatcher_id_
	 returning id into fact_feedback_id;

    delete from data.feedback_docs fd
	where fd.feedback_id=fact_feedback_id and
	      (not exists (select ff.id from data.feedback_files ff
		           where ff.doc_id=fd.id and 
				         (ff.id=file_id1_ or 
				         ff.id=file_id2_ or 
				         ff.id=file_id3_ or 
				         ff.id=file_id4_ or 
				         ff.id=file_id5_) ) 
					  );
	
   end;   
  else
   insert into data.feedback(id,dispatcher_id,driver_id,opernumber,operdate,summa,commentary)
     values(nextval('data.feedback_id_seq'),dispatcher_id_,driver_id_,opernumber_,operdate_,summa_,commentary_)
	returning id into fact_feedback_id;
  end if; 

  if coalesce(file_id1_,0)<0 then /*only new*/
   begin   
	insert into data.feedback_docs(id,feedback_id)		
			values(nextval('data.feedback_docs_id_seq'),fact_feedback_id)
			returning id into attach_doc_id;
	insert into data.feedback_files(id,doc_id,filedata,filename)		
			values(nextval('data.feedback_files_id_seq'),attach_doc_id,file_data1_,file_name1_);
   end;
  end if;			
			
  if coalesce(file_id2_,0)<0 then /*only new*/
   begin   
	insert into data.feedback_docs(id,feedback_id)		
			values(nextval('data.feedback_docs_id_seq'),fact_feedback_id)
			returning id into attach_doc_id;
	insert into data.feedback_files(id,doc_id,filedata,filename)		
			values(nextval('data.feedback_files_id_seq'),attach_doc_id,file_data2_,file_name2_);
   end;
  end if;			
  
  if coalesce(file_id3_,0)<0 then /*only new*/
   begin   
	insert into data.feedback_docs(id,feedback_id)		
			values(nextval('data.feedback_docs_id_seq'),fact_feedback_id)
			returning id into attach_doc_id;
	insert into data.feedback_files(id,doc_id,filedata,filename)		
			values(nextval('data.feedback_files_id_seq'),attach_doc_id,file_data3_,file_name3_);
   end;
  end if;			
			
  
  if coalesce(file_id4_,0)<0 then /*only new*/
   begin   
	insert into data.feedback_docs(id,feedback_id)		
			values(nextval('data.feedback_docs_id_seq'),fact_feedback_id)
			returning id into attach_doc_id;
	insert into data.feedback_files(id,doc_id,filedata,filename)		
			values(nextval('data.feedback_files_id_seq'),attach_doc_id,file_data4_,file_name4_);
   end;
  end if;			
			
  
  if coalesce(file_id5_,0)<0 then /*only new*/
   begin   
	insert into data.feedback_docs(id,feedback_id)		
			values(nextval('data.feedback_docs_id_seq'),fact_feedback_id)
			returning id into attach_doc_id;
	insert into data.feedback_files(id,doc_id,filedata,filename)		
			values(nextval('data.feedback_files_id_seq'),attach_doc_id,file_data5_,file_name5_);
   end;
  end if;			
			

return fact_feedback_id;

end

$$;


ALTER FUNCTION winapp.edit_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer, feedback_id_ bigint, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) OWNER TO postgres;

--
-- TOC entry 825 (class 1255 OID 16801)
-- Name: get_addsums_file(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS bytea
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE photo bytea;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select af.filedata from data.addsums_files af where af.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION winapp.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 826 (class 1255 OID 16802)
-- Name: get_addsums_files(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_addsums_files(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE scan text default '';
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return '';
end if;

 select cast(ARRAY(select xmlforest(af.id,af.filename) from data.addsums_files af 
				                                  left join data.addsums_docs ad on ad.id=af.doc_id
				                                           where ad.addsum_id=addsum_id_) as text)
 into scan;

return scan;

END

$$;


ALTER FUNCTION winapp.get_addsums_files(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 16803)
-- Name: SYS_CARTYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_CARTYPES" (
    id integer NOT NULL,
    name character varying(255),
    class_id integer
);


ALTER TABLE sysdata."SYS_CARTYPES" OWNER TO postgres;

--
-- TOC entry 824 (class 1255 OID 16806)
-- Name: get_car_types(); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_car_types() RETURNS SETOF sysdata."SYS_CARTYPES"
    LANGUAGE sql SECURITY DEFINER
    AS $$
select 
 st.id,
 sc.name||'::'||st.name,
 st.class_id
 from sysdata."SYS_CARTYPES" st
 left join sysdata."SYS_CARCLASSES" sc
 on st.class_id=sc.id
 order by st.id;

$$;


ALTER FUNCTION winapp.get_car_types() OWNER TO postgres;

--
-- TOC entry 853 (class 1255 OID 16807)
-- Name: get_driver(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT name text, OUT login text, OUT birthday date, OUT contact text, OUT contact2 text, OUT is_active boolean, OUT level_id integer, OUT level_name text, OUT photo bytea, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT poluchatel text, OUT inn text, OUT kpp text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select d.name,
	    d.login,
	    d.date_of_birth,
	    d.contact,
	    d.contact2,
	    d.is_active,
	    d.level_id,
		dl.name,
	    df.filedata,
		d.bank,
		d.bik,
		d.korrschet,
		d.rasschet,
		d.poluchatel,
		d.inn,
		d.kpp
 from data.drivers d 
 left join sysdata."SYS_DRIVERLEVELS" dl on dl.id=d.level_id
 left join data.driver_docs dd on dd.driver_id=d.id and dd.doc_type=9
 left join data.driver_files df on df.doc_id=dd.id
 where d.id=driver_id_ and d.dispatcher_id=dispatcher_id_
  into name,
	login,
	birthday,
	contact,
	contact2,
	is_active,
	level_id,
	level_name,
	photo,
	bank,
	bik,
	korrschet,
	rasschet,
	poluchatel,
	inn,
	kpp;

END

$$;


ALTER FUNCTION winapp.get_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT name text, OUT login text, OUT birthday date, OUT contact text, OUT contact2 text, OUT is_active boolean, OUT level_id integer, OUT level_name text, OUT photo bytea, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT poluchatel text, OUT inn text, OUT kpp text) OWNER TO postgres;

--
-- TOC entry 827 (class 1255 OID 16808)
-- Name: get_driver_car(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT carmodel text, OUT carnumber text, OUT carcolor text, OUT cartype_id integer, OUT is_active boolean, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dc.carmodel,
	    dc.carnumber,
	    dc.carcolor,
	    dc.cartype_id,
	    dc.is_active,
	    pts.doc_serie,
	    pts.doc_number,
		cast(ARRAY( SELECT xmlforest(dcf.id,dcf.filename) 
			 from data.driver_car_files dcf where dcf.doc_id=pts.id) as text),
/*		cast(ARRAY( SELECT json_build_object('id',dcf.id,'filename',dcf.filename) 
				   from data.driver_car_files dcf where dcf.doc_id=pts.id) as text),*/
	    sts.doc_serie,
	    sts.doc_number,
		cast(ARRAY( SELECT xmlforest(dcf.id,dcf.filename) 
			 from data.driver_car_files dcf where dcf.doc_id=sts.id) as text)
		/*cast(ARRAY( SELECT json_build_object('id',dcf.id,'filename',dcf.filename) 
				   from data.driver_car_files dcf where dcf.doc_id=sts.id) as text)
 	      array(select dcf.id from data.driver_car_files where dcf.doc_id=sts.id)		*/
 from data.driver_cars dc
 left join data.drivers dd on dc.driver_id=dd.id
 left join data.driver_car_docs pts on pts.driver_car_id=dc.id and pts.doc_type=2
 left join data.driver_car_docs sts on sts.driver_car_id=dc.id and sts.doc_type=3
 where dc.id=driver_car_id_ and dd.dispatcher_id=dispatcher_id_
  into carmodel,
	   carnumber,
	   carcolor,
	   cartype_id,
	   is_active,
	   ptsnumber,
	   ptsserie,
	   ptsscan,
	   stsnumber,
	   stsserie,
   	   stsscan;

END

$$;


ALTER FUNCTION winapp.get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT carmodel text, OUT carnumber text, OUT carcolor text, OUT cartype_id integer, OUT is_active boolean, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) OWNER TO postgres;

--
-- TOC entry 854 (class 1255 OID 16809)
-- Name: get_driver_car_file(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS bytea
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE photo bytea;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select df.filedata from data.driver_car_files df where df.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION winapp.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 855 (class 1255 OID 16810)
-- Name: get_driver_dogovor(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
	    dd.doc_number,
	    dd.doc_date,
	    dd.end_date,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=6
  into dog_id,
       dog_number,
	   dog_begin,
	   dog_end,
	   dog_scan;

END

$$;


ALTER FUNCTION winapp.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) OWNER TO postgres;

--
-- TOC entry 856 (class 1255 OID 16811)
-- Name: get_driver_file(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS bytea
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE photo bytea;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select df.filedata from data.driver_files df where df.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION winapp.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 16812)
-- Name: SYS_DRIVERLEVELS; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_DRIVERLEVELS" (
    id integer NOT NULL,
    name character varying(80)
);


ALTER TABLE sysdata."SYS_DRIVERLEVELS" OWNER TO postgres;

--
-- TOC entry 829 (class 1255 OID 16815)
-- Name: get_driver_levels(); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_levels() RETURNS SETOF sysdata."SYS_DRIVERLEVELS"
    LANGUAGE sql SECURITY DEFINER
    AS $$select * from sysdata."SYS_DRIVERLEVELS" order by id
$$;


ALTER FUNCTION winapp.get_driver_levels() OWNER TO postgres;

--
-- TOC entry 857 (class 1255 OID 16816)
-- Name: get_driver_passport(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

 select dd.id,
        dd.doc_serie,
	    dd.doc_number,
	    dd.doc_date,
	    dd.doc_from,
		cast(ARRAY( SELECT xmlforest(df.id,df.filename) 
			 from data.driver_files df where df.doc_id=dd.id) as text)
 from data.driver_docs dd
 where dd.driver_id=driver_id_ and dd.doc_type=1
  into pass_id,
       pass_serie,
	   pass_number,
	   pass_date,
	   pass_from,
	   pass_scan;

END

$$;


ALTER FUNCTION winapp.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) OWNER TO postgres;

--
-- TOC entry 830 (class 1255 OID 16817)
-- Name: get_feedback_file(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) RETURNS bytea
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$

DECLARE photo bytea;

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return null;
end if;

 select ff.filedata from data.feedback_files ff where ff.id=file_id_ into photo;

return photo;
END

$$;


ALTER FUNCTION winapp.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) OWNER TO postgres;

--
-- TOC entry 831 (class 1255 OID 16818)
-- Name: get_feedback_files(integer, text, bigint); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_feedback_files(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$DECLARE scan text default '';
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return '';
end if;

 select cast(ARRAY(select xmlforest(ff.id,ff.filename) from data.feedback_files ff 
				                                  left join data.feedback_docs fd on fd.id=ff.doc_id
				                                           where fd.feedback_id=feedback_id_) as text)
 into scan;

/*
 raise notice '%s',(select cast(ARRAY(select xmlforest(ff.id,ff.filename) from data.feedback_files ff where ff.doc_id=fd.id) as text)
 from data.feedback_docs fd
 where fd.feedback_id=feedback_id_);
*/

return scan;

END

$$;


ALTER FUNCTION winapp.get_feedback_files(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) OWNER TO postgres;

--
-- TOC entry 858 (class 1255 OID 16819)
-- Name: get_invoice_options(integer, text, integer, boolean); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

if disp_data then
 begin
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'bank') into bank;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'bik') into bik;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'korrschet') into korrschet;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'rasschet') into rasschet;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'platelschik') into full_name;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'inn') into inn;
  select coalesce(param_value_text,'') from winapp.get_option('',dispatcher_id_,pass_,1,'kpp') into kpp;
 end;
else
 begin
  select coalesce(d.bank,''),
		 coalesce(d.bik,''),
		 coalesce(d.korrschet,''),
		 coalesce(d.rasschet,''),
		 coalesce(d.poluchatel,''),
		 coalesce(d.inn,''),
		 coalesce(d.kpp,'') from data.drivers d where d.id=driver_id_
  into bank,bik,korrschet,rasschet,full_name,inn,kpp;
 end;
end if; 

END

$$;


ALTER FUNCTION winapp.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) OWNER TO postgres;

--
-- TOC entry 828 (class 1255 OID 16820)
-- Name: get_next_opernumber(integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_next_opernumber(dispatcher_id_ integer) RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
select max(opernumber)+1 from data.feedback where dispatcher_id=dispatcher_id_;
$$;


ALTER FUNCTION winapp.get_next_opernumber(dispatcher_id_ integer) OWNER TO postgres;

--
-- TOC entry 833 (class 1255 OID 16821)
-- Name: get_option(text, integer, text, integer, text); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.get_option(hash text, dispatcher_id_ integer, pass_ text, section_id_ integer, option_name_ text, OUT param_view_name text, OUT param_value_text text, OUT param_value_integer integer, OUT param_value_real real) RETURNS record
    LANGUAGE plpgsql STABLE SECURITY DEFINER COST 10
    AS $$

BEGIN

if coalesce(dispatcher_id_,0)>0 then
 begin
   if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
    return;
   end if; 
 end;
else
 begin
   if not sysdata.check_signing(hash) then
    return;
   end if;
 end;
end if; 

 select o.param_view_name,
        o.param_value_text,
		o.param_value_integer,
		o.param_value_real 
 from data."options" o
 where o.section_id=section_id_ and o.param_name=option_name_
 into param_view_name,
	  param_value_text,
	  param_value_integer,
	  param_value_real;
 
 return;
 
END

$$;


ALTER FUNCTION winapp.get_option(hash text, dispatcher_id_ integer, pass_ text, section_id_ integer, option_name_ text, OUT param_view_name text, OUT param_value_text text, OUT param_value_integer integer, OUT param_value_real real) OWNER TO postgres;

--
-- TOC entry 832 (class 1255 OID 16822)
-- Name: set_driver_dogovor(integer, text, integer, bigint, text, date, date, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ bytea, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ bytea, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ bytea, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ bytea, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ bytea) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE dog_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if dog_id_>0 then
 begin
  update data.driver_docs set doc_number=dog_number,
				   doc_date=dog_begin,
				   end_date=dog_end
	where id=dog_id_ and driver_id=driver_id_ and doc_type=6
	returning id into dog_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_number,doc_date,end_date)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,6,dog_number,dog_begin,dog_end)
	 returning id into dog_id;
end if;	 

    delete from data.driver_files where doc_id=dog_id 
	 and id<>dog_file_id1_ and id<>dog_file_id2_ and id<>dog_file_id3_ and id<>dog_file_id4_ and id<>dog_file_id5_;

     if coalesce(dog_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name1_,dog_file_data1_);		 
     end if; 
     if coalesce(dog_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name2_,dog_file_data2_);		 
     end if; 
     if coalesce(dog_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name3_,dog_file_data3_);		 
     end if; 
     if coalesce(dog_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name4_,dog_file_data4_);		 
     end if; 
     if coalesce(dog_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),dog_id,dog_file_name5_,dog_file_data5_);		 
     end if; 

return true;

end

$$;


ALTER FUNCTION winapp.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ bytea, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ bytea, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ bytea, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ bytea, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ bytea) OWNER TO postgres;

--
-- TOC entry 859 (class 1255 OID 16823)
-- Name: set_driver_passport(integer, text, integer, bigint, text, text, date, text, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea, bigint, character varying, bytea); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ bytea, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ bytea, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ bytea, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ bytea, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ bytea) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE pass_id bigint default 0;
DECLARE attach_id bigint default 0;

begin

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

if pass_id_>0 then
 begin
  update data.driver_docs set doc_serie=pass_serie,
				   doc_number=pass_number,
				   doc_date=pass_date,
				   doc_from=pass_from
	where id=pass_id_ and driver_id=driver_id_ and doc_type=1
	returning id into pass_id;
 end; 
else
  insert into data.driver_docs (id,driver_id,doc_type,doc_serie,doc_number,doc_date,doc_from)
                         values(nextval('data.driver_docs_id_seq'),driver_id_,1,pass_serie,pass_number,pass_date,pass_from)
	 returning id into pass_id;
end if;	 

    delete from data.driver_files where doc_id=pass_id 
	 and id<>pass_file_id1_ and id<>pass_file_id2_ and id<>pass_file_id3_ and id<>pass_file_id4_ and id<>pass_file_id5_;

     if coalesce(pass_file_id1_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name1_,pass_file_data1_);		 
     end if; 
     if coalesce(pass_file_id2_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name2_,pass_file_data2_);		 
     end if; 
     if coalesce(pass_file_id3_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name3_,pass_file_data3_);		 
     end if; 
     if coalesce(pass_file_id4_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name4_,pass_file_data4_);		 
     end if; 
     if coalesce(pass_file_id5_,0)<0 then /*only new*/
      insert into data.driver_files (id,doc_id,filename,filedata) 
	  values (nextval('data.driver_files_id_seq'),pass_id,pass_file_name5_,pass_file_data5_);		 
     end if; 

return true;

end

$$;


ALTER FUNCTION winapp.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ bytea, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ bytea, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ bytea, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ bytea, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ bytea) OWNER TO postgres;

--
-- TOC entry 834 (class 1255 OID 16824)
-- Name: set_feedback_paid(integer, text, bigint, date); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.set_feedback_paid(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, date_ date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

DECLARE feedback_id bigint DEFAULT 0;
BEGIN 

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return false;
end if;

update data.feedback
   set paid=date_ 
   where id=feedback_id_ and dispatcher_id=dispatcher_id_ 
   returning id into feedback_id;

if feedback_id>0 then
 RETURN true;
else 
 RETURN false;
end if;

END

$$;


ALTER FUNCTION winapp.set_feedback_paid(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, date_ date) OWNER TO postgres;

--
-- TOC entry 836 (class 1255 OID 16825)
-- Name: view_addsums(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS TABLE(id bigint, operdate timestamp without time zone, dispatcher_id integer, driver_id integer, driver_name character varying, summa_plus numeric, summa_minus numeric, commentary text, scan_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$
BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT a.id,	
	a.operdate,
    a.dispatcher_id,
    a.driver_id,
	d.name,
	case when a.summa>0 then a.summa else null end,
	case when a.summa<0 then a.summa else null end,
	a.commentary,
	(select count(ad.id) from data.addsums_docs ad where ad.addsum_id=a.id)
   FROM data.addsums a 
   left join data.drivers d on d.id=a.driver_id
  WHERE (a.driver_id = coalesce(driver_id_,a.driver_id) or 1>coalesce(driver_id_,0)) 
  order by a.operdate;
 
END

$$;


ALTER FUNCTION winapp.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 835 (class 1255 OID 16826)
-- Name: view_drivers(integer, text); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.view_drivers(dispatcher_id_ integer, pass_ text) RETURNS TABLE(id integer, name character varying, second_name character varying, family_name character varying, login character varying, level_name character varying, is_active boolean, date_of_birth date, full_age double precision, contact text, contact2 text, cars_count bigint, dispatcher_id integer, sum_work numeric, sum_get numeric, add_plus numeric, add_minus numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT d.id,
    d.name,
	d.second_name,
	d.family_name,
    d.login,
    dl.name AS level_name,
    d.is_active,
    d.date_of_birth,
    date_part('year'::text, age(CURRENT_TIMESTAMP, d.date_of_birth::timestamp with time zone)) AS full_age,
    d.contact,
	d.contact2,
    ( SELECT count(dc.id) AS count
           FROM data.driver_cars dc
          WHERE dc.driver_id = d.id) AS cars_count,
    d.dispatcher_id,
	(select sum(summa) from data.orders o where o.driver_id=d.id and o.status_id=3) sum_work,
	(select sum(summa) from data.feedback f where f.driver_id=d.id and not f.paid is null) sum_get,
	(select sum(summa) from data.addsums a where a.driver_id=d.id and a.summa>0) add_plus,
	(select sum(summa) from data.addsums a where a.driver_id=d.id and a.summa<0) add_minus
   FROM data.drivers d
   LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON d.level_id = dl.id
   WHERE d.dispatcher_id=dispatcher_id_;
 
END

$$;


ALTER FUNCTION winapp.view_drivers(dispatcher_id_ integer, pass_ text) OWNER TO postgres;

--
-- TOC entry 837 (class 1255 OID 16827)
-- Name: view_feedback(integer, text, integer); Type: FUNCTION; Schema: winapp; Owner: postgres
--

CREATE FUNCTION winapp.view_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer) RETURNS TABLE(id bigint, opernumber integer, operdate timestamp without time zone, dispatcher_id integer, driver_id integer, driver_name character varying, summa numeric, paid_date date, commentary text, scan_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER ROWS 20
    AS $$

BEGIN

if sysdata.check_id_dispatcher(dispatcher_id_,pass_)<1 then
 return;
end if;

  RETURN QUERY  
	SELECT f.id,	
	f.opernumber,
	f.operdate,
    f.dispatcher_id,
    f.driver_id,
	d.name,
	f.summa,
    f.paid,
	f.commentary,
	(select count(fd.id) from data.feedback_docs fd where fd.feedback_id=f.id)
   FROM data.feedback f 
   left join data.drivers d on d.id=f.driver_id
  WHERE (f.driver_id = coalesce(driver_id_,f.driver_id) or 1>coalesce(driver_id_,0)) 
  order by f.operdate;
 
END

$$;


ALTER FUNCTION winapp.view_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer) OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 16828)
-- Name: google_addresses; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.google_addresses (
    id bigint NOT NULL,
    address text,
    google_original bigint,
    client_id integer,
    dispatcher_id integer
);


ALTER TABLE data.google_addresses OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 16834)
-- Name: google_originals; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.google_originals (
    id bigint NOT NULL,
    address text,
    latitude numeric(12,6),
    longitude numeric(12,6)
);


ALTER TABLE data.google_originals OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 16840)
-- Name: view_google_addresses; Type: VIEW; Schema: api; Owner: postgres
--

CREATE VIEW api.view_google_addresses WITH (security_barrier='false') AS
 SELECT google_addresses.id,
    google_addresses.address,
    google_originals.address AS google_address,
    google_originals.latitude,
    google_originals.longitude
   FROM (data.google_addresses
     LEFT JOIN data.google_originals ON ((google_addresses.google_original = google_originals.id)));


ALTER VIEW api.view_google_addresses OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 16844)
-- Name: distance_for_load; Type: TABLE; Schema: assignment; Owner: postgres
--

CREATE TABLE assignment.distance_for_load (
    id bigint NOT NULL,
    order_id bigint,
    driver_id integer,
    koeff numeric(12,6)
);


ALTER TABLE assignment.distance_for_load OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 16847)
-- Name: distance_for_load_id_seq; Type: SEQUENCE; Schema: assignment; Owner: postgres
--

CREATE SEQUENCE assignment.distance_for_load_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE assignment.distance_for_load_id_seq OWNER TO postgres;

--
-- TOC entry 4862 (class 0 OID 0)
-- Dependencies: 216
-- Name: distance_for_load_id_seq; Type: SEQUENCE OWNED BY; Schema: assignment; Owner: postgres
--

ALTER SEQUENCE assignment.distance_for_load_id_seq OWNED BY assignment.distance_for_load.id;


--
-- TOC entry 217 (class 1259 OID 16849)
-- Name: driver_last_route; Type: TABLE; Schema: assignment; Owner: postgres
--

CREATE TABLE assignment.driver_last_route (
    id bigint NOT NULL,
    driver_id integer,
    route_id integer,
    routetype_id integer
);


ALTER TABLE assignment.driver_last_route OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 16852)
-- Name: driver_last_route_id_seq; Type: SEQUENCE; Schema: assignment; Owner: postgres
--

CREATE SEQUENCE assignment.driver_last_route_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE assignment.driver_last_route_id_seq OWNER TO postgres;

--
-- TOC entry 4863 (class 0 OID 0)
-- Dependencies: 218
-- Name: driver_last_route_id_seq; Type: SEQUENCE OWNED BY; Schema: assignment; Owner: postgres
--

ALTER SEQUENCE assignment.driver_last_route_id_seq OWNED BY assignment.driver_last_route.id;


--
-- TOC entry 219 (class 1259 OID 16854)
-- Name: addsums; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.addsums (
    id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    driver_id integer NOT NULL,
    summa numeric(15,2),
    commentary text,
    operdate timestamp without time zone,
    is_deleted boolean,
    del_time timestamp without time zone
);


ALTER TABLE data.addsums OWNER TO postgres;

--
-- TOC entry 4864 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE addsums; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.addsums IS 'Премии и штрафы водителю';


--
-- TOC entry 220 (class 1259 OID 16860)
-- Name: addsums_docs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.addsums_docs (
    id bigint NOT NULL,
    addsum_id bigint NOT NULL
);


ALTER TABLE data.addsums_docs OWNER TO postgres;

--
-- TOC entry 4865 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE addsums_docs; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.addsums_docs IS 'Прикрепленные документы (заголовки) по премиям и штрафам';


--
-- TOC entry 221 (class 1259 OID 16863)
-- Name: addsums_docs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.addsums_docs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.addsums_docs_id_seq OWNER TO postgres;

--
-- TOC entry 4866 (class 0 OID 0)
-- Dependencies: 221
-- Name: addsums_docs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.addsums_docs_id_seq OWNED BY data.addsums_docs.id;


--
-- TOC entry 222 (class 1259 OID 16865)
-- Name: addsums_files_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.addsums_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.addsums_files_id_seq OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16867)
-- Name: addsums_files; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.addsums_files (
    id bigint DEFAULT nextval('data.addsums_files_id_seq'::regclass) NOT NULL,
    doc_id bigint NOT NULL,
    filedata bytea,
    filename text,
    filepath text,
    filesize bigint
);


ALTER TABLE data.addsums_files OWNER TO postgres;

--
-- TOC entry 4867 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE addsums_files; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.addsums_files IS 'Прикрепленные документы по премиям и штрафам';


--
-- TOC entry 224 (class 1259 OID 16874)
-- Name: addsums_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.addsums_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.addsums_id_seq OWNER TO postgres;

--
-- TOC entry 4868 (class 0 OID 0)
-- Dependencies: 224
-- Name: addsums_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.addsums_id_seq OWNED BY data.addsums.id;


--
-- TOC entry 225 (class 1259 OID 16876)
-- Name: agg_commission; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.agg_commission (
    id integer NOT NULL,
    begin_date date,
    percent numeric(6,2),
    description text,
    name text
);


ALTER TABLE data.agg_commission OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16882)
-- Name: agg_commission_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.agg_commission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.agg_commission_id_seq OWNER TO postgres;

--
-- TOC entry 4869 (class 0 OID 0)
-- Dependencies: 226
-- Name: agg_commission_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.agg_commission_id_seq OWNED BY data.agg_commission.id;


--
-- TOC entry 227 (class 1259 OID 16884)
-- Name: agg_regions; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.agg_regions (
    id integer NOT NULL,
    name text,
    region polygon,
    koeff numeric(9,3),
    description text,
    is_active boolean DEFAULT true
);


ALTER TABLE data.agg_regions OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16891)
-- Name: agg_regions_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.agg_regions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.agg_regions_id_seq OWNER TO postgres;

--
-- TOC entry 4870 (class 0 OID 0)
-- Dependencies: 228
-- Name: agg_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.agg_regions_id_seq OWNED BY data.agg_regions.id;


--
-- TOC entry 229 (class 1259 OID 16893)
-- Name: autocreate_logs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.autocreate_logs (
    id bigint NOT NULL,
    dispatcher_id integer,
    datetime timestamp without time zone,
    type_id integer,
    action_result jsonb
);


ALTER TABLE data.autocreate_logs OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16899)
-- Name: autocreate_logs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.autocreate_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.autocreate_logs_id_seq OWNER TO postgres;

--
-- TOC entry 4871 (class 0 OID 0)
-- Dependencies: 230
-- Name: autocreate_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.autocreate_logs_id_seq OWNED BY data.autocreate_logs.id;


--
-- TOC entry 231 (class 1259 OID 16901)
-- Name: calendar; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.calendar (
    id bigint NOT NULL,
    dispatcher_id integer,
    driver_id integer,
    route_id integer,
    daytype_id integer,
    cdate date
);


ALTER TABLE data.calendar OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16904)
-- Name: calendar_final; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.calendar_final (
    id bigint NOT NULL,
    dispatcher_id integer,
    driver_id integer,
    route_id integer,
    daytype_id integer,
    cdate date
);


ALTER TABLE data.calendar_final OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16907)
-- Name: calendar_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.calendar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.calendar_id_seq OWNER TO postgres;

--
-- TOC entry 4872 (class 0 OID 0)
-- Dependencies: 233
-- Name: calendar_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.calendar_id_seq OWNED BY data.calendar.id;


--
-- TOC entry 234 (class 1259 OID 16909)
-- Name: calendar_notifications; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.calendar_notifications (
    id bigint NOT NULL,
    driver_id integer,
    event_date date,
    notify_id bigint
);


ALTER TABLE data.calendar_notifications OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16912)
-- Name: calendar_notifications_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.calendar_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.calendar_notifications_id_seq OWNER TO postgres;

--
-- TOC entry 4873 (class 0 OID 0)
-- Dependencies: 235
-- Name: calendar_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.calendar_notifications_id_seq OWNED BY data.calendar_notifications.id;


--
-- TOC entry 236 (class 1259 OID 16914)
-- Name: calendar_notifications_notification_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.calendar_notifications_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.calendar_notifications_notification_id_seq OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16916)
-- Name: checkpoint_history; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.checkpoint_history (
    id bigint NOT NULL,
    name character varying(1024),
    latitude numeric(12,6),
    longitude numeric(12,6),
    kontakt_name character varying(256),
    kontakt_phone character varying(80),
    notes character varying(1024),
    client_id integer NOT NULL,
    point_id integer
);


ALTER TABLE data.checkpoint_history OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16922)
-- Name: checkpoint_history_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.checkpoint_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.checkpoint_history_id_seq OWNER TO postgres;

--
-- TOC entry 4874 (class 0 OID 0)
-- Dependencies: 238
-- Name: checkpoint_history_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.checkpoint_history_id_seq OWNED BY data.checkpoint_history.id;


--
-- TOC entry 239 (class 1259 OID 16924)
-- Name: checkpoints; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.checkpoints (
    id bigint NOT NULL,
    order_id bigint,
    to_addr_name character varying(1024),
    to_addr_latitude numeric(12,6),
    to_addr_longitude numeric(12,6),
    kontakt_name character varying(256),
    kontakt_phone character varying(80),
    notes character varying(1024),
    visited_status boolean,
    visited_time timestamp without time zone,
    position_in_order integer,
    to_time_to timestamp without time zone,
    distance_to real,
    duration_to integer,
    to_point_id integer,
    by_driver boolean,
    photos jsonb,
    accepted boolean
);


ALTER TABLE data.checkpoints OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16930)
-- Name: checkpoints_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.checkpoints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.checkpoints_id_seq OWNER TO postgres;

--
-- TOC entry 4875 (class 0 OID 0)
-- Dependencies: 240
-- Name: checkpoints_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.checkpoints_id_seq OWNED BY data.checkpoints.id;


--
-- TOC entry 241 (class 1259 OID 16932)
-- Name: client_point_coordinates; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.client_point_coordinates (
    id bigint NOT NULL,
    point_id integer NOT NULL,
    latitude numeric(12,6),
    longitude numeric(12,6)
);


ALTER TABLE data.client_point_coordinates OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 16935)
-- Name: client_point_coordinates_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.client_point_coordinates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.client_point_coordinates_id_seq OWNER TO postgres;

--
-- TOC entry 4876 (class 0 OID 0)
-- Dependencies: 242
-- Name: client_point_coordinates_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.client_point_coordinates_id_seq OWNED BY data.client_point_coordinates.id;


--
-- TOC entry 243 (class 1259 OID 16937)
-- Name: client_point_groups; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.client_point_groups (
    id integer NOT NULL,
    dispatcher_id integer,
    name text,
    code character varying(20),
    description text
);


ALTER TABLE data.client_point_groups OWNER TO postgres;

--
-- TOC entry 4877 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN client_point_groups.code; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.client_point_groups.code IS 'Код группы - генерится автоматически';


--
-- TOC entry 244 (class 1259 OID 16943)
-- Name: client_point_groups_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.client_point_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.client_point_groups_id_seq OWNER TO postgres;

--
-- TOC entry 4878 (class 0 OID 0)
-- Dependencies: 244
-- Name: client_point_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.client_point_groups_id_seq OWNED BY data.client_point_groups.id;


--
-- TOC entry 245 (class 1259 OID 16945)
-- Name: client_points; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.client_points (
    id integer NOT NULL,
    client_id integer,
    name character varying(255),
    description text,
    code character varying(20),
    visible boolean,
    address character varying(1024),
    google_original bigint,
    dispatcher_id integer,
    group_id integer
);


ALTER TABLE data.client_points OWNER TO postgres;

--
-- TOC entry 4879 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN client_points.code; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.client_points.code IS 'Код точки - генерится автоматически';


--
-- TOC entry 246 (class 1259 OID 16951)
-- Name: client_points_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.client_points_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.client_points_id_seq OWNER TO postgres;

--
-- TOC entry 4880 (class 0 OID 0)
-- Dependencies: 246
-- Name: client_points_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.client_points_id_seq OWNED BY data.client_points.id;


--
-- TOC entry 247 (class 1259 OID 16953)
-- Name: clients; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.clients (
    id integer NOT NULL,
    name character varying(255),
    password character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean,
    default_dispatcher_id integer,
    token character varying(64) NOT NULL,
    default_load_address character varying(1024),
    default_load_latitude numeric(12,6),
    default_load_longitude numeric(12,6)
);


ALTER TABLE data.clients OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 16959)
-- Name: clients_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.clients_id_seq OWNER TO postgres;

--
-- TOC entry 4881 (class 0 OID 0)
-- Dependencies: 248
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.clients_id_seq OWNED BY data.clients.id;


--
-- TOC entry 249 (class 1259 OID 16961)
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.contracts_id_seq OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 16963)
-- Name: contracts; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.contracts (
    id integer DEFAULT nextval('data.contracts_id_seq'::regclass) NOT NULL,
    dispatcher_id integer,
    name text,
    description text
);


ALTER TABLE data.contracts OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 16970)
-- Name: cost_types; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.cost_types (
    id integer NOT NULL,
    name character varying(80),
    dispatcher_id integer
);


ALTER TABLE data.cost_types OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 16973)
-- Name: cost_types_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.cost_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.cost_types_id_seq OWNER TO postgres;

--
-- TOC entry 4882 (class 0 OID 0)
-- Dependencies: 252
-- Name: cost_types_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.cost_types_id_seq OWNED BY data.cost_types.id;


--
-- TOC entry 253 (class 1259 OID 16975)
-- Name: dispatcher_dogovor_files_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_dogovor_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_dogovor_files_id_seq OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 16977)
-- Name: dispatcher_dogovor_files; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_dogovor_files (
    id bigint DEFAULT nextval('data.dispatcher_dogovor_files_id_seq'::regclass) NOT NULL,
    dogovor_id bigint NOT NULL,
    filedata bytea,
    filename text,
    filepath text,
    filesize bigint
);


ALTER TABLE data.dispatcher_dogovor_files OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 16984)
-- Name: dispatcher_dogovors; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_dogovors (
    id integer NOT NULL,
    dispatcher_id integer,
    type_id integer,
    name character varying(1024),
    archive boolean
);


ALTER TABLE data.dispatcher_dogovors OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 16990)
-- Name: dispatcher_dogovors_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_dogovors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_dogovors_id_seq OWNER TO postgres;

--
-- TOC entry 4883 (class 0 OID 0)
-- Dependencies: 256
-- Name: dispatcher_dogovors_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatcher_dogovors_id_seq OWNED BY data.dispatcher_dogovors.id;


--
-- TOC entry 257 (class 1259 OID 16992)
-- Name: dispatcher_favorite_orders; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_favorite_orders (
    id bigint NOT NULL,
    order_id bigint,
    dispatcher_id integer,
    favorite boolean
);


ALTER TABLE data.dispatcher_favorite_orders OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 16995)
-- Name: dispatcher_favorite_orders_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_favorite_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_favorite_orders_id_seq OWNER TO postgres;

--
-- TOC entry 4884 (class 0 OID 0)
-- Dependencies: 258
-- Name: dispatcher_favorite_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatcher_favorite_orders_id_seq OWNED BY data.dispatcher_favorite_orders.id;


--
-- TOC entry 259 (class 1259 OID 16997)
-- Name: dispatcher_route_calculations; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_route_calculations (
    id integer NOT NULL,
    route_id integer,
    calc_date date,
    calc_type_id integer,
    calc_data jsonb
);


ALTER TABLE data.dispatcher_route_calculations OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 17003)
-- Name: dispatcher_route_calculations_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_route_calculations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_route_calculations_id_seq OWNER TO postgres;

--
-- TOC entry 4885 (class 0 OID 0)
-- Dependencies: 260
-- Name: dispatcher_route_calculations_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatcher_route_calculations_id_seq OWNED BY data.dispatcher_route_calculations.id;


--
-- TOC entry 261 (class 1259 OID 17005)
-- Name: dispatcher_routes_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_routes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE data.dispatcher_routes_id_seq OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 17007)
-- Name: dispatcher_routes; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_routes (
    id integer DEFAULT nextval('data.dispatcher_routes_id_seq'::regclass) NOT NULL,
    dispatcher_id integer,
    name text,
    active boolean,
    description text,
    difficulty_id integer,
    restrictions jsonb,
    client_id integer,
    load_data jsonb,
    load_time time without time zone,
    base_sum numeric(15,2),
    docs_next_day boolean
);


ALTER TABLE data.dispatcher_routes OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 17014)
-- Name: dispatcher_selected_drivers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_selected_drivers (
    id bigint NOT NULL,
    selected_id bigint NOT NULL,
    driver_id integer NOT NULL,
    datetime timestamp without time zone,
    first_view_time timestamp without time zone,
    reject_time timestamp without time zone
);


ALTER TABLE data.dispatcher_selected_drivers OWNER TO postgres;

--
-- TOC entry 4886 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE dispatcher_selected_drivers; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.dispatcher_selected_drivers IS 'Выделенные водителя для предложения заказа';


--
-- TOC entry 264 (class 1259 OID 17017)
-- Name: dispatcher_selected_drivers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_selected_drivers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_selected_drivers_id_seq OWNER TO postgres;

--
-- TOC entry 4887 (class 0 OID 0)
-- Dependencies: 264
-- Name: dispatcher_selected_drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatcher_selected_drivers_id_seq OWNED BY data.dispatcher_selected_drivers.id;


--
-- TOC entry 265 (class 1259 OID 17019)
-- Name: dispatcher_selected_orders; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_selected_orders (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    sel_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean
);


ALTER TABLE data.dispatcher_selected_orders OWNER TO postgres;

--
-- TOC entry 4888 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE dispatcher_selected_orders; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.dispatcher_selected_orders IS 'Выделенные заказы для предложений водителям';


--
-- TOC entry 266 (class 1259 OID 17023)
-- Name: dispatcher_selected_orders_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatcher_selected_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatcher_selected_orders_id_seq OWNER TO postgres;

--
-- TOC entry 4889 (class 0 OID 0)
-- Dependencies: 266
-- Name: dispatcher_selected_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatcher_selected_orders_id_seq OWNED BY data.dispatcher_selected_orders.id;


--
-- TOC entry 267 (class 1259 OID 17025)
-- Name: dispatcher_to_client; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatcher_to_client (
    dispatcher_id integer NOT NULL,
    client_id integer NOT NULL
);


ALTER TABLE data.dispatcher_to_client OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 17028)
-- Name: dispatchers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.dispatchers (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    pass character varying(255) NOT NULL,
    login character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    second_name character varying(255),
    family_name character varying(255),
    is_admin boolean,
    phone character varying(20),
    token character varying(64)
);


ALTER TABLE data.dispatchers OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 17034)
-- Name: dispatchers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.dispatchers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.dispatchers_id_seq OWNER TO postgres;

--
-- TOC entry 4890 (class 0 OID 0)
-- Dependencies: 269
-- Name: dispatchers_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.dispatchers_id_seq OWNED BY data.dispatchers.id;


--
-- TOC entry 270 (class 1259 OID 17036)
-- Name: driver_activities; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_activities (
    id bigint NOT NULL,
    driver_id integer,
    datetime timestamp without time zone,
    balls integer,
    type_id integer
);


ALTER TABLE data.driver_activities OWNER TO postgres;

--
-- TOC entry 271 (class 1259 OID 17039)
-- Name: driver_activities_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_activities_id_seq OWNER TO postgres;

--
-- TOC entry 4891 (class 0 OID 0)
-- Dependencies: 271
-- Name: driver_activities_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_activities_id_seq OWNED BY data.driver_activities.id;


--
-- TOC entry 272 (class 1259 OID 17041)
-- Name: driver_car_docs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_car_docs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_car_docs_id_seq OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 17043)
-- Name: driver_car_docs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_car_docs (
    id bigint DEFAULT nextval('data.driver_car_docs_id_seq'::regclass) NOT NULL,
    doc_type integer NOT NULL,
    doc_number text,
    doc_date date,
    start_date date,
    end_date date,
    driver_car_id integer NOT NULL,
    doc_serie text
);


ALTER TABLE data.driver_car_docs OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 17050)
-- Name: driver_car_files_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_car_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_car_files_id_seq OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 17052)
-- Name: driver_car_files; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_car_files (
    id bigint DEFAULT nextval('data.driver_car_files_id_seq'::regclass) NOT NULL,
    doc_id bigint NOT NULL,
    filedata bytea,
    filename text,
    filepath text,
    filesize bigint
);


ALTER TABLE data.driver_car_files OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 17059)
-- Name: driver_car_tariffs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_car_tariffs (
    id integer NOT NULL,
    driver_car_id integer,
    tariff_id integer
);


ALTER TABLE data.driver_car_tariffs OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 17062)
-- Name: driver_car_tariffs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_car_tariffs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_car_tariffs_id_seq OWNER TO postgres;

--
-- TOC entry 4892 (class 0 OID 0)
-- Dependencies: 277
-- Name: driver_car_tariffs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_car_tariffs_id_seq OWNED BY data.driver_car_tariffs.id;


--
-- TOC entry 278 (class 1259 OID 17064)
-- Name: driver_cars; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_cars (
    id integer NOT NULL,
    driver_id integer NOT NULL,
    cartype_id integer NOT NULL,
    carmodel character varying(80) NOT NULL,
    carnumber character varying(20) NOT NULL,
    carcolor character varying(80) NOT NULL,
    is_active boolean NOT NULL,
    carclass_id integer,
    is_default boolean,
    tariff_id integer,
    weight_limit numeric(12,2),
    volume_limit numeric(12,2),
    trays_limit integer,
    pallets_limit integer
);


ALTER TABLE data.driver_cars OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 17067)
-- Name: driver_cars_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_cars_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_cars_id_seq OWNER TO postgres;

--
-- TOC entry 4893 (class 0 OID 0)
-- Dependencies: 279
-- Name: driver_cars_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_cars_id_seq OWNED BY data.driver_cars.id;


--
-- TOC entry 280 (class 1259 OID 17069)
-- Name: driver_corrections; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_corrections (
    id bigint NOT NULL,
    driver_id integer,
    order_id bigint,
    point_id integer,
    latitude numeric(12,6),
    longitude numeric(12,6),
    datetime timestamp without time zone,
    real_latitude numeric(12,6),
    real_longitude numeric(12,6)
);


ALTER TABLE data.driver_corrections OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 17072)
-- Name: driver_costs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_costs (
    id bigint NOT NULL,
    driver_id integer,
    cost_id integer,
    percent numeric(6,2)
);


ALTER TABLE data.driver_costs OWNER TO postgres;

--
-- TOC entry 4894 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE driver_costs; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.driver_costs IS 'Сетка процентов затрат водителя';


--
-- TOC entry 282 (class 1259 OID 17075)
-- Name: driver_costs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_costs_id_seq OWNER TO postgres;

--
-- TOC entry 4895 (class 0 OID 0)
-- Dependencies: 282
-- Name: driver_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_costs_id_seq OWNED BY data.driver_costs.id;


--
-- TOC entry 283 (class 1259 OID 17077)
-- Name: driver_current_locations; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_current_locations (
    driver_id integer NOT NULL,
    latitude numeric(12,6),
    longitude numeric(12,6),
    loc_time timestamp without time zone
);


ALTER TABLE data.driver_current_locations OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 17080)
-- Name: driver_devices; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_devices (
    id integer NOT NULL,
    driver_id integer,
    device_id text,
    device_name text,
    add_datetime timestamp without time zone
);


ALTER TABLE data.driver_devices OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 17086)
-- Name: driver_devices_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_devices_id_seq OWNER TO postgres;

--
-- TOC entry 4896 (class 0 OID 0)
-- Dependencies: 285
-- Name: driver_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_devices_id_seq OWNED BY data.driver_devices.id;


--
-- TOC entry 286 (class 1259 OID 17088)
-- Name: driver_docs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_docs (
    id bigint NOT NULL,
    doc_type integer NOT NULL,
    doc_number text,
    doc_date date,
    start_date date,
    end_date date,
    driver_id integer NOT NULL,
    doc_serie text,
    doc_from text
);


ALTER TABLE data.driver_docs OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 17094)
-- Name: driver_docs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_docs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_docs_id_seq OWNER TO postgres;

--
-- TOC entry 4897 (class 0 OID 0)
-- Dependencies: 287
-- Name: driver_docs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_docs_id_seq OWNED BY data.driver_docs.id;


--
-- TOC entry 288 (class 1259 OID 17096)
-- Name: driver_files; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_files (
    id bigint NOT NULL,
    doc_id bigint NOT NULL,
    filedata bytea,
    filename text,
    filepath text,
    filesize bigint
);


ALTER TABLE data.driver_files OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 17102)
-- Name: driver_files_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_files_id_seq OWNER TO postgres;

--
-- TOC entry 4898 (class 0 OID 0)
-- Dependencies: 289
-- Name: driver_files_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_files_id_seq OWNED BY data.driver_files.id;


--
-- TOC entry 290 (class 1259 OID 17104)
-- Name: driver_history_locations; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_history_locations (
    driver_id integer,
    curr_latitude numeric(12,6),
    curr_longitude numeric(12,6),
    loc_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    device_id integer
);


ALTER TABLE data.driver_history_locations OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 17108)
-- Name: driver_stops; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.driver_stops (
    id bigint NOT NULL,
    datetime timestamp without time zone,
    driver_id integer,
    order_id bigint,
    latitude numeric(12,6),
    longitude numeric(12,6)
);


ALTER TABLE data.driver_stops OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 17111)
-- Name: driver_stops_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.driver_stops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.driver_stops_id_seq OWNER TO postgres;

--
-- TOC entry 4899 (class 0 OID 0)
-- Dependencies: 292
-- Name: driver_stops_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.driver_stops_id_seq OWNED BY data.driver_stops.id;


--
-- TOC entry 293 (class 1259 OID 17113)
-- Name: drivers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.drivers (
    id integer NOT NULL,
    login character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    pass character varying(255) NOT NULL,
    is_active boolean,
    level_id integer DEFAULT 1 NOT NULL,
    dispatcher_id integer,
    date_of_birth date,
    contact text,
    contact2 text,
    bank text,
    bik text,
    korrschet text,
    rasschet text,
    poluchatel text,
    inn text,
    kpp text,
    second_name character varying(255),
    family_name character varying(255) NOT NULL,
    reg_addresse character varying(1024),
    fact_addresse character varying(1024),
    bank_card character varying(40),
    restrictions jsonb,
    reg_address_lat numeric(12,6),
    reg_address_lng numeric(12,6),
    fact_address_lat numeric(12,6),
    fact_address_lng numeric(12,6),
    contract_id integer,
    reset_password_code character varying(40),
    reset_password_time timestamp without time zone,
    ogrnip text,
    calendar_index integer
);


ALTER TABLE data.drivers OWNER TO postgres;

--
-- TOC entry 294 (class 1259 OID 17120)
-- Name: drivers_corrections_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.drivers_corrections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.drivers_corrections_id_seq OWNER TO postgres;

--
-- TOC entry 4900 (class 0 OID 0)
-- Dependencies: 294
-- Name: drivers_corrections_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.drivers_corrections_id_seq OWNED BY data.driver_corrections.id;


--
-- TOC entry 295 (class 1259 OID 17122)
-- Name: drivers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.drivers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.drivers_id_seq OWNER TO postgres;

--
-- TOC entry 4901 (class 0 OID 0)
-- Dependencies: 295
-- Name: drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.drivers_id_seq OWNED BY data.drivers.id;


--
-- TOC entry 296 (class 1259 OID 17124)
-- Name: feedback; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.feedback (
    id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    driver_id integer NOT NULL,
    summa numeric(15,2),
    opernumber integer,
    operdate timestamp without time zone,
    paid date,
    commentary text,
    is_deleted boolean,
    del_time timestamp without time zone
);


ALTER TABLE data.feedback OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 17130)
-- Name: feedback_docs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.feedback_docs (
    id bigint NOT NULL,
    feedback_id bigint NOT NULL
);


ALTER TABLE data.feedback_docs OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 17133)
-- Name: feedback_docs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.feedback_docs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.feedback_docs_id_seq OWNER TO postgres;

--
-- TOC entry 4902 (class 0 OID 0)
-- Dependencies: 298
-- Name: feedback_docs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.feedback_docs_id_seq OWNED BY data.feedback_docs.id;


--
-- TOC entry 299 (class 1259 OID 17135)
-- Name: feedback_files_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.feedback_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.feedback_files_id_seq OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 17137)
-- Name: feedback_files; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.feedback_files (
    id bigint DEFAULT nextval('data.feedback_files_id_seq'::regclass) NOT NULL,
    doc_id bigint NOT NULL,
    filedata bytea,
    filename text,
    filepath text,
    filesize bigint
);


ALTER TABLE data.feedback_files OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 17144)
-- Name: feedback_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.feedback_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.feedback_id_seq OWNER TO postgres;

--
-- TOC entry 4903 (class 0 OID 0)
-- Dependencies: 301
-- Name: feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.feedback_id_seq OWNED BY data.feedback.id;


--
-- TOC entry 302 (class 1259 OID 17146)
-- Name: finances_log; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.finances_log (
    id bigint NOT NULL,
    payment_id bigint,
    addsum_id bigint,
    dispatcher_id integer,
    datetime timestamp without time zone,
    action_string text
);


ALTER TABLE data.finances_log OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 17152)
-- Name: finances_log_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.finances_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.finances_log_id_seq OWNER TO postgres;

--
-- TOC entry 4904 (class 0 OID 0)
-- Dependencies: 303
-- Name: finances_log_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.finances_log_id_seq OWNED BY data.finances_log.id;


--
-- TOC entry 304 (class 1259 OID 17154)
-- Name: google_addresses_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.google_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.google_addresses_id_seq OWNER TO postgres;

--
-- TOC entry 4905 (class 0 OID 0)
-- Dependencies: 304
-- Name: google_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.google_addresses_id_seq OWNED BY data.google_addresses.id;


--
-- TOC entry 305 (class 1259 OID 17156)
-- Name: google_modifiers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.google_modifiers (
    id bigint NOT NULL,
    client_id integer,
    latitude numeric(12,6),
    longitude numeric(12,6),
    original_id bigint,
    dispatcher_id integer
);


ALTER TABLE data.google_modifiers OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 17159)
-- Name: google_modifiers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.google_modifiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.google_modifiers_id_seq OWNER TO postgres;

--
-- TOC entry 4906 (class 0 OID 0)
-- Dependencies: 306
-- Name: google_modifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.google_modifiers_id_seq OWNED BY data.google_modifiers.id;


--
-- TOC entry 307 (class 1259 OID 17161)
-- Name: google_originals_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.google_originals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.google_originals_id_seq OWNER TO postgres;

--
-- TOC entry 4907 (class 0 OID 0)
-- Dependencies: 307
-- Name: google_originals_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.google_originals_id_seq OWNED BY data.google_originals.id;


--
-- TOC entry 308 (class 1259 OID 17163)
-- Name: log; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.log (
    id bigint NOT NULL,
    datetime timestamp without time zone,
    driver_id integer,
    dispatcher_id integer,
    client_id integer,
    ip character varying(32),
    user_action text
);


ALTER TABLE data.log OWNER TO postgres;

--
-- TOC entry 309 (class 1259 OID 17169)
-- Name: log_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.log_id_seq OWNER TO postgres;

--
-- TOC entry 4908 (class 0 OID 0)
-- Dependencies: 309
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.log_id_seq OWNED BY data.log.id;


--
-- TOC entry 310 (class 1259 OID 17171)
-- Name: money_requests; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.money_requests (
    id bigint NOT NULL,
    driver_id integer NOT NULL,
    dispatcher_id integer NOT NULL,
    summa numeric(15,2),
    datetime timestamp without time zone,
    unread boolean
);


ALTER TABLE data.money_requests OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 17174)
-- Name: money_requests_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.money_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.money_requests_id_seq OWNER TO postgres;

--
-- TOC entry 4909 (class 0 OID 0)
-- Dependencies: 311
-- Name: money_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.money_requests_id_seq OWNED BY data.money_requests.id;


--
-- TOC entry 312 (class 1259 OID 17176)
-- Name: options; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.options (
    id integer NOT NULL,
    dispatcher_id integer,
    param_name text,
    param_value_text text,
    param_value_integer integer,
    param_value_real real,
    section_id integer NOT NULL,
    param_view_name text,
    param_value_json jsonb
);


ALTER TABLE data.options OWNER TO postgres;

--
-- TOC entry 313 (class 1259 OID 17182)
-- Name: options_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.options_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.options_id_seq OWNER TO postgres;

--
-- TOC entry 4910 (class 0 OID 0)
-- Dependencies: 313
-- Name: options_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.options_id_seq OWNED BY data.options.id;


--
-- TOC entry 314 (class 1259 OID 17184)
-- Name: options_sections; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.options_sections (
    id integer NOT NULL,
    name character varying(80)
);


ALTER TABLE data.options_sections OWNER TO postgres;

--
-- TOC entry 315 (class 1259 OID 17187)
-- Name: order_agg_costs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_agg_costs (
    id bigint NOT NULL,
    order_id bigint,
    cost_name text,
    summa numeric(15,2)
);


ALTER TABLE data.order_agg_costs OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 17193)
-- Name: order_agg_costs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_agg_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_agg_costs_id_seq OWNER TO postgres;

--
-- TOC entry 4911 (class 0 OID 0)
-- Dependencies: 316
-- Name: order_agg_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_agg_costs_id_seq OWNED BY data.order_agg_costs.id;


--
-- TOC entry 317 (class 1259 OID 17195)
-- Name: order_costs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_costs (
    id bigint NOT NULL,
    order_id bigint,
    cost_id integer,
    summa numeric(15,2),
    tariff_cost_id integer
);


ALTER TABLE data.order_costs OWNER TO postgres;

--
-- TOC entry 318 (class 1259 OID 17198)
-- Name: order_costs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_costs_id_seq OWNER TO postgres;

--
-- TOC entry 4912 (class 0 OID 0)
-- Dependencies: 318
-- Name: order_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_costs_id_seq OWNED BY data.order_costs.id;


--
-- TOC entry 319 (class 1259 OID 17200)
-- Name: order_exec_clients_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_exec_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_exec_clients_id_seq OWNER TO postgres;

--
-- TOC entry 320 (class 1259 OID 17202)
-- Name: order_exec_clients; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_exec_clients (
    id integer DEFAULT nextval('data.order_exec_clients_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    client_id integer,
    dispatcher_id integer,
    exec_order timestamp without time zone
);


ALTER TABLE data.order_exec_clients OWNER TO postgres;

--
-- TOC entry 321 (class 1259 OID 17206)
-- Name: order_exec_dispatchers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_exec_dispatchers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_exec_dispatchers_id_seq OWNER TO postgres;

--
-- TOC entry 322 (class 1259 OID 17208)
-- Name: order_exec_dispatchers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_exec_dispatchers (
    id integer DEFAULT nextval('data.order_exec_dispatchers_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    exec_order timestamp without time zone
);


ALTER TABLE data.order_exec_dispatchers OWNER TO postgres;

--
-- TOC entry 323 (class 1259 OID 17212)
-- Name: order_finish_drivers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_finish_drivers (
    id integer NOT NULL,
    order_id bigint NOT NULL,
    driver_id integer NOT NULL,
    finish_order timestamp without time zone
);


ALTER TABLE data.order_finish_drivers OWNER TO postgres;

--
-- TOC entry 324 (class 1259 OID 17215)
-- Name: order_finish_drivers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_finish_drivers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_finish_drivers_id_seq OWNER TO postgres;

--
-- TOC entry 4913 (class 0 OID 0)
-- Dependencies: 324
-- Name: order_finish_drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_finish_drivers_id_seq OWNED BY data.order_finish_drivers.id;


--
-- TOC entry 325 (class 1259 OID 17217)
-- Name: order_history; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_history (
    id bigint NOT NULL,
    order_title character varying(256),
    from_name character varying(1024),
    summa numeric(15,2),
    latitude numeric(12,6),
    longitude numeric(12,6),
    client_id integer NOT NULL,
    point_id integer
);


ALTER TABLE data.order_history OWNER TO postgres;

--
-- TOC entry 326 (class 1259 OID 17223)
-- Name: order_history_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_history_id_seq OWNER TO postgres;

--
-- TOC entry 4914 (class 0 OID 0)
-- Dependencies: 326
-- Name: order_history_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_history_id_seq OWNED BY data.order_history.id;


--
-- TOC entry 327 (class 1259 OID 17225)
-- Name: order_locations; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_locations (
    id bigint NOT NULL,
    order_id bigint,
    driver_id integer,
    datetime timestamp without time zone,
    latitude numeric(12,6),
    longitude numeric(12,6)
);


ALTER TABLE data.order_locations OWNER TO postgres;

--
-- TOC entry 328 (class 1259 OID 17228)
-- Name: order_locations_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_locations_id_seq OWNER TO postgres;

--
-- TOC entry 4915 (class 0 OID 0)
-- Dependencies: 328
-- Name: order_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_locations_id_seq OWNED BY data.order_locations.id;


--
-- TOC entry 329 (class 1259 OID 17230)
-- Name: order_log; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_log (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    client_id integer,
    dispatcher_id integer,
    driver_id integer,
    datetime timestamp without time zone,
    status_old integer,
    status_new integer,
    action_string text
);


ALTER TABLE data.order_log OWNER TO postgres;

--
-- TOC entry 330 (class 1259 OID 17236)
-- Name: order_log_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_log_id_seq OWNER TO postgres;

--
-- TOC entry 4916 (class 0 OID 0)
-- Dependencies: 330
-- Name: order_log_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_log_id_seq OWNED BY data.order_log.id;


--
-- TOC entry 331 (class 1259 OID 17238)
-- Name: order_not_exec_dispatchers_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_not_exec_dispatchers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_not_exec_dispatchers_id_seq OWNER TO postgres;

--
-- TOC entry 332 (class 1259 OID 17240)
-- Name: order_not_exec_dispatchers; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_not_exec_dispatchers (
    id integer DEFAULT nextval('data.order_not_exec_dispatchers_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    not_exec_order timestamp without time zone
);


ALTER TABLE data.order_not_exec_dispatchers OWNER TO postgres;

--
-- TOC entry 333 (class 1259 OID 17244)
-- Name: order_ratings; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_ratings (
    id bigint NOT NULL,
    order_id bigint,
    rating_id integer,
    rating_value real
);


ALTER TABLE data.order_ratings OWNER TO postgres;

--
-- TOC entry 334 (class 1259 OID 17247)
-- Name: order_ratings_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_ratings_id_seq OWNER TO postgres;

--
-- TOC entry 4917 (class 0 OID 0)
-- Dependencies: 334
-- Name: order_ratings_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_ratings_id_seq OWNED BY data.order_ratings.id;


--
-- TOC entry 335 (class 1259 OID 17249)
-- Name: order_views; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.order_views (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    driver_id integer,
    timeview timestamp without time zone
);


ALTER TABLE data.order_views OWNER TO postgres;

--
-- TOC entry 336 (class 1259 OID 17252)
-- Name: order_views_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.order_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.order_views_id_seq OWNER TO postgres;

--
-- TOC entry 4918 (class 0 OID 0)
-- Dependencies: 336
-- Name: order_views_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.order_views_id_seq OWNED BY data.order_views.id;


--
-- TOC entry 337 (class 1259 OID 17254)
-- Name: orders; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders (
    id bigint NOT NULL,
    order_time timestamp without time zone,
    from_addr_name character varying(1024),
    from_addr_latitude numeric(12,6),
    from_addr_longitude numeric(12,6),
    summa numeric(15,2),
    driver_id integer,
    dispatcher_id integer,
    status_id integer,
    carclass_id integer,
    paytype_id integer,
    is_deleted boolean,
    del_time timestamp without time zone,
    distance real,
    duration integer,
    from_time timestamp without time zone,
    visible boolean,
    notes character varying(1024),
    order_title character varying(255),
    client_id integer NOT NULL,
    client_dispatcher_id integer,
    client_code character varying(80),
    client_summa numeric(15,2),
    hours integer,
    driver_car_attribs jsonb,
    from_kontakt_name character varying(256),
    from_kontakt_phone character varying(80),
    from_notes character varying(1024),
    duration_calc integer,
    free_sum boolean,
    point_id integer,
    end_time timestamp without time zone,
    first_offer_time timestamp without time zone,
    begin_time timestamp without time zone,
    doc_date date,
    end_device_id integer,
    rating numeric(6,2),
    created_by_dispatcher_id integer,
    dispatcher_route_id integer,
    pallets_count numeric(10,2)
);


ALTER TABLE data.orders OWNER TO postgres;

--
-- TOC entry 4919 (class 0 OID 0)
-- Dependencies: 337
-- Name: COLUMN orders.client_dispatcher_id; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.orders.client_dispatcher_id IS 'Диспетчер, которого изначально поставил клиент';


--
-- TOC entry 4920 (class 0 OID 0)
-- Dependencies: 337
-- Name: COLUMN orders.hours; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.orders.hours IS 'Время на аренду машины';


--
-- TOC entry 4921 (class 0 OID 0)
-- Dependencies: 337
-- Name: COLUMN orders.driver_car_attribs; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.orders.driver_car_attribs IS 'Данные по машине из заказа в виде JSON';


--
-- TOC entry 4922 (class 0 OID 0)
-- Dependencies: 337
-- Name: COLUMN orders.doc_date; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON COLUMN data.orders.doc_date IS 'Date for official documents';


--
-- TOC entry 338 (class 1259 OID 17260)
-- Name: orders_appointing_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_appointing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_appointing_id_seq OWNER TO postgres;

--
-- TOC entry 339 (class 1259 OID 17262)
-- Name: orders_appointing; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders_appointing (
    id bigint DEFAULT nextval('data.orders_appointing_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    driver_id integer NOT NULL,
    appoint_order timestamp without time zone,
    car_attribs jsonb
);


ALTER TABLE data.orders_appointing OWNER TO postgres;

--
-- TOC entry 4923 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE orders_appointing; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.orders_appointing IS 'Таблица таймстампов назначений заказов диспетчерами';


--
-- TOC entry 340 (class 1259 OID 17269)
-- Name: orders_canceling_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_canceling_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_canceling_id_seq OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 17271)
-- Name: orders_canceling; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders_canceling (
    id bigint DEFAULT nextval('data.orders_canceling_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    driver_id integer NOT NULL,
    cancel_order timestamp without time zone
);


ALTER TABLE data.orders_canceling OWNER TO postgres;

--
-- TOC entry 4924 (class 0 OID 0)
-- Dependencies: 341
-- Name: TABLE orders_canceling; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.orders_canceling IS 'Таблица таймстампов отмен заказов водителями';


--
-- TOC entry 342 (class 1259 OID 17275)
-- Name: orders_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_id_seq OWNER TO postgres;

--
-- TOC entry 4925 (class 0 OID 0)
-- Dependencies: 342
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.orders_id_seq OWNED BY data.orders.id;


--
-- TOC entry 343 (class 1259 OID 17277)
-- Name: orders_rejecting_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_rejecting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_rejecting_id_seq OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 17279)
-- Name: orders_rejecting; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders_rejecting (
    id bigint DEFAULT nextval('data.orders_rejecting_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    driver_id integer NOT NULL,
    reject_order timestamp without time zone
);


ALTER TABLE data.orders_rejecting OWNER TO postgres;

--
-- TOC entry 4926 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE orders_rejecting; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.orders_rejecting IS 'Таблица таймстампов отклонений заказов водителями';


--
-- TOC entry 345 (class 1259 OID 17283)
-- Name: orders_revoking_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_revoking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_revoking_id_seq OWNER TO postgres;

--
-- TOC entry 346 (class 1259 OID 17285)
-- Name: orders_revoking; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders_revoking (
    id bigint DEFAULT nextval('data.orders_revoking_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    dispatcher_id integer NOT NULL,
    driver_id integer NOT NULL,
    revoke_order timestamp without time zone
);


ALTER TABLE data.orders_revoking OWNER TO postgres;

--
-- TOC entry 4927 (class 0 OID 0)
-- Dependencies: 346
-- Name: TABLE orders_revoking; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.orders_revoking IS 'Таблица таймстампов отмен назначений заказов диспетчерами';


--
-- TOC entry 347 (class 1259 OID 17289)
-- Name: orders_taking; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.orders_taking (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    driver_id integer NOT NULL,
    take_order timestamp without time zone,
    driver_car_attribs jsonb
);


ALTER TABLE data.orders_taking OWNER TO postgres;

--
-- TOC entry 4928 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE orders_taking; Type: COMMENT; Schema: data; Owner: postgres
--

COMMENT ON TABLE data.orders_taking IS 'Таблица таймстампов взятий заказов водителями';


--
-- TOC entry 348 (class 1259 OID 17295)
-- Name: orders_taking_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.orders_taking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.orders_taking_id_seq OWNER TO postgres;

--
-- TOC entry 4929 (class 0 OID 0)
-- Dependencies: 348
-- Name: orders_taking_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.orders_taking_id_seq OWNED BY data.orders_taking.id;


--
-- TOC entry 349 (class 1259 OID 17297)
-- Name: password_histories; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.password_histories (
    id integer NOT NULL,
    user_id integer NOT NULL,
    password character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE data.password_histories OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 17300)
-- Name: point_rating; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.point_rating (
    id integer NOT NULL,
    point_id integer,
    driver_id integer,
    order_id bigint,
    rating numeric(5,2),
    commentary text
);


ALTER TABLE data.point_rating OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 17306)
-- Name: point_rating_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.point_rating_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.point_rating_id_seq OWNER TO postgres;

--
-- TOC entry 4930 (class 0 OID 0)
-- Dependencies: 351
-- Name: point_rating_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.point_rating_id_seq OWNED BY data.point_rating.id;


--
-- TOC entry 352 (class 1259 OID 17308)
-- Name: routes_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.routes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.routes_id_seq OWNER TO postgres;

--
-- TOC entry 353 (class 1259 OID 17310)
-- Name: routes; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.routes (
    id integer DEFAULT nextval('data.routes_id_seq'::regclass) NOT NULL,
    client_id integer,
    name text,
    summa numeric(15,2),
    active boolean,
    description text,
    type_id integer,
    restrictions jsonb,
    sums jsonb,
    dispatcher_id integer
);


ALTER TABLE data.routes OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 17317)
-- Name: tariff_costs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.tariff_costs (
    id integer NOT NULL,
    tariff_id integer,
    name text,
    percent numeric(6,2)
);


ALTER TABLE data.tariff_costs OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 17323)
-- Name: tariff_costs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.tariff_costs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.tariff_costs_id_seq OWNER TO postgres;

--
-- TOC entry 4931 (class 0 OID 0)
-- Dependencies: 355
-- Name: tariff_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.tariff_costs_id_seq OWNED BY data.tariff_costs.id;


--
-- TOC entry 356 (class 1259 OID 17325)
-- Name: tariffs; Type: TABLE; Schema: data; Owner: postgres
--

CREATE TABLE data.tariffs (
    id integer NOT NULL,
    dispatcher_id integer,
    name text,
    description text,
    begin_date date,
    end_date date
);


ALTER TABLE data.tariffs OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 17331)
-- Name: tariffs_id_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.tariffs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.tariffs_id_seq OWNER TO postgres;

--
-- TOC entry 4932 (class 0 OID 0)
-- Dependencies: 357
-- Name: tariffs_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: postgres
--

ALTER SEQUENCE data.tariffs_id_seq OWNED BY data.tariffs.id;


--
-- TOC entry 358 (class 1259 OID 17333)
-- Name: view_counter_drv_seq; Type: SEQUENCE; Schema: data; Owner: postgres
--

CREATE SEQUENCE data.view_counter_drv_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE data.view_counter_drv_seq OWNER TO postgres;

--
-- TOC entry 433 (class 1259 OID 17639)
-- Name: SYS_ACTIVITYTYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ACTIVITYTYPES" (
    id integer NOT NULL,
    typename text
);


ALTER TABLE sysdata."SYS_ACTIVITYTYPES" OWNER TO postgres;

--
-- TOC entry 434 (class 1259 OID 17645)
-- Name: SYS_ACTIVITYTYPES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_ACTIVITYTYPES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_ACTIVITYTYPES_id_seq" OWNER TO postgres;

--
-- TOC entry 4933 (class 0 OID 0)
-- Dependencies: 434
-- Name: SYS_ACTIVITYTYPES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_ACTIVITYTYPES_id_seq" OWNED BY sysdata."SYS_ACTIVITYTYPES".id;


--
-- TOC entry 435 (class 1259 OID 17647)
-- Name: SYS_AUTOCREATETYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_AUTOCREATETYPES" (
    id integer NOT NULL,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_AUTOCREATETYPES" OWNER TO postgres;

--
-- TOC entry 436 (class 1259 OID 17650)
-- Name: SYS_CARCLASSES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_CARCLASSES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_CARCLASSES_id_seq" OWNER TO postgres;

--
-- TOC entry 4934 (class 0 OID 0)
-- Dependencies: 436
-- Name: SYS_CARCLASSES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_CARCLASSES_id_seq" OWNED BY sysdata."SYS_CARCLASSES".id;


--
-- TOC entry 437 (class 1259 OID 17652)
-- Name: SYS_CARTYPES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_CARTYPES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_CARTYPES_id_seq" OWNER TO postgres;

--
-- TOC entry 4935 (class 0 OID 0)
-- Dependencies: 437
-- Name: SYS_CARTYPES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_CARTYPES_id_seq" OWNED BY sysdata."SYS_CARTYPES".id;


--
-- TOC entry 438 (class 1259 OID 17654)
-- Name: SYS_CONDITION_VALUE_TYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_CONDITION_VALUE_TYPES" (
    id integer NOT NULL,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_CONDITION_VALUE_TYPES" OWNER TO postgres;

--
-- TOC entry 439 (class 1259 OID 17657)
-- Name: SYS_DAYTYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_DAYTYPES" (
    id integer NOT NULL,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_DAYTYPES" OWNER TO postgres;

--
-- TOC entry 440 (class 1259 OID 17660)
-- Name: SYS_DOCTYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_DOCTYPES" (
    id integer NOT NULL,
    typename text NOT NULL
);


ALTER TABLE sysdata."SYS_DOCTYPES" OWNER TO postgres;

--
-- TOC entry 441 (class 1259 OID 17666)
-- Name: SYS_DOCTYPES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_DOCTYPES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_DOCTYPES_id_seq" OWNER TO postgres;

--
-- TOC entry 4936 (class 0 OID 0)
-- Dependencies: 441
-- Name: SYS_DOCTYPES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_DOCTYPES_id_seq" OWNED BY sysdata."SYS_DOCTYPES".id;


--
-- TOC entry 442 (class 1259 OID 17668)
-- Name: SYS_DOGOVOR_TYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_DOGOVOR_TYPES" (
    id integer NOT NULL,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_DOGOVOR_TYPES" OWNER TO postgres;

--
-- TOC entry 443 (class 1259 OID 17671)
-- Name: SYS_ORDERSTATUS; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ORDERSTATUS" (
    id integer NOT NULL,
    name character varying(80),
    name_for_driver character varying(80)
);


ALTER TABLE sysdata."SYS_ORDERSTATUS" OWNER TO postgres;

--
-- TOC entry 444 (class 1259 OID 17674)
-- Name: SYS_PARAMS; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_PARAMS" (
    param_name character varying(80) NOT NULL,
    param_value_string character varying(1024),
    param_value_integer integer,
    param_value_real real,
    description text,
    param_json jsonb
);


ALTER TABLE sysdata."SYS_PARAMS" OWNER TO postgres;

--
-- TOC entry 445 (class 1259 OID 17680)
-- Name: SYS_PAYTYPES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_PAYTYPES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_PAYTYPES_id_seq" OWNER TO postgres;

--
-- TOC entry 4937 (class 0 OID 0)
-- Dependencies: 445
-- Name: SYS_PAYTYPES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_PAYTYPES_id_seq" OWNED BY sysdata."SYS_PAYTYPES".id;


--
-- TOC entry 446 (class 1259 OID 17682)
-- Name: SYS_RESOURCES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_RESOURCES" (
    id bigint NOT NULL,
    resource_id bigint,
    country_code character varying(6),
    name text
);


ALTER TABLE sysdata."SYS_RESOURCES" OWNER TO postgres;

--
-- TOC entry 447 (class 1259 OID 17688)
-- Name: SYS_RESOURCES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_RESOURCES_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_RESOURCES_id_seq" OWNER TO postgres;

--
-- TOC entry 4938 (class 0 OID 0)
-- Dependencies: 447
-- Name: SYS_RESOURCES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_RESOURCES_id_seq" OWNED BY sysdata."SYS_RESOURCES".id;


--
-- TOC entry 448 (class 1259 OID 17690)
-- Name: SYS_ROUTECALC_TYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ROUTECALC_TYPES" (
    id integer NOT NULL,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_ROUTECALC_TYPES" OWNER TO postgres;

--
-- TOC entry 449 (class 1259 OID 17693)
-- Name: SYS_ROUTERATING_PARAMS; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ROUTERATING_PARAMS" (
    id integer NOT NULL,
    name text,
    weight real
);


ALTER TABLE sysdata."SYS_ROUTERATING_PARAMS" OWNER TO postgres;

--
-- TOC entry 450 (class 1259 OID 17699)
-- Name: SYS_ROUTERESTRICTIONS; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ROUTERESTRICTIONS" (
    id integer NOT NULL,
    route_resource_id bigint,
    driver_resource_id bigint
);


ALTER TABLE sysdata."SYS_ROUTERESTRICTIONS" OWNER TO postgres;

--
-- TOC entry 451 (class 1259 OID 17702)
-- Name: SYS_ROUTERESTRICTIONS_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_ROUTERESTRICTIONS_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_ROUTERESTRICTIONS_id_seq" OWNER TO postgres;

--
-- TOC entry 4939 (class 0 OID 0)
-- Dependencies: 451
-- Name: SYS_ROUTERESTRICTIONS_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_ROUTERESTRICTIONS_id_seq" OWNED BY sysdata."SYS_ROUTERESTRICTIONS".id;


--
-- TOC entry 452 (class 1259 OID 17704)
-- Name: SYS_ROUTETYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ROUTETYPES" (
    id integer NOT NULL,
    difficulty numeric(5,2),
    resource_id bigint
);


ALTER TABLE sysdata."SYS_ROUTETYPES" OWNER TO postgres;

--
-- TOC entry 453 (class 1259 OID 17707)
-- Name: SYS_ROUTE_CONDITION_TYPES; Type: TABLE; Schema: sysdata; Owner: postgres
--

CREATE TABLE sysdata."SYS_ROUTE_CONDITION_TYPES" (
    id integer NOT NULL,
    value_type_id integer,
    resource_id bigint
);


ALTER TABLE sysdata."SYS_ROUTE_CONDITION_TYPES" OWNER TO postgres;

--
-- TOC entry 454 (class 1259 OID 17710)
-- Name: SYS_ROUTE_CONDITION_TYPES_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPES_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPES_id_seq" OWNER TO postgres;

--
-- TOC entry 4940 (class 0 OID 0)
-- Dependencies: 454
-- Name: SYS_ROUTE_CONDITION_TYPES_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPES_id_seq" OWNED BY sysdata."SYS_ROUTE_CONDITION_TYPES".id;


--
-- TOC entry 455 (class 1259 OID 17712)
-- Name: SYS_ROUTE_CONDITION_TYPE_id_seq; Type: SEQUENCE; Schema: sysdata; Owner: postgres
--

CREATE SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPE_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPE_id_seq" OWNER TO postgres;

--
-- TOC entry 4941 (class 0 OID 0)
-- Dependencies: 455
-- Name: SYS_ROUTE_CONDITION_TYPE_id_seq; Type: SEQUENCE OWNED BY; Schema: sysdata; Owner: postgres
--

ALTER SEQUENCE sysdata."SYS_ROUTE_CONDITION_TYPE_id_seq" OWNED BY sysdata."SYS_CONDITION_VALUE_TYPES".id;


--
-- TOC entry 456 (class 1259 OID 17714)
-- Name: cars_view; Type: VIEW; Schema: winapp; Owner: postgres
--

CREATE VIEW winapp.cars_view AS
 SELECT c.id,
    c.driver_id,
    c.cartype_id,
    (((cc.name)::text || '::'::text) || (ct.name)::text) AS cartype_name,
    c.carmodel,
    c.carnumber,
    c.carcolor,
    c.is_active
   FROM ((data.driver_cars c
     LEFT JOIN sysdata."SYS_CARTYPES" ct ON ((c.cartype_id = ct.id)))
     LEFT JOIN sysdata."SYS_CARCLASSES" cc ON ((ct.class_id = cc.id)));


ALTER VIEW winapp.cars_view OWNER TO postgres;

--
-- TOC entry 457 (class 1259 OID 17719)
-- Name: drivers_view; Type: VIEW; Schema: winapp; Owner: postgres
--

CREATE VIEW winapp.drivers_view WITH (security_barrier='false') AS
 SELECT d.id,
    d.name,
    d.login,
    dl.name AS level_name,
    d.is_active,
    d.date_of_birth,
    date_part('year'::text, age(CURRENT_TIMESTAMP, (d.date_of_birth)::timestamp with time zone)) AS full_age,
    d.contact,
    ( SELECT count(dc.id) AS count
           FROM data.driver_cars dc
          WHERE (dc.driver_id = d.id)) AS cars_count,
    d.dispatcher_id
   FROM (data.drivers d
     LEFT JOIN sysdata."SYS_DRIVERLEVELS" dl ON ((d.level_id = dl.id)));


ALTER VIEW winapp.drivers_view OWNER TO postgres;

--
-- TOC entry 3955 (class 2604 OID 21135)
-- Name: distance_for_load id; Type: DEFAULT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.distance_for_load ALTER COLUMN id SET DEFAULT nextval('assignment.distance_for_load_id_seq'::regclass);


--
-- TOC entry 3956 (class 2604 OID 21136)
-- Name: driver_last_route id; Type: DEFAULT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.driver_last_route ALTER COLUMN id SET DEFAULT nextval('assignment.driver_last_route_id_seq'::regclass);


--
-- TOC entry 3957 (class 2604 OID 21137)
-- Name: addsums id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums ALTER COLUMN id SET DEFAULT nextval('data.addsums_id_seq'::regclass);


--
-- TOC entry 3958 (class 2604 OID 21138)
-- Name: addsums_docs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums_docs ALTER COLUMN id SET DEFAULT nextval('data.addsums_docs_id_seq'::regclass);


--
-- TOC entry 3960 (class 2604 OID 21139)
-- Name: agg_commission id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.agg_commission ALTER COLUMN id SET DEFAULT nextval('data.agg_commission_id_seq'::regclass);


--
-- TOC entry 3961 (class 2604 OID 21140)
-- Name: agg_regions id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.agg_regions ALTER COLUMN id SET DEFAULT nextval('data.agg_regions_id_seq'::regclass);


--
-- TOC entry 3963 (class 2604 OID 21141)
-- Name: autocreate_logs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.autocreate_logs ALTER COLUMN id SET DEFAULT nextval('data.autocreate_logs_id_seq'::regclass);


--
-- TOC entry 3964 (class 2604 OID 21142)
-- Name: calendar id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar ALTER COLUMN id SET DEFAULT nextval('data.calendar_id_seq'::regclass);


--
-- TOC entry 3965 (class 2604 OID 21143)
-- Name: calendar_notifications id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_notifications ALTER COLUMN id SET DEFAULT nextval('data.calendar_notifications_id_seq'::regclass);


--
-- TOC entry 3966 (class 2604 OID 21144)
-- Name: checkpoint_history id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoint_history ALTER COLUMN id SET DEFAULT nextval('data.checkpoint_history_id_seq'::regclass);


--
-- TOC entry 3967 (class 2604 OID 21145)
-- Name: checkpoints id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoints ALTER COLUMN id SET DEFAULT nextval('data.checkpoints_id_seq'::regclass);


--
-- TOC entry 3968 (class 2604 OID 21146)
-- Name: client_point_coordinates id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_coordinates ALTER COLUMN id SET DEFAULT nextval('data.client_point_coordinates_id_seq'::regclass);


--
-- TOC entry 3969 (class 2604 OID 21147)
-- Name: client_point_groups id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_groups ALTER COLUMN id SET DEFAULT nextval('data.client_point_groups_id_seq'::regclass);


--
-- TOC entry 3970 (class 2604 OID 21148)
-- Name: client_points id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points ALTER COLUMN id SET DEFAULT nextval('data.client_points_id_seq'::regclass);


--
-- TOC entry 3971 (class 2604 OID 21149)
-- Name: clients id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.clients ALTER COLUMN id SET DEFAULT nextval('data.clients_id_seq'::regclass);


--
-- TOC entry 3973 (class 2604 OID 21150)
-- Name: cost_types id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.cost_types ALTER COLUMN id SET DEFAULT nextval('data.cost_types_id_seq'::regclass);


--
-- TOC entry 3975 (class 2604 OID 21151)
-- Name: dispatcher_dogovors id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovors ALTER COLUMN id SET DEFAULT nextval('data.dispatcher_dogovors_id_seq'::regclass);


--
-- TOC entry 3976 (class 2604 OID 21152)
-- Name: dispatcher_favorite_orders id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_favorite_orders ALTER COLUMN id SET DEFAULT nextval('data.dispatcher_favorite_orders_id_seq'::regclass);


--
-- TOC entry 3977 (class 2604 OID 21153)
-- Name: dispatcher_route_calculations id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_route_calculations ALTER COLUMN id SET DEFAULT nextval('data.dispatcher_route_calculations_id_seq'::regclass);


--
-- TOC entry 3979 (class 2604 OID 21154)
-- Name: dispatcher_selected_drivers id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_drivers ALTER COLUMN id SET DEFAULT nextval('data.dispatcher_selected_drivers_id_seq'::regclass);


--
-- TOC entry 3980 (class 2604 OID 21155)
-- Name: dispatcher_selected_orders id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_orders ALTER COLUMN id SET DEFAULT nextval('data.dispatcher_selected_orders_id_seq'::regclass);


--
-- TOC entry 3982 (class 2604 OID 21156)
-- Name: dispatchers id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatchers ALTER COLUMN id SET DEFAULT nextval('data.dispatchers_id_seq'::regclass);


--
-- TOC entry 3983 (class 2604 OID 21157)
-- Name: driver_activities id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_activities ALTER COLUMN id SET DEFAULT nextval('data.driver_activities_id_seq'::regclass);


--
-- TOC entry 3986 (class 2604 OID 21158)
-- Name: driver_car_tariffs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_tariffs ALTER COLUMN id SET DEFAULT nextval('data.driver_car_tariffs_id_seq'::regclass);


--
-- TOC entry 3987 (class 2604 OID 21159)
-- Name: driver_cars id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars ALTER COLUMN id SET DEFAULT nextval('data.driver_cars_id_seq'::regclass);


--
-- TOC entry 3988 (class 2604 OID 21160)
-- Name: driver_corrections id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_corrections ALTER COLUMN id SET DEFAULT nextval('data.drivers_corrections_id_seq'::regclass);


--
-- TOC entry 3989 (class 2604 OID 21161)
-- Name: driver_costs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_costs ALTER COLUMN id SET DEFAULT nextval('data.driver_costs_id_seq'::regclass);


--
-- TOC entry 3990 (class 2604 OID 21162)
-- Name: driver_devices id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_devices ALTER COLUMN id SET DEFAULT nextval('data.driver_devices_id_seq'::regclass);


--
-- TOC entry 3991 (class 2604 OID 21163)
-- Name: driver_docs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_docs ALTER COLUMN id SET DEFAULT nextval('data.driver_docs_id_seq'::regclass);


--
-- TOC entry 3992 (class 2604 OID 21164)
-- Name: driver_files id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_files ALTER COLUMN id SET DEFAULT nextval('data.driver_files_id_seq'::regclass);


--
-- TOC entry 3994 (class 2604 OID 21165)
-- Name: driver_stops id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_stops ALTER COLUMN id SET DEFAULT nextval('data.driver_stops_id_seq'::regclass);


--
-- TOC entry 3995 (class 2604 OID 21166)
-- Name: drivers id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers ALTER COLUMN id SET DEFAULT nextval('data.drivers_id_seq'::regclass);


--
-- TOC entry 3997 (class 2604 OID 21167)
-- Name: feedback id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback ALTER COLUMN id SET DEFAULT nextval('data.feedback_id_seq'::regclass);


--
-- TOC entry 3998 (class 2604 OID 21168)
-- Name: feedback_docs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback_docs ALTER COLUMN id SET DEFAULT nextval('data.feedback_docs_id_seq'::regclass);


--
-- TOC entry 4000 (class 2604 OID 21169)
-- Name: finances_log id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.finances_log ALTER COLUMN id SET DEFAULT nextval('data.finances_log_id_seq'::regclass);


--
-- TOC entry 3953 (class 2604 OID 21170)
-- Name: google_addresses id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_addresses ALTER COLUMN id SET DEFAULT nextval('data.google_addresses_id_seq'::regclass);


--
-- TOC entry 4001 (class 2604 OID 21171)
-- Name: google_modifiers id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_modifiers ALTER COLUMN id SET DEFAULT nextval('data.google_modifiers_id_seq'::regclass);


--
-- TOC entry 3954 (class 2604 OID 21172)
-- Name: google_originals id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_originals ALTER COLUMN id SET DEFAULT nextval('data.google_originals_id_seq'::regclass);


--
-- TOC entry 4002 (class 2604 OID 21173)
-- Name: log id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.log ALTER COLUMN id SET DEFAULT nextval('data.log_id_seq'::regclass);


--
-- TOC entry 4003 (class 2604 OID 21174)
-- Name: money_requests id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.money_requests ALTER COLUMN id SET DEFAULT nextval('data.money_requests_id_seq'::regclass);


--
-- TOC entry 4004 (class 2604 OID 21175)
-- Name: options id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options ALTER COLUMN id SET DEFAULT nextval('data.options_id_seq'::regclass);


--
-- TOC entry 4005 (class 2604 OID 21176)
-- Name: order_agg_costs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_agg_costs ALTER COLUMN id SET DEFAULT nextval('data.order_agg_costs_id_seq'::regclass);


--
-- TOC entry 4006 (class 2604 OID 21177)
-- Name: order_costs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs ALTER COLUMN id SET DEFAULT nextval('data.order_costs_id_seq'::regclass);


--
-- TOC entry 4009 (class 2604 OID 21178)
-- Name: order_finish_drivers id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_finish_drivers ALTER COLUMN id SET DEFAULT nextval('data.order_finish_drivers_id_seq'::regclass);


--
-- TOC entry 4010 (class 2604 OID 21179)
-- Name: order_history id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_history ALTER COLUMN id SET DEFAULT nextval('data.order_history_id_seq'::regclass);


--
-- TOC entry 4011 (class 2604 OID 21180)
-- Name: order_locations id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_locations ALTER COLUMN id SET DEFAULT nextval('data.order_locations_id_seq'::regclass);


--
-- TOC entry 4012 (class 2604 OID 21181)
-- Name: order_log id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log ALTER COLUMN id SET DEFAULT nextval('data.order_log_id_seq'::regclass);


--
-- TOC entry 4014 (class 2604 OID 21182)
-- Name: order_ratings id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_ratings ALTER COLUMN id SET DEFAULT nextval('data.order_ratings_id_seq'::regclass);


--
-- TOC entry 4015 (class 2604 OID 21183)
-- Name: order_views id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_views ALTER COLUMN id SET DEFAULT nextval('data.order_views_id_seq'::regclass);


--
-- TOC entry 4016 (class 2604 OID 21184)
-- Name: orders id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders ALTER COLUMN id SET DEFAULT nextval('data.orders_id_seq'::regclass);


--
-- TOC entry 4021 (class 2604 OID 21185)
-- Name: orders_taking id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_taking ALTER COLUMN id SET DEFAULT nextval('data.orders_taking_id_seq'::regclass);


--
-- TOC entry 4022 (class 2604 OID 21186)
-- Name: point_rating id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating ALTER COLUMN id SET DEFAULT nextval('data.point_rating_id_seq'::regclass);


--
-- TOC entry 4024 (class 2604 OID 21187)
-- Name: tariff_costs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariff_costs ALTER COLUMN id SET DEFAULT nextval('data.tariff_costs_id_seq'::regclass);


--
-- TOC entry 4025 (class 2604 OID 21188)
-- Name: tariffs id; Type: DEFAULT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariffs ALTER COLUMN id SET DEFAULT nextval('data.tariffs_id_seq'::regclass);


--
-- TOC entry 4026 (class 2604 OID 21223)
-- Name: SYS_ACTIVITYTYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ACTIVITYTYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_ACTIVITYTYPES_id_seq"'::regclass);


--
-- TOC entry 3950 (class 2604 OID 21224)
-- Name: SYS_CARCLASSES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CARCLASSES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_CARCLASSES_id_seq"'::regclass);


--
-- TOC entry 3952 (class 2604 OID 21225)
-- Name: SYS_CARTYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CARTYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_CARTYPES_id_seq"'::regclass);


--
-- TOC entry 4027 (class 2604 OID 21226)
-- Name: SYS_CONDITION_VALUE_TYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CONDITION_VALUE_TYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_ROUTE_CONDITION_TYPE_id_seq"'::regclass);


--
-- TOC entry 4028 (class 2604 OID 21227)
-- Name: SYS_DOCTYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_DOCTYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_DOCTYPES_id_seq"'::regclass);


--
-- TOC entry 3951 (class 2604 OID 21228)
-- Name: SYS_PAYTYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_PAYTYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_PAYTYPES_id_seq"'::regclass);


--
-- TOC entry 4029 (class 2604 OID 21229)
-- Name: SYS_RESOURCES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_RESOURCES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_RESOURCES_id_seq"'::regclass);


--
-- TOC entry 4030 (class 2604 OID 21230)
-- Name: SYS_ROUTERESTRICTIONS id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTERESTRICTIONS" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_ROUTERESTRICTIONS_id_seq"'::regclass);


--
-- TOC entry 4031 (class 2604 OID 21231)
-- Name: SYS_ROUTE_CONDITION_TYPES id; Type: DEFAULT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTE_CONDITION_TYPES" ALTER COLUMN id SET DEFAULT nextval('sysdata."SYS_ROUTE_CONDITION_TYPES_id_seq"'::regclass);


--
-- TOC entry 4051 (class 2606 OID 19845)
-- Name: distance_for_load distance_for_load_order_id_driver_id_key; Type: CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.distance_for_load
    ADD CONSTRAINT distance_for_load_order_id_driver_id_key UNIQUE (order_id, driver_id);


--
-- TOC entry 4053 (class 2606 OID 19847)
-- Name: distance_for_load distance_for_load_pkey; Type: CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.distance_for_load
    ADD CONSTRAINT distance_for_load_pkey PRIMARY KEY (id);


--
-- TOC entry 4055 (class 2606 OID 19849)
-- Name: driver_last_route driver_last_route_driver_id_key; Type: CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.driver_last_route
    ADD CONSTRAINT driver_last_route_driver_id_key UNIQUE (driver_id);


--
-- TOC entry 4057 (class 2606 OID 19851)
-- Name: driver_last_route driver_last_route_pkey; Type: CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.driver_last_route
    ADD CONSTRAINT driver_last_route_pkey PRIMARY KEY (id);


--
-- TOC entry 4062 (class 2606 OID 19853)
-- Name: addsums_docs addsums_docs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums_docs
    ADD CONSTRAINT addsums_docs_pkey PRIMARY KEY (id);


--
-- TOC entry 4064 (class 2606 OID 19855)
-- Name: addsums_files addsums_files_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums_files
    ADD CONSTRAINT addsums_files_pkey PRIMARY KEY (id);


--
-- TOC entry 4059 (class 2606 OID 19857)
-- Name: addsums addsums_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums
    ADD CONSTRAINT addsums_pkey PRIMARY KEY (id);


--
-- TOC entry 4067 (class 2606 OID 19859)
-- Name: agg_commission agg_commission_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.agg_commission
    ADD CONSTRAINT agg_commission_pkey PRIMARY KEY (id);


--
-- TOC entry 4069 (class 2606 OID 19861)
-- Name: agg_regions agg_regions_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.agg_regions
    ADD CONSTRAINT agg_regions_pkey PRIMARY KEY (id);


--
-- TOC entry 4071 (class 2606 OID 19863)
-- Name: autocreate_logs autocreate_logs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.autocreate_logs
    ADD CONSTRAINT autocreate_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 4079 (class 2606 OID 19865)
-- Name: calendar_final calendar_final_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_final
    ADD CONSTRAINT calendar_final_pkey PRIMARY KEY (id);


--
-- TOC entry 4084 (class 2606 OID 19867)
-- Name: calendar_notifications calendar_notifications_driver_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_notifications
    ADD CONSTRAINT calendar_notifications_driver_id_key UNIQUE (driver_id);


--
-- TOC entry 4086 (class 2606 OID 19869)
-- Name: calendar_notifications calendar_notifications_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_notifications
    ADD CONSTRAINT calendar_notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 4074 (class 2606 OID 19871)
-- Name: calendar calendar_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar
    ADD CONSTRAINT calendar_pkey PRIMARY KEY (id);


--
-- TOC entry 4088 (class 2606 OID 19873)
-- Name: checkpoint_history checkpoint_history_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoint_history
    ADD CONSTRAINT checkpoint_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4092 (class 2606 OID 19875)
-- Name: checkpoints checkpoints_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoints
    ADD CONSTRAINT checkpoints_pkey PRIMARY KEY (id);


--
-- TOC entry 4096 (class 2606 OID 19877)
-- Name: client_point_coordinates client_point_coordinates_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_coordinates
    ADD CONSTRAINT client_point_coordinates_pkey PRIMARY KEY (id);


--
-- TOC entry 4098 (class 2606 OID 19879)
-- Name: client_point_groups client_point_groups_dispatcher_id_code_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_groups
    ADD CONSTRAINT client_point_groups_dispatcher_id_code_key UNIQUE (dispatcher_id, code);


--
-- TOC entry 4100 (class 2606 OID 19881)
-- Name: client_point_groups client_point_groups_dispatcher_id_name_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_groups
    ADD CONSTRAINT client_point_groups_dispatcher_id_name_key UNIQUE (dispatcher_id, name);


--
-- TOC entry 4102 (class 2606 OID 19883)
-- Name: client_point_groups client_point_groups_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_groups
    ADD CONSTRAINT client_point_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4104 (class 2606 OID 19885)
-- Name: client_points client_points_client_id_code_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_client_id_code_key UNIQUE (client_id, code);


--
-- TOC entry 4106 (class 2606 OID 19887)
-- Name: client_points client_points_client_id_gor_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_client_id_gor_key UNIQUE (client_id, google_original);


--
-- TOC entry 4108 (class 2606 OID 19889)
-- Name: client_points client_points_client_id_name_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_client_id_name_key UNIQUE (client_id, name);


--
-- TOC entry 4110 (class 2606 OID 19891)
-- Name: client_points client_points_dispatcher_id_code_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_dispatcher_id_code_key UNIQUE (dispatcher_id, code);


--
-- TOC entry 4112 (class 2606 OID 19893)
-- Name: client_points client_points_dispatcher_id_gor_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_dispatcher_id_gor_key UNIQUE (dispatcher_id, google_original);


--
-- TOC entry 4114 (class 2606 OID 19895)
-- Name: client_points client_points_dispatcher_id_name_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_dispatcher_id_name_key UNIQUE (dispatcher_id, name);


--
-- TOC entry 4117 (class 2606 OID 19897)
-- Name: client_points client_points_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_pkey PRIMARY KEY (id);


--
-- TOC entry 4121 (class 2606 OID 19899)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- TOC entry 4123 (class 2606 OID 19901)
-- Name: clients clients_token_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.clients
    ADD CONSTRAINT clients_token_key UNIQUE (token);


--
-- TOC entry 4127 (class 2606 OID 19903)
-- Name: contracts contracts_dispatcher_id_name_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.contracts
    ADD CONSTRAINT contracts_dispatcher_id_name_key UNIQUE (dispatcher_id, name);


--
-- TOC entry 4129 (class 2606 OID 19905)
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- TOC entry 4131 (class 2606 OID 19907)
-- Name: cost_types cost_types_name_dispatcher_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.cost_types
    ADD CONSTRAINT cost_types_name_dispatcher_id_key UNIQUE (name, dispatcher_id);


--
-- TOC entry 4133 (class 2606 OID 19909)
-- Name: cost_types cost_types_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.cost_types
    ADD CONSTRAINT cost_types_pkey PRIMARY KEY (id);


--
-- TOC entry 4136 (class 2606 OID 19911)
-- Name: dispatcher_dogovor_files dispatcher_dogovor_files_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovor_files
    ADD CONSTRAINT dispatcher_dogovor_files_pkey PRIMARY KEY (id);


--
-- TOC entry 4138 (class 2606 OID 19913)
-- Name: dispatcher_dogovors dispatcher_dogovors_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovors
    ADD CONSTRAINT dispatcher_dogovors_pkey PRIMARY KEY (id);


--
-- TOC entry 4140 (class 2606 OID 19915)
-- Name: dispatcher_favorite_orders dispatcher_favorite_orders_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_favorite_orders
    ADD CONSTRAINT dispatcher_favorite_orders_pkey PRIMARY KEY (id);


--
-- TOC entry 4142 (class 2606 OID 19917)
-- Name: dispatcher_route_calculations dispatcher_route_calculations_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_route_calculations
    ADD CONSTRAINT dispatcher_route_calculations_pkey PRIMARY KEY (id);


--
-- TOC entry 4144 (class 2606 OID 19919)
-- Name: dispatcher_route_calculations dispatcher_route_calculations_route_id_calc_date_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_route_calculations
    ADD CONSTRAINT dispatcher_route_calculations_route_id_calc_date_key UNIQUE (route_id, calc_date);


--
-- TOC entry 4147 (class 2606 OID 19921)
-- Name: dispatcher_routes dispatcher_routes_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_routes
    ADD CONSTRAINT dispatcher_routes_pkey PRIMARY KEY (id);


--
-- TOC entry 4151 (class 2606 OID 19923)
-- Name: dispatcher_selected_drivers dispatcher_selected_drivers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_drivers
    ADD CONSTRAINT dispatcher_selected_drivers_pkey PRIMARY KEY (id);


--
-- TOC entry 4153 (class 2606 OID 19925)
-- Name: dispatcher_selected_drivers dispatcher_selected_drivers_selected_id_driver_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_drivers
    ADD CONSTRAINT dispatcher_selected_drivers_selected_id_driver_id_key UNIQUE (selected_id, driver_id);


--
-- TOC entry 4155 (class 2606 OID 19927)
-- Name: dispatcher_selected_orders dispatcher_selected_orders_order_id_dispatcher_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_orders
    ADD CONSTRAINT dispatcher_selected_orders_order_id_dispatcher_id_key UNIQUE (order_id, dispatcher_id);


--
-- TOC entry 4157 (class 2606 OID 19929)
-- Name: dispatcher_selected_orders dispatcher_selected_orders_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_orders
    ADD CONSTRAINT dispatcher_selected_orders_pkey PRIMARY KEY (id);


--
-- TOC entry 4160 (class 2606 OID 19931)
-- Name: dispatcher_to_client dispatcher_to client_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_to_client
    ADD CONSTRAINT "dispatcher_to client_pkey" PRIMARY KEY (dispatcher_id, client_id);


--
-- TOC entry 4164 (class 2606 OID 19933)
-- Name: dispatchers dispatchers_login_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatchers
    ADD CONSTRAINT dispatchers_login_key UNIQUE (login);


--
-- TOC entry 4166 (class 2606 OID 19935)
-- Name: dispatchers dispatchers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatchers
    ADD CONSTRAINT dispatchers_pkey PRIMARY KEY (id);


--
-- TOC entry 4168 (class 2606 OID 19937)
-- Name: driver_activities driver_activities_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_activities
    ADD CONSTRAINT driver_activities_pkey PRIMARY KEY (id);


--
-- TOC entry 4171 (class 2606 OID 19939)
-- Name: driver_car_docs driver_car_docs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_docs
    ADD CONSTRAINT driver_car_docs_pkey PRIMARY KEY (id);


--
-- TOC entry 4173 (class 2606 OID 19941)
-- Name: driver_car_files driver_car_files_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_files
    ADD CONSTRAINT driver_car_files_pkey PRIMARY KEY (id);


--
-- TOC entry 4175 (class 2606 OID 19943)
-- Name: driver_car_tariffs driver_car_tariffs_driver_car_id_tariff_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_tariffs
    ADD CONSTRAINT driver_car_tariffs_driver_car_id_tariff_id_key UNIQUE (driver_car_id, tariff_id);


--
-- TOC entry 4177 (class 2606 OID 19945)
-- Name: driver_car_tariffs driver_car_tariffs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_tariffs
    ADD CONSTRAINT driver_car_tariffs_pkey PRIMARY KEY (id);


--
-- TOC entry 4179 (class 2606 OID 19947)
-- Name: driver_cars driver_cars_driver_id_cartype_id_carmodel_carnumber_carcolo_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_driver_id_cartype_id_carmodel_carnumber_carcolo_key UNIQUE (driver_id, cartype_id, carmodel, carnumber, carcolor);


--
-- TOC entry 4181 (class 2606 OID 19949)
-- Name: driver_cars driver_cars_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_pkey PRIMARY KEY (id);


--
-- TOC entry 4187 (class 2606 OID 19951)
-- Name: driver_costs driver_costs_driver_id_cost_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_costs
    ADD CONSTRAINT driver_costs_driver_id_cost_id_key UNIQUE (driver_id, cost_id);


--
-- TOC entry 4189 (class 2606 OID 19953)
-- Name: driver_costs driver_costs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_costs
    ADD CONSTRAINT driver_costs_pkey PRIMARY KEY (id);


--
-- TOC entry 4191 (class 2606 OID 19955)
-- Name: driver_current_locations driver_current_locations_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_current_locations
    ADD CONSTRAINT driver_current_locations_pkey PRIMARY KEY (driver_id);


--
-- TOC entry 4193 (class 2606 OID 19957)
-- Name: driver_devices driver_devices_driver_id_device_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_devices
    ADD CONSTRAINT driver_devices_driver_id_device_id_key UNIQUE (driver_id, device_id);


--
-- TOC entry 4195 (class 2606 OID 19959)
-- Name: driver_devices driver_devices_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_devices
    ADD CONSTRAINT driver_devices_pkey PRIMARY KEY (id);


--
-- TOC entry 4197 (class 2606 OID 19961)
-- Name: driver_docs driver_docs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_docs
    ADD CONSTRAINT driver_docs_pkey PRIMARY KEY (id);


--
-- TOC entry 4199 (class 2606 OID 19963)
-- Name: driver_files driver_files_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_files
    ADD CONSTRAINT driver_files_pkey PRIMARY KEY (id);


--
-- TOC entry 4201 (class 2606 OID 19965)
-- Name: driver_history_locations driver_history_locations_driver_id_loc_time_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_history_locations
    ADD CONSTRAINT driver_history_locations_driver_id_loc_time_key UNIQUE (driver_id, loc_time);


--
-- TOC entry 4207 (class 2606 OID 19970)
-- Name: driver_stops driver_stops_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_stops
    ADD CONSTRAINT driver_stops_pkey PRIMARY KEY (id);


--
-- TOC entry 4185 (class 2606 OID 19972)
-- Name: driver_corrections drivers_corrections_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_corrections
    ADD CONSTRAINT drivers_corrections_pkey PRIMARY KEY (id);


--
-- TOC entry 4209 (class 2606 OID 19974)
-- Name: drivers drivers_login_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers
    ADD CONSTRAINT drivers_login_key UNIQUE (login);


--
-- TOC entry 4211 (class 2606 OID 19976)
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (id);


--
-- TOC entry 4220 (class 2606 OID 19978)
-- Name: feedback_docs feedback_docs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback_docs
    ADD CONSTRAINT feedback_docs_pkey PRIMARY KEY (id);


--
-- TOC entry 4222 (class 2606 OID 19980)
-- Name: feedback_files feedback_files_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback_files
    ADD CONSTRAINT feedback_files_pkey PRIMARY KEY (id);


--
-- TOC entry 4217 (class 2606 OID 19982)
-- Name: feedback feedback_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback
    ADD CONSTRAINT feedback_pkey PRIMARY KEY (id);


--
-- TOC entry 4225 (class 2606 OID 19984)
-- Name: finances_log finances_log_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.finances_log
    ADD CONSTRAINT finances_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4045 (class 2606 OID 19986)
-- Name: google_addresses google_addresses_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_addresses
    ADD CONSTRAINT google_addresses_pkey PRIMARY KEY (id);


--
-- TOC entry 4228 (class 2606 OID 19988)
-- Name: google_modifiers google_modifiers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_modifiers
    ADD CONSTRAINT google_modifiers_pkey PRIMARY KEY (id);


--
-- TOC entry 4047 (class 2606 OID 19990)
-- Name: google_originals google_originals_address_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_originals
    ADD CONSTRAINT google_originals_address_key UNIQUE (address);


--
-- TOC entry 4049 (class 2606 OID 19992)
-- Name: google_originals google_originals_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_originals
    ADD CONSTRAINT google_originals_pkey PRIMARY KEY (id);


--
-- TOC entry 4231 (class 2606 OID 19994)
-- Name: log log_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- TOC entry 4234 (class 2606 OID 19996)
-- Name: money_requests money_requests_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.money_requests
    ADD CONSTRAINT money_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 4236 (class 2606 OID 19998)
-- Name: options options_dispatcher_param_name_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options
    ADD CONSTRAINT options_dispatcher_param_name_key UNIQUE (dispatcher_id, param_name);


--
-- TOC entry 4238 (class 2606 OID 20000)
-- Name: options options_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options
    ADD CONSTRAINT options_pkey PRIMARY KEY (id);


--
-- TOC entry 4240 (class 2606 OID 20002)
-- Name: options_sections options_sections_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options_sections
    ADD CONSTRAINT options_sections_pkey PRIMARY KEY (id);


--
-- TOC entry 4242 (class 2606 OID 20004)
-- Name: order_agg_costs order_agg_costs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_agg_costs
    ADD CONSTRAINT order_agg_costs_pkey PRIMARY KEY (id);


--
-- TOC entry 4244 (class 2606 OID 20006)
-- Name: order_costs order_costs_order_id_cost_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs
    ADD CONSTRAINT order_costs_order_id_cost_id_key UNIQUE (order_id, cost_id);


--
-- TOC entry 4246 (class 2606 OID 20008)
-- Name: order_costs order_costs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs
    ADD CONSTRAINT order_costs_pkey PRIMARY KEY (id);


--
-- TOC entry 4249 (class 2606 OID 20010)
-- Name: order_exec_clients order_exec_clients_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_clients
    ADD CONSTRAINT order_exec_clients_pkey PRIMARY KEY (id);


--
-- TOC entry 4252 (class 2606 OID 20012)
-- Name: order_exec_dispatchers order_exec_dispatchers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_dispatchers
    ADD CONSTRAINT order_exec_dispatchers_pkey PRIMARY KEY (id);


--
-- TOC entry 4255 (class 2606 OID 20014)
-- Name: order_finish_drivers order_finish_drivers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_finish_drivers
    ADD CONSTRAINT order_finish_drivers_pkey PRIMARY KEY (id);


--
-- TOC entry 4259 (class 2606 OID 20016)
-- Name: order_history order_history_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_history
    ADD CONSTRAINT order_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4262 (class 2606 OID 20018)
-- Name: order_locations order_locations_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_locations
    ADD CONSTRAINT order_locations_pkey PRIMARY KEY (id);


--
-- TOC entry 4265 (class 2606 OID 20035)
-- Name: order_log order_log_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4268 (class 2606 OID 20037)
-- Name: order_not_exec_dispatchers order_not_exec_dispatchers_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_not_exec_dispatchers
    ADD CONSTRAINT order_not_exec_dispatchers_pkey PRIMARY KEY (id);


--
-- TOC entry 4270 (class 2606 OID 20039)
-- Name: order_ratings order_ratings_order_id_rating_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_ratings
    ADD CONSTRAINT order_ratings_order_id_rating_id_key UNIQUE (order_id, rating_id);


--
-- TOC entry 4272 (class 2606 OID 20041)
-- Name: order_ratings order_ratings_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_ratings
    ADD CONSTRAINT order_ratings_pkey PRIMARY KEY (id);


--
-- TOC entry 4275 (class 2606 OID 20043)
-- Name: order_views order_views_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_views
    ADD CONSTRAINT order_views_pkey PRIMARY KEY (id);


--
-- TOC entry 4293 (class 2606 OID 20045)
-- Name: orders_appointing orders_appointing_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_appointing
    ADD CONSTRAINT orders_appointing_pkey PRIMARY KEY (id);


--
-- TOC entry 4296 (class 2606 OID 20047)
-- Name: orders_canceling orders_canceling_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_canceling
    ADD CONSTRAINT orders_canceling_pkey PRIMARY KEY (id);


--
-- TOC entry 4290 (class 2606 OID 20049)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- TOC entry 4299 (class 2606 OID 20051)
-- Name: orders_rejecting orders_rejecting_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_rejecting
    ADD CONSTRAINT orders_rejecting_pkey PRIMARY KEY (id);


--
-- TOC entry 4302 (class 2606 OID 20053)
-- Name: orders_revoking orders_revoking_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_revoking
    ADD CONSTRAINT orders_revoking_pkey PRIMARY KEY (id);


--
-- TOC entry 4305 (class 2606 OID 20055)
-- Name: orders_taking orders_taking_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_taking
    ADD CONSTRAINT orders_taking_pkey PRIMARY KEY (id);


--
-- TOC entry 4307 (class 2606 OID 20057)
-- Name: point_rating point_rating_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating
    ADD CONSTRAINT point_rating_pkey PRIMARY KEY (id);


--
-- TOC entry 4309 (class 2606 OID 20059)
-- Name: point_rating point_rating_point_id_driver_id_order_id_key; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating
    ADD CONSTRAINT point_rating_point_id_driver_id_order_id_key UNIQUE (point_id, driver_id, order_id);


--
-- TOC entry 4315 (class 2606 OID 20061)
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (id);


--
-- TOC entry 4317 (class 2606 OID 20063)
-- Name: tariff_costs tariff_costs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariff_costs
    ADD CONSTRAINT tariff_costs_pkey PRIMARY KEY (id);


--
-- TOC entry 4319 (class 2606 OID 20065)
-- Name: tariffs tariffs_pkey; Type: CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariffs
    ADD CONSTRAINT tariffs_pkey PRIMARY KEY (id);


--
-- TOC entry 4321 (class 2606 OID 20157)
-- Name: SYS_ACTIVITYTYPES SYS_ACTIVITYTYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ACTIVITYTYPES"
    ADD CONSTRAINT "SYS_ACTIVITYTYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4323 (class 2606 OID 20159)
-- Name: SYS_AUTOCREATETYPES SYS_AUTOCREATETYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_AUTOCREATETYPES"
    ADD CONSTRAINT "SYS_AUTOCREATETYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4033 (class 2606 OID 20161)
-- Name: SYS_CARCLASSES SYS_CARCLASSES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CARCLASSES"
    ADD CONSTRAINT "SYS_CARCLASSES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4037 (class 2606 OID 20163)
-- Name: SYS_CARTYPES SYS_CARTYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CARTYPES"
    ADD CONSTRAINT "SYS_CARTYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4327 (class 2606 OID 20165)
-- Name: SYS_DAYTYPES SYS_DAYTYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_DAYTYPES"
    ADD CONSTRAINT "SYS_DAYTYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4329 (class 2606 OID 20167)
-- Name: SYS_DOCTYPES SYS_DOCTYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_DOCTYPES"
    ADD CONSTRAINT "SYS_DOCTYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4331 (class 2606 OID 20169)
-- Name: SYS_DOGOVOR_TYPES SYS_DOGOVOR_TYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_DOGOVOR_TYPES"
    ADD CONSTRAINT "SYS_DOGOVOR_TYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4040 (class 2606 OID 20171)
-- Name: SYS_DRIVERLEVELS SYS_DRIVERLEVELS_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_DRIVERLEVELS"
    ADD CONSTRAINT "SYS_DRIVERLEVELS_pkey" PRIMARY KEY (id);


--
-- TOC entry 4333 (class 2606 OID 20173)
-- Name: SYS_ORDERSTATUS SYS_ORDERSTATUS_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ORDERSTATUS"
    ADD CONSTRAINT "SYS_ORDERSTATUS_pkey" PRIMARY KEY (id);


--
-- TOC entry 4335 (class 2606 OID 20175)
-- Name: SYS_PARAMS SYS_PARAMS_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_PARAMS"
    ADD CONSTRAINT "SYS_PARAMS_pkey" PRIMARY KEY (param_name);


--
-- TOC entry 4035 (class 2606 OID 20177)
-- Name: SYS_PAYTYPES SYS_PAYTYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_PAYTYPES"
    ADD CONSTRAINT "SYS_PAYTYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4337 (class 2606 OID 20179)
-- Name: SYS_RESOURCES SYS_RESOURCES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_RESOURCES"
    ADD CONSTRAINT "SYS_RESOURCES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4339 (class 2606 OID 20181)
-- Name: SYS_RESOURCES SYS_RESOURCES_resource_id_country_code_key; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_RESOURCES"
    ADD CONSTRAINT "SYS_RESOURCES_resource_id_country_code_key" UNIQUE (resource_id, country_code);


--
-- TOC entry 4341 (class 2606 OID 20183)
-- Name: SYS_ROUTECALC_TYPES SYS_ROUTECALC_TYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTECALC_TYPES"
    ADD CONSTRAINT "SYS_ROUTECALC_TYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4343 (class 2606 OID 20185)
-- Name: SYS_ROUTERATING_PARAMS SYS_ROUTERATING_PARAMS_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTERATING_PARAMS"
    ADD CONSTRAINT "SYS_ROUTERATING_PARAMS_pkey" PRIMARY KEY (id);


--
-- TOC entry 4345 (class 2606 OID 20187)
-- Name: SYS_ROUTERESTRICTIONS SYS_ROUTERESTRICTIONS_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTERESTRICTIONS"
    ADD CONSTRAINT "SYS_ROUTERESTRICTIONS_pkey" PRIMARY KEY (id);


--
-- TOC entry 4347 (class 2606 OID 20189)
-- Name: SYS_ROUTETYPES SYS_ROUTETYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTETYPES"
    ADD CONSTRAINT "SYS_ROUTETYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4349 (class 2606 OID 20191)
-- Name: SYS_ROUTE_CONDITION_TYPES SYS_ROUTE_CONDITION_TYPES_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTE_CONDITION_TYPES"
    ADD CONSTRAINT "SYS_ROUTE_CONDITION_TYPES_pkey" PRIMARY KEY (id);


--
-- TOC entry 4325 (class 2606 OID 20193)
-- Name: SYS_CONDITION_VALUE_TYPES SYS_ROUTE_CONDITION_TYPE_pkey; Type: CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CONDITION_VALUE_TYPES"
    ADD CONSTRAINT "SYS_ROUTE_CONDITION_TYPE_pkey" PRIMARY KEY (id);


--
-- TOC entry 4065 (class 1259 OID 20194)
-- Name: agg_commission_begin_date_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX agg_commission_begin_date_idx ON data.agg_commission USING btree (begin_date);


--
-- TOC entry 4115 (class 1259 OID 20195)
-- Name: client_points_idx_code; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX client_points_idx_code ON data.client_points USING btree (client_id, code);


--
-- TOC entry 4310 (class 1259 OID 20196)
-- Name: client_route_name; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX client_route_name ON data.routes USING btree (client_id, upper(name));


--
-- TOC entry 4232 (class 1259 OID 20197)
-- Name: datetime_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX datetime_idx ON data.money_requests USING btree (datetime);


--
-- TOC entry 4183 (class 1259 OID 20198)
-- Name: driver_corrections_datetime_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX driver_corrections_datetime_idx ON data.driver_corrections USING btree (datetime);


--
-- TOC entry 4205 (class 1259 OID 20199)
-- Name: driver_stops_datetime_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX driver_stops_datetime_idx ON data.driver_stops USING btree (datetime);


--
-- TOC entry 4212 (class 1259 OID 20200)
-- Name: family_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX family_idx ON data.drivers USING btree (family_name);


--
-- TOC entry 4223 (class 1259 OID 20201)
-- Name: finances_log_idx_datetime; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX finances_log_idx_datetime ON data.finances_log USING btree (datetime);


--
-- TOC entry 4072 (class 1259 OID 20202)
-- Name: fki_autocreate_logs_type_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_autocreate_logs_type_id_fkey ON data.autocreate_logs USING btree (type_id);


--
-- TOC entry 4089 (class 1259 OID 20203)
-- Name: fki_checkpoint_history_client; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_checkpoint_history_client ON data.checkpoint_history USING btree (client_id);


--
-- TOC entry 4090 (class 1259 OID 20204)
-- Name: fki_checkpoint_history_point; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_checkpoint_history_point ON data.checkpoint_history USING btree (point_id);


--
-- TOC entry 4093 (class 1259 OID 20205)
-- Name: fki_checkpoint_order; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_checkpoint_order ON data.checkpoints USING btree (order_id);


--
-- TOC entry 4094 (class 1259 OID 20206)
-- Name: fki_checkpoint_point; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_checkpoint_point ON data.checkpoints USING btree (to_point_id);


--
-- TOC entry 4118 (class 1259 OID 20207)
-- Name: fki_client_points_dispatcher_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_client_points_dispatcher_id_fkey ON data.client_points USING btree (dispatcher_id);


--
-- TOC entry 4119 (class 1259 OID 20208)
-- Name: fki_client_points_group_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_client_points_group_id_fkey ON data.client_points USING btree (group_id);


--
-- TOC entry 4124 (class 1259 OID 20209)
-- Name: fki_clients_dispatcher_id; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_clients_dispatcher_id ON data.clients USING btree (default_dispatcher_id);


--
-- TOC entry 4148 (class 1259 OID 20210)
-- Name: fki_dispatcher_routes_client_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_dispatcher_routes_client_id_fkey ON data.dispatcher_routes USING btree (client_id);


--
-- TOC entry 4158 (class 1259 OID 20211)
-- Name: fki_dispatcher_selected_orders_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_dispatcher_selected_orders_id_fkey ON data.dispatcher_selected_orders USING btree (order_id);


--
-- TOC entry 4161 (class 1259 OID 20212)
-- Name: fki_dispatcher_to client_client_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX "fki_dispatcher_to client_client_id_fkey" ON data.dispatcher_to_client USING btree (client_id);


--
-- TOC entry 4162 (class 1259 OID 20213)
-- Name: fki_dispatcher_to client_dispatcher_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX "fki_dispatcher_to client_dispatcher_id_fkey" ON data.dispatcher_to_client USING btree (dispatcher_id);


--
-- TOC entry 4169 (class 1259 OID 20214)
-- Name: fki_driver_activities_type_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_driver_activities_type_fkey ON data.driver_activities USING btree (type_id);


--
-- TOC entry 4182 (class 1259 OID 20215)
-- Name: fki_driver_cars_tariff_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_driver_cars_tariff_id_fkey ON data.driver_cars USING btree (tariff_id);


--
-- TOC entry 4213 (class 1259 OID 20216)
-- Name: fki_drivers_contract_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_drivers_contract_id_fkey ON data.drivers USING btree (contract_id);


--
-- TOC entry 4041 (class 1259 OID 20217)
-- Name: fki_google_addresses_client_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_google_addresses_client_id_fkey ON data.google_addresses USING btree (client_id);


--
-- TOC entry 4042 (class 1259 OID 20218)
-- Name: fki_google_addresses_dispatcher_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_google_addresses_dispatcher_id_fkey ON data.google_addresses USING btree (dispatcher_id);


--
-- TOC entry 4226 (class 1259 OID 20219)
-- Name: fki_google_modifiers_dispatcher_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_google_modifiers_dispatcher_id_fkey ON data.google_modifiers USING btree (dispatcher_id);


--
-- TOC entry 4202 (class 1259 OID 20220)
-- Name: fki_location_device; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_location_device ON data.driver_history_locations USING btree (device_id);


--
-- TOC entry 4203 (class 1259 OID 20228)
-- Name: fki_location_driver; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_location_driver ON data.driver_history_locations USING btree (driver_id);


--
-- TOC entry 4276 (class 1259 OID 20229)
-- Name: fki_order_cartype; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_cartype ON data.orders USING btree (carclass_id);


--
-- TOC entry 4277 (class 1259 OID 20230)
-- Name: fki_order_created_by_dispatcher; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_created_by_dispatcher ON data.orders USING btree (created_by_dispatcher_id);


--
-- TOC entry 4278 (class 1259 OID 20231)
-- Name: fki_order_dispatcher; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_dispatcher ON data.orders USING btree (dispatcher_id);


--
-- TOC entry 4279 (class 1259 OID 20232)
-- Name: fki_order_driver; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_driver ON data.orders USING btree (driver_id);


--
-- TOC entry 4280 (class 1259 OID 20233)
-- Name: fki_order_end_device; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_end_device ON data.orders USING btree (end_device_id);


--
-- TOC entry 4256 (class 1259 OID 20234)
-- Name: fki_order_history_client; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_history_client ON data.order_history USING btree (client_id);


--
-- TOC entry 4257 (class 1259 OID 20235)
-- Name: fki_order_history_point; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_history_point ON data.order_history USING btree (point_id);


--
-- TOC entry 4281 (class 1259 OID 20236)
-- Name: fki_order_paytype; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_paytype ON data.orders USING btree (paytype_id);


--
-- TOC entry 4282 (class 1259 OID 20237)
-- Name: fki_order_status; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_order_status ON data.orders USING btree (status_id);


--
-- TOC entry 4283 (class 1259 OID 20238)
-- Name: fki_orders_dispatcher_route_id; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_orders_dispatcher_route_id ON data.orders USING btree (dispatcher_route_id);


--
-- TOC entry 4311 (class 1259 OID 20239)
-- Name: fki_routes_dispatcher_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_routes_dispatcher_id_fkey ON data.routes USING btree (dispatcher_id);


--
-- TOC entry 4312 (class 1259 OID 20240)
-- Name: fki_routes_type_id_fkey; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX fki_routes_type_id_fkey ON data.routes USING btree (type_id);


--
-- TOC entry 4043 (class 1259 OID 20241)
-- Name: ga_address; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX ga_address ON data.google_addresses USING btree (upper(address), client_id);


--
-- TOC entry 4060 (class 1259 OID 20242)
-- Name: idx_addoperdate; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_addoperdate ON data.addsums USING btree (operdate);


--
-- TOC entry 4075 (class 1259 OID 20243)
-- Name: idx_calendar_cdate; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_calendar_cdate ON data.calendar USING btree (cdate);


--
-- TOC entry 4076 (class 1259 OID 20244)
-- Name: idx_calendar_driver_cdate_uni; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX idx_calendar_driver_cdate_uni ON data.calendar USING btree (dispatcher_id, driver_id, cdate) WHERE (driver_id IS NOT NULL);


--
-- TOC entry 4080 (class 1259 OID 20245)
-- Name: idx_calendar_final_cdate; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_calendar_final_cdate ON data.calendar_final USING btree (cdate);


--
-- TOC entry 4081 (class 1259 OID 20246)
-- Name: idx_calendar_final_driver_cdate_uni; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX idx_calendar_final_driver_cdate_uni ON data.calendar_final USING btree (dispatcher_id, driver_id, cdate) WHERE (driver_id IS NOT NULL);


--
-- TOC entry 4082 (class 1259 OID 20247)
-- Name: idx_calendar_final_route_cdate_uni; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX idx_calendar_final_route_cdate_uni ON data.calendar_final USING btree (dispatcher_id, route_id, cdate) WHERE (route_id IS NOT NULL);


--
-- TOC entry 4077 (class 1259 OID 20248)
-- Name: idx_calendar_route_cdate_uni; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX idx_calendar_route_cdate_uni ON data.calendar USING btree (dispatcher_id, route_id, cdate) WHERE (route_id IS NOT NULL);


--
-- TOC entry 4125 (class 1259 OID 20249)
-- Name: idx_clients_token; Type: INDEX; Schema: data; Owner: postgres
--

CREATE UNIQUE INDEX idx_clients_token ON data.clients USING btree (token);


--
-- TOC entry 4134 (class 1259 OID 20250)
-- Name: idx_cost_type_name; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_cost_type_name ON data.cost_types USING btree (name);


--
-- TOC entry 4229 (class 1259 OID 20251)
-- Name: idx_datetime; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_datetime ON data.log USING btree (datetime);


--
-- TOC entry 4149 (class 1259 OID 20252)
-- Name: idx_dispatcher_routes_name; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_dispatcher_routes_name ON data.dispatcher_routes USING btree (name);


--
-- TOC entry 4284 (class 1259 OID 20253)
-- Name: idx_from_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_from_time ON data.orders USING btree (from_time);


--
-- TOC entry 4218 (class 1259 OID 20254)
-- Name: idx_operdate; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_operdate ON data.feedback USING btree (operdate);


--
-- TOC entry 4291 (class 1259 OID 20255)
-- Name: idx_order_appointing_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_appointing_time ON data.orders_appointing USING btree (appoint_order);


--
-- TOC entry 4294 (class 1259 OID 20256)
-- Name: idx_order_canceling_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_canceling_time ON data.orders_canceling USING btree (cancel_order);


--
-- TOC entry 4285 (class 1259 OID 20257)
-- Name: idx_order_client_code; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_client_code ON data.orders USING btree (client_id, client_code);


--
-- TOC entry 4260 (class 1259 OID 20258)
-- Name: idx_order_location_datetime; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_location_datetime ON data.order_locations USING btree (datetime);


--
-- TOC entry 4297 (class 1259 OID 20270)
-- Name: idx_order_rejecting_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_rejecting_time ON data.orders_rejecting USING btree (reject_order);


--
-- TOC entry 4303 (class 1259 OID 20271)
-- Name: idx_order_taking_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_taking_time ON data.orders_taking USING btree (take_order);


--
-- TOC entry 4286 (class 1259 OID 20272)
-- Name: idx_order_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_time ON data.orders USING btree (order_time);


--
-- TOC entry 4287 (class 1259 OID 20273)
-- Name: idx_order_title; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_title ON data.orders USING btree (upper((order_title)::text));


--
-- TOC entry 4273 (class 1259 OID 20274)
-- Name: idx_order_view_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_order_view_time ON data.order_views USING btree (timeview);


--
-- TOC entry 4247 (class 1259 OID 20275)
-- Name: idx_orders_exec_clients_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_orders_exec_clients_time ON data.order_exec_clients USING btree (exec_order);


--
-- TOC entry 4250 (class 1259 OID 20276)
-- Name: idx_orders_exec_dispatchers_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_orders_exec_dispatchers_time ON data.order_exec_dispatchers USING btree (exec_order);


--
-- TOC entry 4253 (class 1259 OID 20277)
-- Name: idx_orders_finish_drivers_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_orders_finish_drivers_time ON data.order_finish_drivers USING btree (finish_order);


--
-- TOC entry 4266 (class 1259 OID 20278)
-- Name: idx_orders_not_exec_dispatchers_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_orders_not_exec_dispatchers_time ON data.order_not_exec_dispatchers USING btree (not_exec_order);


--
-- TOC entry 4300 (class 1259 OID 20279)
-- Name: idx_orders_revoking_time; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_orders_revoking_time ON data.orders_revoking USING btree (revoke_order);


--
-- TOC entry 4145 (class 1259 OID 20280)
-- Name: idx_route_calc_date; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX idx_route_calc_date ON data.dispatcher_route_calculations USING btree (calc_date DESC NULLS LAST);


--
-- TOC entry 4204 (class 1259 OID 20281)
-- Name: loc_time_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX loc_time_idx ON data.driver_history_locations USING btree (loc_time DESC NULLS LAST);


--
-- TOC entry 4214 (class 1259 OID 20282)
-- Name: name_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX name_idx ON data.drivers USING btree (name);


--
-- TOC entry 4263 (class 1259 OID 20283)
-- Name: order_log_idx_datetime; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX order_log_idx_datetime ON data.order_log USING btree (datetime);


--
-- TOC entry 4288 (class 1259 OID 20284)
-- Name: order_point; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX order_point ON data.orders USING btree (point_id);


--
-- TOC entry 4313 (class 1259 OID 20285)
-- Name: route_name; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX route_name ON data.routes USING btree (upper(name));


--
-- TOC entry 4215 (class 1259 OID 20286)
-- Name: second_name_idx; Type: INDEX; Schema: data; Owner: postgres
--

CREATE INDEX second_name_idx ON data.drivers USING btree (second_name);


--
-- TOC entry 4038 (class 1259 OID 20335)
-- Name: fki_type_class; Type: INDEX; Schema: sysdata; Owner: postgres
--

CREATE INDEX fki_type_class ON sysdata."SYS_CARTYPES" USING btree (class_id);


--
-- TOC entry 4511 (class 2620 OID 20336)
-- Name: orders assignment_d; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER assignment_d AFTER DELETE ON data.orders FOR EACH ROW EXECUTE PROCEDURE data.driver_route_delete_assignment();


--
-- TOC entry 4508 (class 2620 OID 20337)
-- Name: drivers assignment_iu; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER assignment_iu AFTER INSERT OR UPDATE ON data.drivers FOR EACH ROW EXECUTE PROCEDURE data.driver_update_assignment();


--
-- TOC entry 4512 (class 2620 OID 20338)
-- Name: orders assignment_iu; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER assignment_iu AFTER INSERT OR UPDATE ON data.orders FOR EACH ROW EXECUTE PROCEDURE data.order_update_assignment();


--
-- TOC entry 4513 (class 2620 OID 20339)
-- Name: orders assignment_u; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER assignment_u AFTER UPDATE ON data.orders FOR EACH ROW EXECUTE PROCEDURE data.driver_route_update_assignment();


--
-- TOC entry 4506 (class 2620 OID 20340)
-- Name: dispatcher_selected_orders assignment_update; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER assignment_update BEFORE INSERT OR UPDATE ON data.dispatcher_selected_orders FOR EACH ROW EXECUTE PROCEDURE data.dso_update_assignment();


--
-- TOC entry 4509 (class 2620 OID 20341)
-- Name: drivers calendar_index_i; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER calendar_index_i BEFORE INSERT ON data.drivers FOR EACH ROW EXECUTE PROCEDURE data.driver_insert_calendar_index();


--
-- TOC entry 4507 (class 2620 OID 20342)
-- Name: dispatchers tr_before_update; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER tr_before_update BEFORE UPDATE ON data.dispatchers FOR EACH ROW EXECUTE PROCEDURE data.deny_update_login();

ALTER TABLE data.dispatchers DISABLE TRIGGER tr_before_update;


--
-- TOC entry 4510 (class 2620 OID 20343)
-- Name: drivers tr_before_update; Type: TRIGGER; Schema: data; Owner: postgres
--

CREATE TRIGGER tr_before_update BEFORE UPDATE ON data.drivers FOR EACH ROW EXECUTE PROCEDURE data.deny_update_login();

ALTER TABLE data.drivers DISABLE TRIGGER tr_before_update;


--
-- TOC entry 4504 (class 2620 OID 20344)
-- Name: SYS_DRIVERLEVELS tr_before_delete_driver_level; Type: TRIGGER; Schema: sysdata; Owner: postgres
--

CREATE TRIGGER tr_before_delete_driver_level BEFORE DELETE ON sysdata."SYS_DRIVERLEVELS" FOR EACH ROW EXECUTE PROCEDURE sysdata.before_delete_driver_level();


--
-- TOC entry 4505 (class 2620 OID 20345)
-- Name: SYS_DRIVERLEVELS tr_before_update_driver_level; Type: TRIGGER; Schema: sysdata; Owner: postgres
--

CREATE TRIGGER tr_before_update_driver_level BEFORE UPDATE ON sysdata."SYS_DRIVERLEVELS" FOR EACH ROW EXECUTE PROCEDURE sysdata.before_update_driver_level();


--
-- TOC entry 4354 (class 2606 OID 20346)
-- Name: distance_for_load distance_for_load_driver_id_fkey; Type: FK CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.distance_for_load
    ADD CONSTRAINT distance_for_load_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4355 (class 2606 OID 20351)
-- Name: distance_for_load distance_for_load_order_id_fkey; Type: FK CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.distance_for_load
    ADD CONSTRAINT distance_for_load_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4356 (class 2606 OID 20356)
-- Name: driver_last_route driver_last_route_driver_id_fkey; Type: FK CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.driver_last_route
    ADD CONSTRAINT driver_last_route_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4357 (class 2606 OID 20361)
-- Name: driver_last_route driver_last_route_route_id_fkey; Type: FK CONSTRAINT; Schema: assignment; Owner: postgres
--

ALTER TABLE ONLY assignment.driver_last_route
    ADD CONSTRAINT driver_last_route_route_id_fkey FOREIGN KEY (route_id) REFERENCES data.routes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4358 (class 2606 OID 20366)
-- Name: addsums addsums_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums
    ADD CONSTRAINT addsums_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4360 (class 2606 OID 20371)
-- Name: addsums_docs addsums_docs_addsum_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums_docs
    ADD CONSTRAINT addsums_docs_addsum_id_fkey FOREIGN KEY (addsum_id) REFERENCES data.addsums(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4359 (class 2606 OID 20376)
-- Name: addsums addsums_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums
    ADD CONSTRAINT addsums_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4361 (class 2606 OID 20381)
-- Name: addsums_files addsums_files_doc_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.addsums_files
    ADD CONSTRAINT addsums_files_doc_id_fkey FOREIGN KEY (doc_id) REFERENCES data.addsums_docs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4362 (class 2606 OID 20386)
-- Name: autocreate_logs autocreate_logs_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.autocreate_logs
    ADD CONSTRAINT autocreate_logs_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4363 (class 2606 OID 20391)
-- Name: autocreate_logs autocreate_logs_type_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.autocreate_logs
    ADD CONSTRAINT autocreate_logs_type_id_fkey FOREIGN KEY (type_id) REFERENCES sysdata."SYS_AUTOCREATETYPES"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4364 (class 2606 OID 20396)
-- Name: calendar calendar_daytype_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar
    ADD CONSTRAINT calendar_daytype_id_fkey FOREIGN KEY (daytype_id) REFERENCES sysdata."SYS_DAYTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4365 (class 2606 OID 20401)
-- Name: calendar calendar_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar
    ADD CONSTRAINT calendar_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4366 (class 2606 OID 20406)
-- Name: calendar calendar_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar
    ADD CONSTRAINT calendar_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4368 (class 2606 OID 20411)
-- Name: calendar_final calendar_final_daytype_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_final
    ADD CONSTRAINT calendar_final_daytype_id_fkey FOREIGN KEY (daytype_id) REFERENCES sysdata."SYS_DAYTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4369 (class 2606 OID 20416)
-- Name: calendar_final calendar_final_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_final
    ADD CONSTRAINT calendar_final_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4370 (class 2606 OID 20421)
-- Name: calendar_final calendar_final_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_final
    ADD CONSTRAINT calendar_final_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4371 (class 2606 OID 20426)
-- Name: calendar_final calendar_final_route_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_final
    ADD CONSTRAINT calendar_final_route_id_fkey FOREIGN KEY (route_id) REFERENCES data.dispatcher_routes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4372 (class 2606 OID 20431)
-- Name: calendar_notifications calendar_notifications_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar_notifications
    ADD CONSTRAINT calendar_notifications_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4367 (class 2606 OID 20436)
-- Name: calendar calendar_route_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.calendar
    ADD CONSTRAINT calendar_route_id_fkey FOREIGN KEY (route_id) REFERENCES data.dispatcher_routes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4373 (class 2606 OID 20441)
-- Name: checkpoint_history checkpoint_history_client; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoint_history
    ADD CONSTRAINT checkpoint_history_client FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4374 (class 2606 OID 20446)
-- Name: checkpoint_history checkpoint_history_point; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoint_history
    ADD CONSTRAINT checkpoint_history_point FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4375 (class 2606 OID 20451)
-- Name: checkpoints checkpoint_order; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoints
    ADD CONSTRAINT checkpoint_order FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4376 (class 2606 OID 20456)
-- Name: checkpoints checkpoint_point; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.checkpoints
    ADD CONSTRAINT checkpoint_point FOREIGN KEY (to_point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4377 (class 2606 OID 20461)
-- Name: client_point_coordinates client_point_coordinates_point_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_coordinates
    ADD CONSTRAINT client_point_coordinates_point_id_fkey FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4378 (class 2606 OID 20466)
-- Name: client_point_groups client_point_groups_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_point_groups
    ADD CONSTRAINT client_point_groups_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4379 (class 2606 OID 20471)
-- Name: client_points client_points_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4380 (class 2606 OID 20476)
-- Name: client_points client_points_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4381 (class 2606 OID 20481)
-- Name: client_points client_points_group_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.client_points
    ADD CONSTRAINT client_points_group_id_fkey FOREIGN KEY (group_id) REFERENCES data.client_point_groups(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4382 (class 2606 OID 20486)
-- Name: clients clients_default_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.clients
    ADD CONSTRAINT clients_default_dispatcher_id_fkey FOREIGN KEY (default_dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4383 (class 2606 OID 20491)
-- Name: contracts contracts_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.contracts
    ADD CONSTRAINT contracts_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4384 (class 2606 OID 20496)
-- Name: cost_types cost_types_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.cost_types
    ADD CONSTRAINT cost_types_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4385 (class 2606 OID 20501)
-- Name: dispatcher_dogovor_files dispatcher_dogovor_files_dogovor_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovor_files
    ADD CONSTRAINT dispatcher_dogovor_files_dogovor_id_fkey FOREIGN KEY (dogovor_id) REFERENCES data.dispatcher_dogovors(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4386 (class 2606 OID 20506)
-- Name: dispatcher_dogovors dispatcher_dogovors_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovors
    ADD CONSTRAINT dispatcher_dogovors_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4387 (class 2606 OID 20511)
-- Name: dispatcher_dogovors dispatcher_dogovors_type_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_dogovors
    ADD CONSTRAINT dispatcher_dogovors_type_id_fkey FOREIGN KEY (type_id) REFERENCES sysdata."SYS_DOGOVOR_TYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4388 (class 2606 OID 20516)
-- Name: dispatcher_favorite_orders dispatcher_favorite_orders_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_favorite_orders
    ADD CONSTRAINT dispatcher_favorite_orders_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4389 (class 2606 OID 20521)
-- Name: dispatcher_favorite_orders dispatcher_favorite_orders_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_favorite_orders
    ADD CONSTRAINT dispatcher_favorite_orders_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4390 (class 2606 OID 20526)
-- Name: dispatcher_route_calculations dispatcher_route_calculations_calc_type_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_route_calculations
    ADD CONSTRAINT dispatcher_route_calculations_calc_type_id_fkey FOREIGN KEY (calc_type_id) REFERENCES sysdata."SYS_ROUTECALC_TYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4391 (class 2606 OID 20531)
-- Name: dispatcher_route_calculations dispatcher_route_calculations_route_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_route_calculations
    ADD CONSTRAINT dispatcher_route_calculations_route_id_fkey FOREIGN KEY (route_id) REFERENCES data.dispatcher_routes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4392 (class 2606 OID 20536)
-- Name: dispatcher_routes dispatcher_routes_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_routes
    ADD CONSTRAINT dispatcher_routes_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4393 (class 2606 OID 20541)
-- Name: dispatcher_routes dispatcher_routes_difficulty_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_routes
    ADD CONSTRAINT dispatcher_routes_difficulty_id_fkey FOREIGN KEY (difficulty_id) REFERENCES sysdata."SYS_ROUTETYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4394 (class 2606 OID 20546)
-- Name: dispatcher_routes dispatcher_routes_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_routes
    ADD CONSTRAINT dispatcher_routes_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4395 (class 2606 OID 20551)
-- Name: dispatcher_selected_drivers dispatcher_selected_drivers_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_drivers
    ADD CONSTRAINT dispatcher_selected_drivers_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4396 (class 2606 OID 20556)
-- Name: dispatcher_selected_drivers dispatcher_selected_drivers_selected_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_drivers
    ADD CONSTRAINT dispatcher_selected_drivers_selected_id_fkey FOREIGN KEY (selected_id) REFERENCES data.dispatcher_selected_orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4397 (class 2606 OID 20561)
-- Name: dispatcher_selected_orders dispatcher_selected_orders_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_orders
    ADD CONSTRAINT dispatcher_selected_orders_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4398 (class 2606 OID 20566)
-- Name: dispatcher_selected_orders dispatcher_selected_orders_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_selected_orders
    ADD CONSTRAINT dispatcher_selected_orders_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4399 (class 2606 OID 20571)
-- Name: dispatcher_to_client dispatcher_to client_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_to_client
    ADD CONSTRAINT "dispatcher_to client_client_id_fkey" FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4400 (class 2606 OID 20576)
-- Name: dispatcher_to_client dispatcher_to client_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.dispatcher_to_client
    ADD CONSTRAINT "dispatcher_to client_dispatcher_id_fkey" FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4401 (class 2606 OID 20581)
-- Name: driver_activities driver_activities_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_activities
    ADD CONSTRAINT driver_activities_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4402 (class 2606 OID 20586)
-- Name: driver_activities driver_activities_type_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_activities
    ADD CONSTRAINT driver_activities_type_id_fkey FOREIGN KEY (type_id) REFERENCES sysdata."SYS_ACTIVITYTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4403 (class 2606 OID 20591)
-- Name: driver_car_docs driver_car_docs_doc_type_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_docs
    ADD CONSTRAINT driver_car_docs_doc_type_fkey FOREIGN KEY (doc_type) REFERENCES sysdata."SYS_DOCTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4404 (class 2606 OID 20596)
-- Name: driver_car_docs driver_car_docs_driver_car_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_docs
    ADD CONSTRAINT driver_car_docs_driver_car_id_fkey FOREIGN KEY (driver_car_id) REFERENCES data.driver_cars(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4405 (class 2606 OID 20601)
-- Name: driver_car_files driver_car_files_doc_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_files
    ADD CONSTRAINT driver_car_files_doc_id_fkey FOREIGN KEY (doc_id) REFERENCES data.driver_car_docs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4406 (class 2606 OID 20606)
-- Name: driver_car_tariffs driver_car_tariffs_driver_car_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_tariffs
    ADD CONSTRAINT driver_car_tariffs_driver_car_id_fkey FOREIGN KEY (driver_car_id) REFERENCES data.driver_cars(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4407 (class 2606 OID 20611)
-- Name: driver_car_tariffs driver_car_tariffs_tariff_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_car_tariffs
    ADD CONSTRAINT driver_car_tariffs_tariff_id_fkey FOREIGN KEY (tariff_id) REFERENCES data.tariffs(id) ON UPDATE CASCADE;


--
-- TOC entry 4408 (class 2606 OID 20616)
-- Name: driver_cars driver_cars_carclass_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_carclass_id_fkey FOREIGN KEY (carclass_id) REFERENCES sysdata."SYS_CARCLASSES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4409 (class 2606 OID 20621)
-- Name: driver_cars driver_cars_cartype_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_cartype_id_fkey FOREIGN KEY (cartype_id) REFERENCES sysdata."SYS_CARTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4410 (class 2606 OID 20626)
-- Name: driver_cars driver_cars_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4411 (class 2606 OID 20631)
-- Name: driver_cars driver_cars_tariff_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_cars
    ADD CONSTRAINT driver_cars_tariff_id_fkey FOREIGN KEY (tariff_id) REFERENCES data.tariffs(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4415 (class 2606 OID 20636)
-- Name: driver_costs driver_costs_cost_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_costs
    ADD CONSTRAINT driver_costs_cost_id_fkey FOREIGN KEY (cost_id) REFERENCES data.cost_types(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4416 (class 2606 OID 20641)
-- Name: driver_costs driver_costs_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_costs
    ADD CONSTRAINT driver_costs_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4417 (class 2606 OID 20646)
-- Name: driver_current_locations driver_current_locations_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_current_locations
    ADD CONSTRAINT driver_current_locations_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4418 (class 2606 OID 20651)
-- Name: driver_devices driver_devices_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_devices
    ADD CONSTRAINT driver_devices_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4419 (class 2606 OID 20656)
-- Name: driver_docs driver_docs_doc_type_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_docs
    ADD CONSTRAINT driver_docs_doc_type_fkey FOREIGN KEY (doc_type) REFERENCES sysdata."SYS_DOCTYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4420 (class 2606 OID 20661)
-- Name: driver_docs driver_docs_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_docs
    ADD CONSTRAINT driver_docs_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4421 (class 2606 OID 20666)
-- Name: driver_files driver_files_doc_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_files
    ADD CONSTRAINT driver_files_doc_id_fkey FOREIGN KEY (doc_id) REFERENCES data.driver_docs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4424 (class 2606 OID 20671)
-- Name: driver_stops driver_stops_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_stops
    ADD CONSTRAINT driver_stops_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4425 (class 2606 OID 20676)
-- Name: driver_stops driver_stops_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_stops
    ADD CONSTRAINT driver_stops_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4426 (class 2606 OID 20681)
-- Name: drivers drivers_contract_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers
    ADD CONSTRAINT drivers_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES data.contracts(id) ON UPDATE CASCADE;


--
-- TOC entry 4412 (class 2606 OID 20686)
-- Name: driver_corrections drivers_corrections_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_corrections
    ADD CONSTRAINT drivers_corrections_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4413 (class 2606 OID 20691)
-- Name: driver_corrections drivers_corrections_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_corrections
    ADD CONSTRAINT drivers_corrections_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4414 (class 2606 OID 20696)
-- Name: driver_corrections drivers_corrections_point_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_corrections
    ADD CONSTRAINT drivers_corrections_point_id_fkey FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4427 (class 2606 OID 20701)
-- Name: drivers drivers_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers
    ADD CONSTRAINT drivers_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4428 (class 2606 OID 20706)
-- Name: drivers drivers_level_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.drivers
    ADD CONSTRAINT drivers_level_id_fkey FOREIGN KEY (level_id) REFERENCES sysdata."SYS_DRIVERLEVELS"(id) ON UPDATE CASCADE ON DELETE SET DEFAULT;


--
-- TOC entry 4429 (class 2606 OID 20711)
-- Name: feedback feedback_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback
    ADD CONSTRAINT feedback_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4431 (class 2606 OID 20716)
-- Name: feedback_docs feedback_docs_feedback_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback_docs
    ADD CONSTRAINT feedback_docs_feedback_id_fkey FOREIGN KEY (feedback_id) REFERENCES data.feedback(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4430 (class 2606 OID 20721)
-- Name: feedback feedback_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback
    ADD CONSTRAINT feedback_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4432 (class 2606 OID 20726)
-- Name: feedback_files feedback_files_doc_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.feedback_files
    ADD CONSTRAINT feedback_files_doc_id_fkey FOREIGN KEY (doc_id) REFERENCES data.feedback_docs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4433 (class 2606 OID 20731)
-- Name: finances_log finances_log_addsum_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.finances_log
    ADD CONSTRAINT finances_log_addsum_id_fkey FOREIGN KEY (addsum_id) REFERENCES data.addsums(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4434 (class 2606 OID 20736)
-- Name: finances_log finances_log_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.finances_log
    ADD CONSTRAINT finances_log_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4435 (class 2606 OID 20741)
-- Name: finances_log finances_log_payment_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.finances_log
    ADD CONSTRAINT finances_log_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES data.feedback(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4351 (class 2606 OID 20746)
-- Name: google_addresses google_addresses_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_addresses
    ADD CONSTRAINT google_addresses_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4352 (class 2606 OID 20751)
-- Name: google_addresses google_addresses_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_addresses
    ADD CONSTRAINT google_addresses_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4353 (class 2606 OID 20756)
-- Name: google_addresses google_addresses_google_original_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_addresses
    ADD CONSTRAINT google_addresses_google_original_fkey FOREIGN KEY (google_original) REFERENCES data.google_originals(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4436 (class 2606 OID 20761)
-- Name: google_modifiers google_modifiers_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_modifiers
    ADD CONSTRAINT google_modifiers_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4437 (class 2606 OID 20766)
-- Name: google_modifiers google_modifiers_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_modifiers
    ADD CONSTRAINT google_modifiers_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4438 (class 2606 OID 20771)
-- Name: google_modifiers google_modifiers_original_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.google_modifiers
    ADD CONSTRAINT google_modifiers_original_id_fkey FOREIGN KEY (original_id) REFERENCES data.google_originals(id) ON UPDATE CASCADE;


--
-- TOC entry 4422 (class 2606 OID 20776)
-- Name: driver_history_locations location_device; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_history_locations
    ADD CONSTRAINT location_device FOREIGN KEY (device_id) REFERENCES data.driver_devices(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4423 (class 2606 OID 20781)
-- Name: driver_history_locations location_driver; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.driver_history_locations
    ADD CONSTRAINT location_driver FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4439 (class 2606 OID 20786)
-- Name: log log_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.log
    ADD CONSTRAINT log_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4440 (class 2606 OID 20791)
-- Name: log log_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.log
    ADD CONSTRAINT log_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4441 (class 2606 OID 20796)
-- Name: log log_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.log
    ADD CONSTRAINT log_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4442 (class 2606 OID 20801)
-- Name: money_requests money_requests_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.money_requests
    ADD CONSTRAINT money_requests_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4443 (class 2606 OID 20806)
-- Name: money_requests money_requests_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.money_requests
    ADD CONSTRAINT money_requests_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4444 (class 2606 OID 20811)
-- Name: options options_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options
    ADD CONSTRAINT options_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4445 (class 2606 OID 20816)
-- Name: options options_section_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.options
    ADD CONSTRAINT options_section_id_fkey FOREIGN KEY (section_id) REFERENCES data.options_sections(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4446 (class 2606 OID 20821)
-- Name: order_agg_costs order_agg_costs_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_agg_costs
    ADD CONSTRAINT order_agg_costs_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4473 (class 2606 OID 20826)
-- Name: orders order_carclass; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_carclass FOREIGN KEY (carclass_id) REFERENCES sysdata."SYS_CARCLASSES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4474 (class 2606 OID 20831)
-- Name: orders order_client; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_client FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4447 (class 2606 OID 20836)
-- Name: order_costs order_costs_cost_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs
    ADD CONSTRAINT order_costs_cost_id_fkey FOREIGN KEY (cost_id) REFERENCES data.cost_types(id) ON UPDATE CASCADE;


--
-- TOC entry 4448 (class 2606 OID 20841)
-- Name: order_costs order_costs_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs
    ADD CONSTRAINT order_costs_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4449 (class 2606 OID 20846)
-- Name: order_costs order_costs_tariff_cost_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_costs
    ADD CONSTRAINT order_costs_tariff_cost_id_fkey FOREIGN KEY (tariff_cost_id) REFERENCES data.tariff_costs(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 4475 (class 2606 OID 20851)
-- Name: orders order_dispatcher; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_dispatcher FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4476 (class 2606 OID 20856)
-- Name: orders order_driver; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_driver FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4450 (class 2606 OID 20861)
-- Name: order_exec_clients order_exec_clients_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_clients
    ADD CONSTRAINT order_exec_clients_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4451 (class 2606 OID 20866)
-- Name: order_exec_clients order_exec_clients_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_clients
    ADD CONSTRAINT order_exec_clients_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4452 (class 2606 OID 20871)
-- Name: order_exec_clients order_exec_clients_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_clients
    ADD CONSTRAINT order_exec_clients_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4453 (class 2606 OID 20876)
-- Name: order_exec_dispatchers order_exec_dispatchers_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_dispatchers
    ADD CONSTRAINT order_exec_dispatchers_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4454 (class 2606 OID 20881)
-- Name: order_exec_dispatchers order_exec_drivers_dispatchers_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_exec_dispatchers
    ADD CONSTRAINT order_exec_drivers_dispatchers_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4455 (class 2606 OID 20886)
-- Name: order_finish_drivers order_finish_drivers_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_finish_drivers
    ADD CONSTRAINT order_finish_drivers_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4456 (class 2606 OID 20891)
-- Name: order_finish_drivers order_finish_drivers_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_finish_drivers
    ADD CONSTRAINT order_finish_drivers_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4457 (class 2606 OID 20896)
-- Name: order_history order_history_client; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_history
    ADD CONSTRAINT order_history_client FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4458 (class 2606 OID 20901)
-- Name: order_history order_history_point; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_history
    ADD CONSTRAINT order_history_point FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4459 (class 2606 OID 20906)
-- Name: order_locations order_locations_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_locations
    ADD CONSTRAINT order_locations_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4460 (class 2606 OID 20911)
-- Name: order_locations order_locations_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_locations
    ADD CONSTRAINT order_locations_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4461 (class 2606 OID 20916)
-- Name: order_log order_log_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE;


--
-- TOC entry 4462 (class 2606 OID 20921)
-- Name: order_log order_log_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4463 (class 2606 OID 20926)
-- Name: order_log order_log_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4464 (class 2606 OID 20931)
-- Name: order_log order_log_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4465 (class 2606 OID 20936)
-- Name: order_log order_log_status_new_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_status_new_fkey FOREIGN KEY (status_new) REFERENCES sysdata."SYS_ORDERSTATUS"(id) ON UPDATE CASCADE;


--
-- TOC entry 4466 (class 2606 OID 20941)
-- Name: order_log order_log_status_old_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_log
    ADD CONSTRAINT order_log_status_old_fkey FOREIGN KEY (status_old) REFERENCES sysdata."SYS_ORDERSTATUS"(id) ON UPDATE CASCADE;


--
-- TOC entry 4467 (class 2606 OID 20946)
-- Name: order_not_exec_dispatchers order_not_exec_dispatchers_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_not_exec_dispatchers
    ADD CONSTRAINT order_not_exec_dispatchers_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4468 (class 2606 OID 20951)
-- Name: order_not_exec_dispatchers order_not_exec_dispatchers_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_not_exec_dispatchers
    ADD CONSTRAINT order_not_exec_dispatchers_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4477 (class 2606 OID 20956)
-- Name: orders order_paytype; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_paytype FOREIGN KEY (paytype_id) REFERENCES sysdata."SYS_PAYTYPES"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4478 (class 2606 OID 20961)
-- Name: orders order_point; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_point FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4469 (class 2606 OID 20966)
-- Name: order_ratings order_ratings_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_ratings
    ADD CONSTRAINT order_ratings_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4470 (class 2606 OID 20971)
-- Name: order_ratings order_ratings_rating_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_ratings
    ADD CONSTRAINT order_ratings_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES sysdata."SYS_ROUTERATING_PARAMS"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4479 (class 2606 OID 20976)
-- Name: orders order_status; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT order_status FOREIGN KEY (status_id) REFERENCES sysdata."SYS_ORDERSTATUS"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4471 (class 2606 OID 20981)
-- Name: order_views order_views_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_views
    ADD CONSTRAINT order_views_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4472 (class 2606 OID 20986)
-- Name: order_views order_views_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.order_views
    ADD CONSTRAINT order_views_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4483 (class 2606 OID 20991)
-- Name: orders_appointing orders_appointing_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_appointing
    ADD CONSTRAINT orders_appointing_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4484 (class 2606 OID 20996)
-- Name: orders_appointing orders_appointing_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_appointing
    ADD CONSTRAINT orders_appointing_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4485 (class 2606 OID 21001)
-- Name: orders_appointing orders_appointing_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_appointing
    ADD CONSTRAINT orders_appointing_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4486 (class 2606 OID 21006)
-- Name: orders_canceling orders_canceling_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_canceling
    ADD CONSTRAINT orders_canceling_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4487 (class 2606 OID 21011)
-- Name: orders_canceling orders_canceling_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_canceling
    ADD CONSTRAINT orders_canceling_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4480 (class 2606 OID 21016)
-- Name: orders orders_created_by_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT orders_created_by_dispatcher_id_fkey FOREIGN KEY (created_by_dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4481 (class 2606 OID 21021)
-- Name: orders orders_dispatcher_route_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT orders_dispatcher_route_id_fkey FOREIGN KEY (dispatcher_route_id) REFERENCES data.dispatcher_routes(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4482 (class 2606 OID 21026)
-- Name: orders orders_end_device_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders
    ADD CONSTRAINT orders_end_device_id_fkey FOREIGN KEY (end_device_id) REFERENCES data.driver_devices(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4488 (class 2606 OID 21031)
-- Name: orders_rejecting orders_rejecting_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_rejecting
    ADD CONSTRAINT orders_rejecting_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4489 (class 2606 OID 21036)
-- Name: orders_rejecting orders_rejecting_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_rejecting
    ADD CONSTRAINT orders_rejecting_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4490 (class 2606 OID 21041)
-- Name: orders_revoking orders_revoking_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_revoking
    ADD CONSTRAINT orders_revoking_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4491 (class 2606 OID 21046)
-- Name: orders_revoking orders_revoking_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_revoking
    ADD CONSTRAINT orders_revoking_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4492 (class 2606 OID 21051)
-- Name: orders_revoking orders_revoking_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_revoking
    ADD CONSTRAINT orders_revoking_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4493 (class 2606 OID 21056)
-- Name: orders_taking orders_taking_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_taking
    ADD CONSTRAINT orders_taking_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4494 (class 2606 OID 21061)
-- Name: orders_taking orders_taking_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.orders_taking
    ADD CONSTRAINT orders_taking_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4495 (class 2606 OID 21066)
-- Name: point_rating point_rating_driver_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating
    ADD CONSTRAINT point_rating_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES data.drivers(id) ON UPDATE CASCADE;


--
-- TOC entry 4496 (class 2606 OID 21071)
-- Name: point_rating point_rating_order_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating
    ADD CONSTRAINT point_rating_order_id_fkey FOREIGN KEY (order_id) REFERENCES data.orders(id) ON UPDATE CASCADE;


--
-- TOC entry 4497 (class 2606 OID 21076)
-- Name: point_rating point_rating_point_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.point_rating
    ADD CONSTRAINT point_rating_point_id_fkey FOREIGN KEY (point_id) REFERENCES data.client_points(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4498 (class 2606 OID 21081)
-- Name: routes routes_client_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.routes
    ADD CONSTRAINT routes_client_id_fkey FOREIGN KEY (client_id) REFERENCES data.clients(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4499 (class 2606 OID 21086)
-- Name: routes routes_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.routes
    ADD CONSTRAINT routes_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE;


--
-- TOC entry 4500 (class 2606 OID 21091)
-- Name: routes routes_type_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.routes
    ADD CONSTRAINT routes_type_id_fkey FOREIGN KEY (type_id) REFERENCES sysdata."SYS_ROUTETYPES"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4501 (class 2606 OID 21096)
-- Name: tariff_costs tariff_costs_tariff_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariff_costs
    ADD CONSTRAINT tariff_costs_tariff_id_fkey FOREIGN KEY (tariff_id) REFERENCES data.tariffs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4502 (class 2606 OID 21101)
-- Name: tariffs tariffs_dispatcher_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: postgres
--

ALTER TABLE ONLY data.tariffs
    ADD CONSTRAINT tariffs_dispatcher_id_fkey FOREIGN KEY (dispatcher_id) REFERENCES data.dispatchers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4503 (class 2606 OID 21121)
-- Name: SYS_ROUTE_CONDITION_TYPES SYS_ROUTE_CONDITION_TYPES_value_type_id_fkey; Type: FK CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_ROUTE_CONDITION_TYPES"
    ADD CONSTRAINT "SYS_ROUTE_CONDITION_TYPES_value_type_id_fkey" FOREIGN KEY (value_type_id) REFERENCES sysdata."SYS_CONDITION_VALUE_TYPES"(id) ON UPDATE CASCADE;


--
-- TOC entry 4350 (class 2606 OID 21126)
-- Name: SYS_CARTYPES cartype_class; Type: FK CONSTRAINT; Schema: sysdata; Owner: postgres
--

ALTER TABLE ONLY sysdata."SYS_CARTYPES"
    ADD CONSTRAINT cartype_class FOREIGN KEY (class_id) REFERENCES sysdata."SYS_CARCLASSES"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 4816 (class 0 OID 0)
-- Dependencies: 14
-- Name: SCHEMA aggregator_api; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA aggregator_api TO laravel_user;


--
-- TOC entry 4818 (class 0 OID 0)
-- Dependencies: 17
-- Name: SCHEMA winapp; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA winapp TO win_app_user;


--
-- TOC entry 4819 (class 0 OID 0)
-- Dependencies: 809
-- Name: FUNCTION before_update_driver_level(); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.before_update_driver_level() TO auth_user;


--
-- TOC entry 4820 (class 0 OID 0)
-- Dependencies: 839
-- Name: FUNCTION calc_costs(order_id_ bigint, driver_id_ integer, driver_car_id_ integer, OUT agg_cost numeric, OUT all_costs numeric); Type: ACL; Schema: sysdata; Owner: postgres
--

REVOKE ALL ON FUNCTION sysdata.calc_costs(order_id_ bigint, driver_id_ integer, driver_car_id_ integer, OUT agg_cost numeric, OUT all_costs numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION sysdata.calc_costs(order_id_ bigint, driver_id_ integer, driver_car_id_ integer, OUT agg_cost numeric, OUT all_costs numeric) TO auth_user;


--
-- TOC entry 4821 (class 0 OID 0)
-- Dependencies: 810
-- Name: FUNCTION check_id_client(id_ integer, pass_ text); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.check_id_client(id_ integer, pass_ text) TO auth_user;


--
-- TOC entry 4822 (class 0 OID 0)
-- Dependencies: 811
-- Name: FUNCTION check_id_dispatcher(id_ integer, pass_ text, without_pass_ boolean); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.check_id_dispatcher(id_ integer, pass_ text, without_pass_ boolean) TO auth_user;


--
-- TOC entry 4823 (class 0 OID 0)
-- Dependencies: 812
-- Name: FUNCTION check_id_driver(id_ integer, pass_ text); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.check_id_driver(id_ integer, pass_ text) TO auth_user;


--
-- TOC entry 4824 (class 0 OID 0)
-- Dependencies: 813
-- Name: FUNCTION check_signing(text); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.check_signing(text) TO auth_user;


--
-- TOC entry 4825 (class 0 OID 0)
-- Dependencies: 814
-- Name: FUNCTION cron_every_hour(); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.cron_every_hour() TO auth_user;


--
-- TOC entry 4826 (class 0 OID 0)
-- Dependencies: 815
-- Name: FUNCTION cron_fill_order_location(order_id_ bigint, driver_id_ integer, job_id_ bigint); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.cron_fill_order_location(order_id_ bigint, driver_id_ integer, job_id_ bigint) TO auth_user;


--
-- TOC entry 4827 (class 0 OID 0)
-- Dependencies: 840
-- Name: FUNCTION cron_reject_order(order_id_ bigint, driver_id_ integer, job_id_ bigint); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.cron_reject_order(order_id_ bigint, driver_id_ integer, job_id_ bigint) TO auth_user;


--
-- TOC entry 4828 (class 0 OID 0)
-- Dependencies: 816
-- Name: FUNCTION fill_order_location(order_id_ bigint, driver_id_ integer); Type: ACL; Schema: sysdata; Owner: postgres
--

REVOKE ALL ON FUNCTION sysdata.fill_order_location(order_id_ bigint, driver_id_ integer) FROM PUBLIC;
GRANT ALL ON FUNCTION sysdata.fill_order_location(order_id_ bigint, driver_id_ integer) TO auth_user;


--
-- TOC entry 4829 (class 0 OID 0)
-- Dependencies: 817
-- Name: FUNCTION get_distance(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric); Type: ACL; Schema: sysdata; Owner: postgres
--

REVOKE ALL ON FUNCTION sysdata.get_distance(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION sysdata.get_distance(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric) TO auth_user;


--
-- TOC entry 4830 (class 0 OID 0)
-- Dependencies: 847
-- Name: FUNCTION order4dispatcher(order_id_ bigint, dispatcher_id_ integer); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.order4dispatcher(order_id_ bigint, dispatcher_id_ integer) TO auth_user;


--
-- TOC entry 4831 (class 0 OID 0)
-- Dependencies: 818
-- Name: FUNCTION order4driver(order_id_ bigint, driver_id_ integer, driver_dispatcher_id_ integer); Type: ACL; Schema: sysdata; Owner: postgres
--

GRANT ALL ON FUNCTION sysdata.order4driver(order_id_ bigint, driver_id_ integer, driver_dispatcher_id_ integer) TO auth_user;


--
-- TOC entry 4832 (class 0 OID 0)
-- Dependencies: 819
-- Name: FUNCTION check_login_dispatcher(hash text, disp_name text, disp_pass text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.check_login_dispatcher(hash text, disp_name text, disp_pass text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.check_login_dispatcher(hash text, disp_name text, disp_pass text) TO win_app_user;


--
-- TOC entry 4833 (class 0 OID 0)
-- Dependencies: 820
-- Name: FUNCTION delete_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.delete_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.delete_addsum(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) TO win_app_user;


--
-- TOC entry 4834 (class 0 OID 0)
-- Dependencies: 821
-- Name: FUNCTION delete_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.delete_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.delete_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer) TO win_app_user;


--
-- TOC entry 4835 (class 0 OID 0)
-- Dependencies: 822
-- Name: FUNCTION delete_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.delete_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.delete_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer) TO win_app_user;


--
-- TOC entry 4836 (class 0 OID 0)
-- Dependencies: 823
-- Name: FUNCTION delete_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.delete_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.delete_feedback(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) TO win_app_user;


--
-- TOC entry 4837 (class 0 OID 0)
-- Dependencies: 849
-- Name: FUNCTION edit_addsum(dispatcher_id_ integer, pass_ text, driver_id_ integer, addsum_id_ bigint, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.edit_addsum(dispatcher_id_ integer, pass_ text, driver_id_ integer, addsum_id_ bigint, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.edit_addsum(dispatcher_id_ integer, pass_ text, driver_id_ integer, addsum_id_ bigint, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) TO win_app_user;


--
-- TOC entry 4838 (class 0 OID 0)
-- Dependencies: 850
-- Name: FUNCTION edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_photo bytea, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_inn_ text, driver_kpp_ text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_photo bytea, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_inn_ text, driver_kpp_ text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.edit_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_login_ character varying, driver_name_ character varying, driver_second_name_ character varying, driver_family_name_ character varying, driver_pass_ character varying, driver_is_active_ boolean, driver_level_id_ integer, driver_date_of_birth_ date, driver_contact_ text, driver_contact2_ text, driver_photo bytea, driver_bank_ text, driver_bik_ text, driver_korrschet_ text, driver_rasschet_ text, driver_poluchatel_ text, driver_inn_ text, driver_kpp_ text) TO win_app_user;


--
-- TOC entry 4839 (class 0 OID 0)
-- Dependencies: 851
-- Name: FUNCTION edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean, ptsserie_ character varying, ptsnumber_ character varying, pts_file_id1_ bigint, pts_file_name1_ character varying, pts_file_data1_ bytea, pts_file_id2_ bigint, pts_file_name2_ character varying, pts_file_data2_ bytea, stsserie_ character varying, stsnumber_ character varying, sts_file_id1_ bigint, sts_file_name1_ character varying, sts_file_data1_ bytea, sts_file_id2_ bigint, sts_file_name2_ character varying, sts_file_data2_ bytea); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean, ptsserie_ character varying, ptsnumber_ character varying, pts_file_id1_ bigint, pts_file_name1_ character varying, pts_file_data1_ bytea, pts_file_id2_ bigint, pts_file_name2_ character varying, pts_file_data2_ bytea, stsserie_ character varying, stsnumber_ character varying, sts_file_id1_ bigint, sts_file_name1_ character varying, sts_file_data1_ bytea, sts_file_id2_ bigint, sts_file_name2_ character varying, sts_file_data2_ bytea) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.edit_driver_car(dispatcher_id_ integer, pass_ text, driver_id_ integer, driver_car_id_ integer, carmodel_ character varying, carnumber_ character varying, carcolor_ character varying, cartype_id_ integer, is_active_ boolean, ptsserie_ character varying, ptsnumber_ character varying, pts_file_id1_ bigint, pts_file_name1_ character varying, pts_file_data1_ bytea, pts_file_id2_ bigint, pts_file_name2_ character varying, pts_file_data2_ bytea, stsserie_ character varying, stsnumber_ character varying, sts_file_id1_ bigint, sts_file_name1_ character varying, sts_file_data1_ bytea, sts_file_id2_ bigint, sts_file_name2_ character varying, sts_file_data2_ bytea) TO win_app_user;


--
-- TOC entry 4840 (class 0 OID 0)
-- Dependencies: 852
-- Name: FUNCTION edit_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer, feedback_id_ bigint, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.edit_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer, feedback_id_ bigint, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.edit_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer, feedback_id_ bigint, opernumber_ integer, operdate_ timestamp without time zone, summa_ real, commentary_ text, file_id1_ bigint, file_name1_ character varying, file_data1_ bytea, file_id2_ bigint, file_name2_ character varying, file_data2_ bytea, file_id3_ bigint, file_name3_ character varying, file_data3_ bytea, file_id4_ bigint, file_name4_ character varying, file_data4_ bytea, file_id5_ bigint, file_name5_ character varying, file_data5_ bytea) TO win_app_user;


--
-- TOC entry 4841 (class 0 OID 0)
-- Dependencies: 825
-- Name: FUNCTION get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_addsums_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) TO win_app_user;


--
-- TOC entry 4842 (class 0 OID 0)
-- Dependencies: 826
-- Name: FUNCTION get_addsums_files(dispatcher_id_ integer, pass_ text, addsum_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_addsums_files(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_addsums_files(dispatcher_id_ integer, pass_ text, addsum_id_ bigint) TO win_app_user;


--
-- TOC entry 4843 (class 0 OID 0)
-- Dependencies: 824
-- Name: FUNCTION get_car_types(); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_car_types() FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_car_types() TO win_app_user;


--
-- TOC entry 4844 (class 0 OID 0)
-- Dependencies: 853
-- Name: FUNCTION get_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT name text, OUT login text, OUT birthday date, OUT contact text, OUT contact2 text, OUT is_active boolean, OUT level_id integer, OUT level_name text, OUT photo bytea, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT poluchatel text, OUT inn text, OUT kpp text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT name text, OUT login text, OUT birthday date, OUT contact text, OUT contact2 text, OUT is_active boolean, OUT level_id integer, OUT level_name text, OUT photo bytea, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT poluchatel text, OUT inn text, OUT kpp text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT name text, OUT login text, OUT birthday date, OUT contact text, OUT contact2 text, OUT is_active boolean, OUT level_id integer, OUT level_name text, OUT photo bytea, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT poluchatel text, OUT inn text, OUT kpp text) TO win_app_user;


--
-- TOC entry 4845 (class 0 OID 0)
-- Dependencies: 827
-- Name: FUNCTION get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT carmodel text, OUT carnumber text, OUT carcolor text, OUT cartype_id integer, OUT is_active boolean, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT carmodel text, OUT carnumber text, OUT carcolor text, OUT cartype_id integer, OUT is_active boolean, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_car(dispatcher_id_ integer, pass_ text, driver_car_id_ integer, OUT carmodel text, OUT carnumber text, OUT carcolor text, OUT cartype_id integer, OUT is_active boolean, OUT ptsnumber text, OUT ptsserie text, OUT ptsscan text, OUT stsnumber text, OUT stsserie text, OUT stsscan text) TO win_app_user;


--
-- TOC entry 4846 (class 0 OID 0)
-- Dependencies: 854
-- Name: FUNCTION get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_car_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) TO win_app_user;


--
-- TOC entry 4847 (class 0 OID 0)
-- Dependencies: 855
-- Name: FUNCTION get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT dog_id bigint, OUT dog_number text, OUT dog_begin date, OUT dog_end date, OUT dog_scan text) TO win_app_user;


--
-- TOC entry 4848 (class 0 OID 0)
-- Dependencies: 856
-- Name: FUNCTION get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) TO win_app_user;


--
-- TOC entry 4849 (class 0 OID 0)
-- Dependencies: 829
-- Name: FUNCTION get_driver_levels(); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_levels() FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_levels() TO win_app_user;


--
-- TOC entry 4850 (class 0 OID 0)
-- Dependencies: 857
-- Name: FUNCTION get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, OUT pass_id bigint, OUT pass_serie text, OUT pass_number text, OUT pass_date date, OUT pass_from text, OUT pass_scan text) TO win_app_user;


--
-- TOC entry 4851 (class 0 OID 0)
-- Dependencies: 830
-- Name: FUNCTION get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_feedback_file(dispatcher_id_ integer, pass_ text, file_id_ bigint) TO win_app_user;


--
-- TOC entry 4852 (class 0 OID 0)
-- Dependencies: 831
-- Name: FUNCTION get_feedback_files(dispatcher_id_ integer, pass_ text, feedback_id_ bigint); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_feedback_files(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_feedback_files(dispatcher_id_ integer, pass_ text, feedback_id_ bigint) TO win_app_user;


--
-- TOC entry 4853 (class 0 OID 0)
-- Dependencies: 858
-- Name: FUNCTION get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_invoice_options(dispatcher_id_ integer, pass_ text, driver_id_ integer, disp_data boolean, OUT bank text, OUT bik text, OUT korrschet text, OUT rasschet text, OUT full_name text, OUT inn text, OUT kpp text) TO win_app_user;


--
-- TOC entry 4854 (class 0 OID 0)
-- Dependencies: 828
-- Name: FUNCTION get_next_opernumber(dispatcher_id_ integer); Type: ACL; Schema: winapp; Owner: postgres
--

GRANT ALL ON FUNCTION winapp.get_next_opernumber(dispatcher_id_ integer) TO win_app_user;


--
-- TOC entry 4855 (class 0 OID 0)
-- Dependencies: 833
-- Name: FUNCTION get_option(hash text, dispatcher_id_ integer, pass_ text, section_id_ integer, option_name_ text, OUT param_view_name text, OUT param_value_text text, OUT param_value_integer integer, OUT param_value_real real); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.get_option(hash text, dispatcher_id_ integer, pass_ text, section_id_ integer, option_name_ text, OUT param_view_name text, OUT param_value_text text, OUT param_value_integer integer, OUT param_value_real real) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.get_option(hash text, dispatcher_id_ integer, pass_ text, section_id_ integer, option_name_ text, OUT param_view_name text, OUT param_value_text text, OUT param_value_integer integer, OUT param_value_real real) TO win_app_user;


--
-- TOC entry 4856 (class 0 OID 0)
-- Dependencies: 832
-- Name: FUNCTION set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ bytea, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ bytea, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ bytea, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ bytea, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ bytea); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ bytea, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ bytea, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ bytea, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ bytea, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ bytea) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.set_driver_dogovor(dispatcher_id_ integer, pass_ text, driver_id_ integer, dog_id_ bigint, dog_number text, dog_begin date, dog_end date, dog_file_id1_ bigint, dog_file_name1_ character varying, dog_file_data1_ bytea, dog_file_id2_ bigint, dog_file_name2_ character varying, dog_file_data2_ bytea, dog_file_id3_ bigint, dog_file_name3_ character varying, dog_file_data3_ bytea, dog_file_id4_ bigint, dog_file_name4_ character varying, dog_file_data4_ bytea, dog_file_id5_ bigint, dog_file_name5_ character varying, dog_file_data5_ bytea) TO win_app_user;


--
-- TOC entry 4857 (class 0 OID 0)
-- Dependencies: 859
-- Name: FUNCTION set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ bytea, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ bytea, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ bytea, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ bytea, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ bytea); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ bytea, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ bytea, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ bytea, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ bytea, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ bytea) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.set_driver_passport(dispatcher_id_ integer, pass_ text, driver_id_ integer, pass_id_ bigint, pass_serie text, pass_number text, pass_date date, pass_from text, pass_file_id1_ bigint, pass_file_name1_ character varying, pass_file_data1_ bytea, pass_file_id2_ bigint, pass_file_name2_ character varying, pass_file_data2_ bytea, pass_file_id3_ bigint, pass_file_name3_ character varying, pass_file_data3_ bytea, pass_file_id4_ bigint, pass_file_name4_ character varying, pass_file_data4_ bytea, pass_file_id5_ bigint, pass_file_name5_ character varying, pass_file_data5_ bytea) TO win_app_user;


--
-- TOC entry 4858 (class 0 OID 0)
-- Dependencies: 834
-- Name: FUNCTION set_feedback_paid(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, date_ date); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.set_feedback_paid(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, date_ date) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.set_feedback_paid(dispatcher_id_ integer, pass_ text, feedback_id_ bigint, date_ date) TO win_app_user;


--
-- TOC entry 4859 (class 0 OID 0)
-- Dependencies: 836
-- Name: FUNCTION view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.view_addsums(dispatcher_id_ integer, pass_ text, driver_id_ integer) TO win_app_user;


--
-- TOC entry 4860 (class 0 OID 0)
-- Dependencies: 835
-- Name: FUNCTION view_drivers(dispatcher_id_ integer, pass_ text); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.view_drivers(dispatcher_id_ integer, pass_ text) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.view_drivers(dispatcher_id_ integer, pass_ text) TO win_app_user;


--
-- TOC entry 4861 (class 0 OID 0)
-- Dependencies: 837
-- Name: FUNCTION view_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer); Type: ACL; Schema: winapp; Owner: postgres
--

REVOKE ALL ON FUNCTION winapp.view_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer) FROM PUBLIC;
GRANT ALL ON FUNCTION winapp.view_feedback(dispatcher_id_ integer, pass_ text, driver_id_ integer) TO win_app_user;


--
-- TOC entry 4942 (class 0 OID 0)
-- Dependencies: 456
-- Name: TABLE cars_view; Type: ACL; Schema: winapp; Owner: postgres
--

GRANT ALL ON TABLE winapp.cars_view TO win_app_user;


--
-- TOC entry 4943 (class 0 OID 0)
-- Dependencies: 457
-- Name: TABLE drivers_view; Type: ACL; Schema: winapp; Owner: postgres
--

GRANT ALL ON TABLE winapp.drivers_view TO win_app_user;


--
-- TOC entry 2883 (class 826 OID 21248)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: sysdata; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA sysdata GRANT ALL ON FUNCTIONS TO auth_user;


--
-- TOC entry 2884 (class 826 OID 21250)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: winapp; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA winapp GRANT SELECT,USAGE ON SEQUENCES TO win_app_user;


--
-- TOC entry 2885 (class 826 OID 21251)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: winapp; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA winapp GRANT ALL ON FUNCTIONS TO win_app_user;


--
-- TOC entry 2886 (class 826 OID 21252)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: winapp; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA winapp GRANT ALL ON TABLES TO win_app_user;


-- Completed on 2024-03-06 18:09:07

--
-- PostgreSQL database dump complete
--

