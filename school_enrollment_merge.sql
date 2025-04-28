-- Raw data contains much for data than needed. Filter to include only high school level data

CREATE VIEW public_high_school_enrollment AS
SELECT school_code, school_name, 'public' AS school_type, charter, 
gr_09 + gr_10 + gr_11 + gr_12 AS high_school_enr
FROM census_day_enrollment
WHERE aggregate_level = 'S' AND reporting_category = 'TA'
AND gr_09 + gr_10 + gr_11 + gr_12 >= 100; -- remove the very small schools that likely don't have sports teams

ALTER TABLE private_school_data
ADD high_school_enr INT;

UPDATE private_school_data
SET high_school_enr = gr_09 + gr_10 + gr_11 + gr_12;

CREATE VIEW private_high_school_enrollment AS
SELECT SUBSTRING(cds_code,7,7) AS school_code, school_name,
'private' AS school_type, 'N' AS charter, high_school_enr
FROM private_school_data
WHERE high_school_enr >= 100;

CREATE VIEW public_high_school_graduation_data AS
SELECT school_code, school_name, regular_hs_diploma_graduation_rate AS graduation_rate
FROM graduation_outcome_data
WHERE aggregate_level = 'S' AND reporting_category = 'TA';

CREATE VIEW public_high_school_absenteeism_data AS
SELECT school_code, school_name, chronic_absenteeism_rate
FROM absenteeism_data
WHERE aggregate_level = 'S'
AND reporting_category = 'TA';

-- remove whitespaces from school names in case that is preventing matches in joins
UPDATE census_day_enrollment
SET school_name = TRIM(school_name);

UPDATE cif_team_results
SET team = TRIM(team);

UPDATE private_school_data
SET school_name = TRIM(school_name);

-- what percent of high schools in public school enrollment end with a certain word?
-- 'high' 49%
-- 'academy' 8%
-- '(continuation)' 5%
-- 'charter' 5%
SELECT
  SUBSTRING_INDEX(school_name, ' ', -1) AS last_word,
  COUNT(*) AS count,
  COUNT(*)/(SELECT COUNT(*) FROM public_school_enrollment WHERE high_school_enr > 0) AS percent_ending_with
FROM public_school_enrollment
WHERE high_school_enr > 0
GROUP BY last_word
ORDER BY count DESC;

-- for private schools:
/*
'academy' 32%
'school' 31%
everything else is 3% or less
*/
SELECT
  SUBSTRING_INDEX(school_name, ' ', -1) AS last_word,
  COUNT(*) AS count,
  COUNT(*)/(SELECT COUNT(*) FROM private_school_data WHERE high_school_enr > 0) AS percent_ending_with
FROM private_school_data
WHERE high_school_enr > 0
GROUP BY last_word
ORDER BY count DESC;

-- For the teams in CIF results
/*
'valley' 6%
'school' 4%
'christian' 3%
'prep' 2%
*/
SELECT
  SUBSTRING_INDEX(Team, ' ', -1) AS last_word,
  COUNT(*) AS count,
  COUNT(*)/(SELECT COUNT(*) FROM cif_team_results) AS percent_ending_with
FROM cif_team_results
GROUP BY last_word
ORDER BY count DESC;


SELECT
	teams.Team AS team_name,
    public_schools.school_name AS public_name,
	private_schools.school_name AS private_name,
    CASE
		WHEN public_schools.school_name IS NULL AND private_schools.school_name IS NOT NULL THEN private_schools.high_school_enr
        WHEN public_schools.school_name IS NOT NULL AND private_schools.school_name IS NULL THEN public_schools.high_school_enr
	END AS high_school_enr
FROM cif_team_results AS teams
	LEFT JOIN public_high_school_enrollment AS public_schools
		ON public_schools.school_name LIKE CONCAT('%',teams.Team, '%')
	LEFT JOIN private_high_school_enr AS private_schools
		ON private_schools.school_name LIKE CONCAT('%',teams.Team, '%')
WHERE (public_schools.school_name IS NULL AND private_schools.school_name IS NOT NULL)
OR (public_schools.school_name IS NOT NULL AND private_schools.school_name IS NULL);

-- used to make temp table closest_match
CREATE TEMPORARY TABLE teams_with_no_matches
WITH school_name_matches AS (
SELECT
	teams.Team AS team_name,
    public_schools.school_name AS school_name,
	"public" AS school_type,
    high_school_enr
FROM (SELECT DISTINCT Team FROM cif_team_results) AS teams
	LEFT JOIN public_high_school_enrollment AS public_schools
		ON public_schools.school_name LIKE CONCAT('%',teams.Team, '%')
UNION
SELECT
	teams.Team AS team_name,
    private_schools.school_name AS school_name,
	"private" AS school_type,
    high_school_enr
FROM (SELECT DISTINCT Team FROM cif_team_results) AS teams
	LEFT JOIN private_high_school_enrollment AS private_schools
		ON private_schools.school_name LIKE CONCAT('%',teams.Team, '%')
)
SELECT team_name AS team, COUNT(school_name)
FROM school_name_matches
GROUP BY team_name
HAVING COUNT(school_name) =0;

-- this temp table reduces later query computation time
-- finds the closest matching school to a team ordered by levenshtein rating
CREATE TEMPORARY TABLE closest_match
SELECT team,
	(
		WITH levenshtein_ratings AS (
			SELECT school_name, levenshtein(school_name, team) AS rating
			FROM public_high_school_enrollment
			UNION
			SELECT school_name, levenshtein(school_name, team) AS rating
			FROM private_high_school_enrollment
		)
		SELECT school_name
		FROM levenshtein_ratings
		ORDER BY rating
		LIMIT 1
    ) AS school_match
FROM teams_with_no_matches;

SELECT * FROM closest_match;

-- main logic of matching a team to school name
CREATE TEMPORARY TABLE matched_schools AS
WITH school_name_matches AS (
SELECT
	teams.Team AS team_name,
    public_schools.school_name AS school_name,
    levenshtein(teams.Team,public_schools.school_name) AS lev_rating,
    high_school_enr
FROM (SELECT DISTINCT Team FROM cif_team_results) AS teams
	LEFT JOIN public_high_school_enrollment AS public_schools
		ON public_schools.school_name LIKE CONCAT('%',teams.Team, '%')
UNION
SELECT
	teams.Team AS team_name,
    private_schools.school_name AS school_name,
    levenshtein(teams.Team,private_schools.school_name) AS lev_rating,
    high_school_enr
FROM (SELECT DISTINCT Team FROM cif_team_results) AS teams
	LEFT JOIN private_high_school_enrollment AS private_schools
		ON private_schools.school_name LIKE CONCAT('%',teams.Team, '%')
)
SELECT team_name AS team, COUNT(school_name) as possible_matches,
	CASE
		WHEN COUNT(school_name) = 1 THEN (SELECT school_name FROM school_name_matches WHERE team_name = team AND school_name IS NOT NULL LIMIT 1)
        WHEN COUNT(school_name) = 0 THEN (SELECT school_match FROM closest_match WHERE team_name=team)
		WHEN COUNT(school_name) > 10 THEN NULL -- too many matches to reasonably know which one is correct
        ELSE 
		(
            SELECT school_name
            FROM school_name_matches 
            WHERE team_name = team AND school_name IS NOT NULL
            ORDER BY lev_rating
            LIMIT 1
		)
	END AS matched_school
FROM school_name_matches
GROUP BY team_name;

-- final table where teams are matched to a shcool name
CREATE TABLE team_school_matches AS
SELECT team, matched_school FROM matched_schools
WHERE NOT (possible_matches = 0 AND levenshtein(team,matched_school) > 2)
AND NOT (matched_school IS NULL)
ORDER BY team;

SELECT * from team_school_matches;

-- levenshtein function used in matching teams to schools
DELIMITER $$
CREATE FUNCTION levenshtein( s1 VARCHAR(255), s2 VARCHAR(255) )
    RETURNS INT
    DETERMINISTIC
    BEGIN
        DECLARE s1_len, s2_len, i, j, c, c_temp, cost INT;
        DECLARE s1_char CHAR;
        -- max strlen=255
        DECLARE cv0, cv1 VARBINARY(256);

        SET s1_len = CHAR_LENGTH(s1), s2_len = CHAR_LENGTH(s2), cv1 = 0x00, j = 1, i = 1, c = 0;

        IF s1 = s2 THEN
            RETURN 0;
        ELSEIF s1_len = 0 THEN
            RETURN s2_len;
        ELSEIF s2_len = 0 THEN
            RETURN s1_len;
        ELSE
            WHILE j <= s2_len DO
                SET cv1 = CONCAT(cv1, UNHEX(HEX(j))), j = j + 1;
            END WHILE;
            WHILE i <= s1_len DO
                SET s1_char = SUBSTRING(s1, i, 1), c = i, cv0 = UNHEX(HEX(i)), j = 1;
                WHILE j <= s2_len DO
                    SET c = c + 1;
                    IF s1_char = SUBSTRING(s2, j, 1) THEN
                        SET cost = 0; ELSE SET cost = 1;
                    END IF;
                    SET c_temp = CONV(HEX(SUBSTRING(cv1, j, 1)), 16, 10) + cost;
                    IF c > c_temp THEN SET c = c_temp; END IF;
                    SET c_temp = CONV(HEX(SUBSTRING(cv1, j+1, 1)), 16, 10) + 1;
                    IF c > c_temp THEN
                        SET c = c_temp;
                    END IF;
                    SET cv0 = CONCAT(cv0, UNHEX(HEX(c))), j = j + 1;
                END WHILE;
                SET cv1 = cv0, i = i + 1;
            END WHILE;
        END IF;
        RETURN c;
    END$$
DELIMITER ;

-- query that gives final results to be exported for visualization
SELECT COUNT(*) FROM (
SELECT team_results.Place AS place, team_results.Team AS team, team_results.Points as points,
(CAST(SUBSTRING_INDEX(team_results.Team_Time_Avg, ':', 1) AS UNSIGNED) * 60) +
CAST(SUBSTRING_INDEX(team_results.Team_Time_Avg, ':', -1) AS UNSIGNED) AS team_time_avg_seconds,
(SELECT MIN(place) FROM cif_individual_results WHERE team = team_results.Team AND division = team_results.Division) AS top_individual_place,
team_results.Division as division, public.school_code, public.school_name,
public.school_type, public.charter, public.high_school_enr, ROUND(grad_data.graduation_rate/100,3) AS grad_rate,
ROUND(CAST(REPLACE(frpm_data.free_meal_percent_eligible_k12,'%','') AS FLOAT) / 100, 3) AS free_meal_eligible,
ROUND(CAST(REPLACE(frpm_data.frpm_eligible_k12,'%','') AS FLOAT) / 100, 3) AS frpm_eligible,
absenteeism.chronic_absenteeism_rate,
CAST(ela_mean_score AS FLOAT) AS ela_mean_score,
ROUND(CAST(ela_perc_standard_exceeded AS FLOAT) / 100, 4) AS ela_perc_standard_exceeded,
ROUND(CAST(ela_perc_standard_met AS FLOAT) / 100, 4) AS ela_perc_standard_met,
ROUND(CAST(ela_perc_standard_met_and_above AS FLOAT) / 100, 4) AS ela_perc_standard_met_and_above,
ROUND(CAST(ela_perc_standard_nearly_met AS FLOAT) / 100, 4) AS ela_perc_standard_nearly_met,
ROUND(CAST(ela_percent_standard_not_met AS FLOAT) / 100, 4) AS ela_percent_standard_not_met,
CAST(math_mean_score AS FLOAT) math_mean_score,
ROUND(CAST(math_perc_standard_exceeded AS FLOAT) / 100, 4) AS math_perc_standard_exceeded,
ROUND(CAST(math_perc_standard_met AS FLOAT) / 100, 4) AS math_perc_standard_met,
ROUND(CAST(math_perc_standard_met_and_above AS FLOAT) / 100, 4) AS math_perc_standard_met_and_above,
ROUND(CAST(math_perc_standard_nearly_met AS FLOAT) / 100, 4) AS math_perc_standard_nearly_met,
ROUND(CAST(math_percent_standard_not_met AS FLOAT) / 100, 4) AS math_percent_standard_not_met
FROM cif_team_results team_results
JOIN team_school_matches_unduplicated matches
ON team_results.Team = matches.team
JOIN public_high_school_enrollment public
ON public.school_name = matches.matched_school
LEFT JOIN public_high_school_graduation_data grad_data
ON public.school_code = grad_data.school_code
LEFT JOIN frpm_data
ON CAST(public.school_code AS UNSIGNED) = frpm_data.school_code
LEFT JOIN public_high_school_absenteeism_data AS absenteeism
ON CAST(public.school_code AS UNSIGNED) = absenteeism.school_code
LEFT JOIN temp_sb_data AS sb_data
ON CAST(public.school_code AS UNSIGNED) = sb_data.school_code
UNION
SELECT team_results.Place AS place, team_results.Team AS team, team_results.Points as points,
(CAST(SUBSTRING_INDEX(team_results.Team_Time_Avg, ':', 1) AS UNSIGNED) * 60) +
CAST(SUBSTRING_INDEX(team_results.Team_Time_Avg, ':', -1) AS UNSIGNED) AS team_time_avg, -- convert to seconds 
(SELECT MIN(place) FROM cif_individual_results WHERE team = team_results.Team AND division = team_results.Division) AS top_individual_place,
team_results.Division as division, private.school_code, private.school_name,
private.school_type, private.charter, private.high_school_enr, NULL AS grad_rate,
NULL AS free_meal_eligible, NULL AS frpm_eligible,
NULL as chronic_absenteeism_rate,
NULL as ela_mean_score,
NULL AS ela_perc_standard_exceeded,
NULL AS ela_perc_standard_met,
NULL AS ela_perc_standard_met_and_above,
NULL AS ela_perc_standard_nearly_met,
NULL AS ela_percent_standard_not_met,
NULL AS math_mean_score,
NULL AS math_perc_standard_exceeded,
NULL AS math_perc_standard_met,
NULL AS math_perc_standard_met_and_above,
NULL AS math_perc_standard_nearly_met,
NULL AS math_percent_standard_not_met
FROM cif_team_results team_results
JOIN team_school_matches_unduplicated matches
ON team_results.Team = matches.team
JOIN private_high_school_enrollment private
ON private.school_name = matches.matched_school
) inter
WHERE charter = 'Y';

-- used in above results query
CREATE TEMPORARY TABLE temp_sb_data
SELECT data_1.school_code AS school_code,
data_1.mean_scale_score AS ela_mean_score,
data_1.percent_standard_exceeded AS ela_perc_standard_exceeded,
data_1.percent_standard_met AS ela_perc_standard_met,
data_1.percent_standard_met_and_above AS ela_perc_standard_met_and_above,
data_1.percent_standard_nearly_met AS ela_perc_standard_nearly_met,
data_1.percent_standard_not_met AS ela_percent_standard_not_met,
data_2.mean_scale_score AS math_mean_score,
data_2.percent_standard_exceeded AS math_perc_standard_exceeded,
data_2.percent_standard_met AS math_perc_standard_met,
data_2.percent_standard_met_and_above AS math_perc_standard_met_and_above,
data_2.percent_standard_nearly_met AS math_perc_standard_nearly_met,
data_2.percent_standard_not_met AS math_percent_standard_not_met
FROM high_school_sb_data data_1
JOIN high_school_sb_data data_2
ON data_1.school_code = data_2.school_code
WHERE data_1.test_id = 1 AND data_2.test_id = 2;

SELECT matched_school, COUNT(matched_school) FROM team_school_matches
GROUP BY matched_school
ORDER BY COUNT(matched_school) DESC;

CREATE TABLE team_school_matches_unduplicated AS
SELECT team, matched_school
FROM (
SELECT * 
FROM team_school_matches matches
JOIN public_high_school_enrollment enrollment
ON matches.matched_school = enrollment.school_name

UNION

SELECT *
FROM team_school_matches matches
JOIN private_high_school_enrollment enrollment
ON matches.matched_school = enrollment.school_name
) matches
GROUP BY team, matched_school
HAVING COUNT(team) < 2
;

SELECT *
FROM team_school_matches matches
JOIN public_high_school_enrollment enrollment
ON matches.matched_school = enrollment.school_name
ORDER BY team
;

SELECT COUNT(*)
FROM team_school_matches matches
JOIN public_high_school_enrollment enrollment
ON matches.matched_school = enrollment.school_name;

-- summary statistics of statewide data
SELECT AVG(graduation_rate) FROM public_high_school_graduation_data;

SELECT AVG(chronic_absenteeism_rate) FROM public_high_school_absenteeism_data;

SELECT chronic_absenteeism_rate FROM absenteeism_data -- statewide chronic absenteeism rate
WHERE aggregate_level = 'T'
AND reporting_category = 'TA'
AND charter = 'All'
AND dass = 'All';

SELECT regular_hs_diploma_graduation_rate -- statewide graduation rate
FROM graduation_outcome_data
WHERE aggregate_level = 'T'
AND reporting_category = 'TA'
AND charter = 'All'
AND dass = 'All';

SELECT 
SUM(free_meal_count_k12) / SUM(enrollment_k12) AS statewide_free_meal_eligible
FROM frpm_data
WHERE high_grade = 12;

SELECT 
SUM(frpm_count_k12) / SUM(enrollment_k12) AS statewide_frpm_eligible
FROM frpm_data
WHERE high_grade = 12;

