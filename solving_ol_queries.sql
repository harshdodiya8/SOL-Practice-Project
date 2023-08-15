-- 1. How many olympics games have been held?
select count(distinct games) as total_olympics_games from ol_hist

-- 2. List down all Olympics games held so far.
select distinct year, season, city from ol_hist group by year,season, city order by year asc

-- 3. Mention the total no of nations who participated in each olympics game?
with countries as
	(
	select oh.games, nr.region
	from ol_hist oh
	join nocreg nr on oh.noc =nr.noc
	group by games, nr.region
	order by games asc
	)
select games, count(*) as pc from countries
group by games
order by games

-- 4. Which year saw the highest and lowest no of countries participating in olympics
with countries as
	(
	select oh.games, nr.region
	from ol_hist oh
	join nocreg nr on oh.noc =nr.noc
	group by games, nr.region
	order by games asc
	),
	tot_countries as
	(select games, count(*) as pc from countries
	group by games
	order by games )
select distinct
concat(first_value(games) over (order by pc asc), '-', first_value(pc) over (order by pc asc))
as lowest_participations,
concat(first_value(games) over (order by pc desc), '-', first_value(pc) over (order by pc desc))
as highest_participations
from tot_countries

-- 5. Which nation has participated in all of the olympic games
with countries as
	(
	select oh.games, nr.region as country
	from ol_hist oh
	join nocreg nr on oh.noc =nr.noc
	group by games, nr.region
	order by games asc
	),
	tot_countries as (select count(	distinct games) as pc from countries),
	countries_participated as (select country, count(1) from countries group by country)
select cp.* from countries_participated cp join tot_countries tc 
on cp.count=tc.pc

-- 6. Identify the sport which was played in all summer olympics.
with summer as (select distinct year, season, sport from ol_hist where season = 'Summer' group by year,season,sport order by year),
     games_played as (select count(distinct year) as tot_games from summer),
     time_played as (select sport, count(sport) as times_played from summer group by sport order by times_played desc)
select tp.* from time_played tp
join games_played gp
	on gp.tot_games=tp.times_played

-- 7. Which Sports were just played only once in the olympics.
with t1 as (select distinct year, season, sport from ol_hist group by year,season,sport order by year),
     t2 as (select count(distinct year) as tot_games from t1),
     t3 as (select sport, count(sport) as times_played from t1 group by sport order by times_played asc)
select * from t3  where times_played = 1 order by t3.sport;


-- 8. Fetch the total no of sports played in each olympic games.
with t1 as (select games, sport from ol_hist group by games, sport order by games)
select distinct games, count(1) tot_played from t1 group by games order by tot_played desc


-- 9. Fetch oldest athletes to win a gold medal
with t1 as
	(select  name, sex, cast(case when age= 'NA' then '0' else age end as int) as age, team, games, sport, medal
	from ol_hist
	where medal in ('Gold', 'gold')),
	t2 as
	(
	select *, rank() over (order by age desc) as rnk
	from t1
	)
select * from t2 where rnk = 1


-- 10. Find the Ratio of male and female athletes participated in all olympic games.
with tot_count as 
	(select sex, count(1) as cnt from ol_hist group by sex),
     t2 as (select *, row_number() over (order by cnt) as rw from tot_count),
     min_cnt as (select cnt from t2	where rw = 1),
	 max_cnt as (select cnt from t2 where rw = 2)
select concat('1:', round(max_cnt.cnt::decimal/min_cnt.cnt, 2))	as ratio
from min_cnt, max_cnt



-- 11. Fetch the top 5 athletes who have won the most gold medals. b

with t1 as
	(select  name, sex, age, team, games, sport, medal
	from ol_hist
	where medal in ('Gold', 'gold')),	
	t2 as (select name, games, sport
		from t1
		group by  name, games,sport
		order by name)
select name, count(1) as wm from t2 group by name order by wm desc 
select name, count(medal) as won_gold
from t2
group by name, medal
order by won_gold desc

-- 12. Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).
with t1 as
	(select oh.name, nr.region as team, count(oh.medal ) as tot_medals
	from ol_hist oh
	join nocreg nr on oh.noc = nr.noc
	where oh.medal in ('Gold', 'Silver', 'Bronze' ) 
	group by nr.region, oh.name
	order by tot_medals desc),
t2 as (select *, dense_rank() over (order by tot_medals desc) as rnk from t1 )
select * from t2
where rnk <= 5;

-- 13. Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.
with t1 as (select nr.region as team, count(oh.medal ) as tot_medals
	from ol_hist oh
	join nocreg nr on oh.noc = nr.noc
	where oh.medal in ('Gold', 'Silver', 'Bronze' ) 
	group by nr.region
	order by tot_medals desc),
t2 as (select *, rank() over (order by tot_medals desc) as rnk from t1 )
select * from t2
where rnk <= 5;

-- 14. List down total gold, silver and bronze medals won by each country.
SELECT country, coalesce(gold, 0) as gold,
coalesce(silver, 0) as silver,
coalesce(bronze, 0) as bronze	
FROM CROSSTAB ('SELECT NR.REGION AS COUNTRY, MEDAL, COUNT(1) AS TOT_MEDALS
				FROM OL_HIST OH
				JOIN NOCREG NR ON NR.NOC = OH.NOC
				WHERE MEDAL <> ''NA''
				GROUP BY NR.REGION, MEDAL ORDER BY NR.REGION, MEDAL',
			  	'values (''Bronze''), (''Gold''), (''Silver'')')
                AS RESULT (country VARCHAR, bronze BIGINT, gold BIGINT, silver BIGINT) 
order by gold desc, silver desc, bronze desc


-- 15.  List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
SELECT substring(games,1,position(' - ' in games) -1) as games,
substring(games,position(' - ' in games) +3) as country,
coalesce(gold, 0) as gold,
coalesce(silver, 0) as silver,
coalesce(bronze, 0) as bronze	
FROM CROSSTAB ('SELECT concat(games,'' - '',nr.region) AS games, MEDAL, COUNT(1) AS TOT_MEDALS
				FROM OL_HIST OH
				JOIN NOCREG NR ON NR.NOC = OH.NOC
				WHERE MEDAL <> ''NA''
				GROUP BY games, NR.REGION, MEDAL  ORDER BY games, MEDAL',
			  	'values (''Bronze''), (''Gold''), (''Silver'')')
                AS RESULT (games text, bronze BIGINT, gold BIGINT, silver BIGINT) 

-- 16. Identify which country won the most gold, most silver and most bronze medals in each olympic games.
with t1 as (
		SELECT substring(games,1,position(' - ' in games) -1) as games,
		substring(games,position(' - ' in games) +3) as country,
		coalesce(gold, 0) as gold,
		coalesce(silver, 0) as silver,
		coalesce(bronze, 0) as bronze	
		FROM CROSSTAB ('SELECT concat(games,'' - '',nr.region) AS games, MEDAL, COUNT(1) AS TOT_MEDALS
						FROM OL_HIST OH
						JOIN NOCREG NR ON NR.NOC = OH.NOC
						WHERE MEDAL <> ''NA''
						GROUP BY games, NR.REGION, MEDAL  ORDER BY games, MEDAL',
						'values (''Bronze''), (''Gold''), (''Silver'')')
						AS RESULT (games text, bronze BIGINT, gold BIGINT, silver BIGINT) 
order by games),	
t2 as(select distinct games, 
				concat(first_value(country) over (partition by games order by gold desc), ' - ', 
				first_value(gold) over (partition by games order by gold desc)) as max_gold,
				concat(first_value(country) over (partition by games order by silver desc), ' - ', 
			  first_value(silver) over (partition by games order by silver desc)) as max_silver,
			concat(first_value(country) over (partition by games order by bronze desc), ' - ', 
			  first_value(bronze) over (partition by games order by bronze desc)) as max_bronze
		from t1
		order by games),
-- 17. Identify which country won the most gold, most silver, most bronze medals and the most medals in each olympic games. 
t3 as (SELECT games, NR.REGION AS COUNTRY, COUNT(medal) AS TOT_MEDALS
				FROM OL_HIST OH
				JOIN NOCREG NR ON NR.NOC = OH.NOC
				WHERE MEDAL <> 'NA'
				GROUP BY games, NR.REGION ORDER BY games, NR.REGION),
t4 as (select distinct games,
			concat(first_value(country) over (partition by games order by tot_medals desc), ' - ', 
			first_value(tot_medals) over (partition by games order by tot_medals desc)) as max_medals
			from t3
			order by games)
select t2.*, t4.max_medals from t2 join t4 on t2.games = t4.games


-- 18. Which countries have never won gold medal but have won silver/bronze medals?
with t1 as 
		(SELECT country, coalesce(gold, 0) as gold,
		coalesce(silver, 0) as silver,
		coalesce(bronze, 0) as bronze	
		FROM CROSSTAB ('SELECT NR.REGION AS COUNTRY, MEDAL, COUNT(1) AS TOT_MEDALS
						FROM OL_HIST OH
						JOIN NOCREG NR ON NR.NOC = OH.NOC
						WHERE MEDAL <> ''NA''
						GROUP BY NR.REGION, MEDAL ORDER BY NR.REGION, MEDAL',
						'values (''Bronze''), (''Gold''), (''Silver'')')
						AS RESULT (country VARCHAR, bronze BIGINT, gold BIGINT, silver BIGINT) 
		order by gold desc, silver desc, bronze desc)
select * from t1 where gold = 0 and (silver != 0 or bronze != 0) 


-- 19. In which Sport/event, India has won highest medals.

with t1 as
	(SELECT NR.REGION AS COUNTRY, sport, count(medal) as tot_medals
	FROM OL_HIST OH
	JOIN NOCREG NR ON NR.NOC = OH.NOC
	WHERE MEDAL <> 'NA' and nr.region = 'India'
	GROUP BY NR.REGION, sport ORDER BY tot_medals)
select distinct country,
concat(first_value(sport) over (order by tot_medals desc), ' - ', first_value(tot_medals) over (order by tot_medals desc)) as Highest_medals
from t1


-- 20. Break down all olympic games where India won medal for Hockey and how many medals in each olympic games
SELECT NR.REGION AS COUNTRY, sport, games, count(medal) as tot_medals
FROM OL_HIST OH
JOIN NOCREG NR ON NR.NOC = OH.NOC
WHERE MEDAL <> 'NA' and nr.region = 'India' and sport = 'Hockey'
GROUP BY NR.REGION, sport, games ORDER BY tot_medals desc

select * from ol_hist
select * from nocreg