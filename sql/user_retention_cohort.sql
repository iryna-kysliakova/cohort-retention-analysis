select *
from cohort_users_raw cur
limit 20;

select*
from cohort_events_raw cer
limit 20;


---1. прибираємо пробіли
select user_id, 
trim(signup_datetime) as date
from cohort_users_raw cur
---2. заміна деліметрів

select
user_id,
replace(replace(signup_datetime,'.','-'),'/','-')
from cohort_users_raw

---3.Split_part- витягуємо дату , задаємо рік у 4_ох цифрах

select 
user_id, signup_datetime,
split_part(signup_datetime,' ',1)
from cohort_users_raw

---4.визначаємо 2 чи 4 цифри у році

 select user_id,signup_datetime,
 length(split_part(replace(replace(split_part(trim(signup_datetime),' ',1),'.','-'),'/','-'),'-',3))=4
 from cohort_users_raw



with users_parsed as
 	--- користувачі з правильною датою реєстрації
(
	select
	u.user_id, 
	u.signup_datetime, 
	u.promo_signup_flag,
case
	when length(split_part(replace(replace(split_part(trim(u.signup_datetime),' ',1),'.','-'),'/','-'),'-',3))=4 
	then to_date(replace(replace(split_part(trim(u.signup_datetime),' ',1),'.','-'),'/','-'), 'DD-MM-YYYY') 
	else to_date(replace(replace(split_part(trim(u.signup_datetime),' ',1),'.','-'),'/','-'),'DD-MM-YY')
end as signup_ts 
from cohort_users_raw u
),
 events_parsed as
	 -- події з правильною датою
 (
	 select 
		 c.user_id,
		 c.event_datetime,
		 c.event_type,
		 c.revenue,
		 case 
		 	when length(split_part(replace(replace(split_part(trim(c.event_datetime),' ',1),'/','-'),'.','-'),'-',3))=4
		 	then to_date(replace(replace(split_part(trim(c.event_datetime),' ',1),'/','-'),'.','-'),'DD-MM-YYYY')
		 	else to_date(replace(replace(split_part(trim(c.event_datetime),' ',1),'/','-'),'.','-'),'DD-MM-YY')
		 end as event_ts
	  from cohort_events_raw c  
 ),
 joined_tables as
 -- об'днання користувачів і подій
 (	select 
		u.user_id,
		u.signup_ts,
		u.promo_signup_flag,
		date_trunc('month',u.signup_ts)::date as cohort_month,    			 -- визначаємо перший місяць реєстрації
		e.event_ts,
		e.event_type,
		e.revenue,
		date_trunc('month',e.event_ts)::date as activity_month,   			  -- перший місяць активності 
		12*(extract(year from e.event_ts) - extract (year from u.signup_ts)) 
		+
		(extract(month from e.event_ts) - extract (month from u.signup_ts)) as month_offset   -- різниця між подією тиа датою реєстрації по місяцях		                                                                          
	from users_parsed u
	left join events_parsed e on u.user_id=e.user_id
	where u.signup_ts is not null
	and e.event_ts is not null
	and e.event_type is not null
	and e.event_type != lower('test_event'))
		 --фінальна агрегована таблиця
select promo_signup_flag,cohort_month,month_offset,
count(distinct user_id) as total_users
from joined_tables
where activity_month between '2025-01-01' and '2025-06-01'
group by promo_signup_flag,cohort_month,month_offset
order by promo_signup_flag,cohort_month,month_offset;




