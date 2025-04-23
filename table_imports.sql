USE xc_analysis;

CREATE TABLE cif_individual_results
(
	result_index INT,
    place INT,
    athlete VARCHAR(128),
    grade INT,
    team VARCHAR(128),
    mark CHAR(8),
    points INT,
    cif_section CHAR(2),
    division CHAR(2)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Documents/personal-projects/xc-analysis/cif-individual-results.csv' INTO TABLE cif_individual_results
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

DROP TABLE census_day_enrollment;
CREATE TABLE census_day_enrollment
(
	academic_year CHAR(7),
    aggregate_level CHAR(1),
    county_code VARCHAR(16),
    district_code VARCHAR(16),
    school_code VARCHAR(16),
    county_name VARCHAR(16),
    district_name VARCHAR(64),
    school_name VARCHAR(64),
    charter VARCHAR(8),
    reporting_category VARCHAR(16),
    total_enr VARCHAR(16),
    gr_tk VARCHAR(8),
	gr_kn VARCHAR(8),
    gr_01 VARCHAR(8),
    gr_02 VARCHAR(8),
    gr_03 VARCHAR(8),
    gr_04 VARCHAR(8),
    gr_05 VARCHAR(8),
    gr_06 VARCHAR(8),
    gr_07 VARCHAR(8),
    gr_08 VARCHAR(8),
    gr_09 VARCHAR(8),
    gr_10 VARCHAR(8),
    gr_11 VARCHAR(8),
    gr_12 VARCHAR(8)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/census_day_enrollment.csv' INTO TABLE census_day_enrollment
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

CREATE TABLE private_school_data
(
	cds_code BIGINT,
    county_name VARCHAR(16),
    public_district_name VARCHAR(64),
    school_name VARCHAR(128),
    gr_kn INT,
    gr_01 INT,
    gr_02 INT,
    gr_03 INT,
    gr_04 INT,
    gr_05 INT,
    gr_06 INT,
    gr_07 INT,
    gr_08 INT,
    gr_09 INT,
    gr_10 INT,
    gr_11 INT,
    gr_12 INT,
    total_enr INT,
    prev_year_grads INT,
    full_time_teachers INT,
    part_time_teachers INT,
    administrators INT,
    other_staff INT
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/privateschooldata2324.csv' INTO TABLE private_school_data
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

CREATE TABLE graduation_outcome_data
(
academic_year CHAR(7),
    aggregate_level CHAR(1),
    county_code VARCHAR(16),
    district_code VARCHAR(16),
    school_code VARCHAR(16),
    county_name VARCHAR(16),
    district_name VARCHAR(64),
    school_name VARCHAR(64),
    charter VARCHAR(8),
    dass VARCHAR(8),
    reporting_category CHAR(2),
    cohort_students VARCHAR(16),
    regular_hs_diploma_graduates_count VARCHAR(16),
    regular_hs_diploma_graduation_rate VARCHAR(16)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/acgr24.csv' INTO TABLE graduation_outcome_data
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

CREATE TABLE frpm_data
(
academic_year CHAR(7),
    county_code VARCHAR(16),
    district_code VARCHAR(16),
    school_code VARCHAR(16),
    county_name VARCHAR(16),
    district_name VARCHAR(64),
    school_name VARCHAR(64),
    district_type VARCHAR(64),
    school_type VARCHAR(64),
    ed_option_type VARCHAR(64),
    charter VARCHAR(8),
    charter_school_number VARCHAR(8),
    charter_funding_type VARCHAR(32),
    irc VARCHAR(4),
    low_grade VARCHAR(4),
    high_grade VARCHAR(4),
    enrollment_k12 INT,
    free_meal_count_k12 INT,
    free_meal_percent_eligible_k12 VARCHAR(8),
    frpm_count_k12 INT,
    frpm_eligible_k12 VARCHAR(8)
    
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/frpm2324/FRPM_school_data.csv' INTO TABLE frpm_data
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

CREATE TABLE absenteeism_data
(
academic_year CHAR(7),
    aggregate_level CHAR(1),
    county_code VARCHAR(16),
    district_code VARCHAR(16),
    school_code VARCHAR(16),
    county_name VARCHAR(16),
    district_name VARCHAR(64),
    school_name VARCHAR(64),
    charter VARCHAR(8),
    dass VARCHAR(8),
    reporting_category VARCHAR(8),
    chronic_absenteeism_eligible_enrollment VARCHAR(16),
    chronic_absenteeism_count VARCHAR(16),
    chronic_absenteeism_rate VARCHAR(16)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/chronicabsenteeism24.csv' INTO TABLE absenteeism_data
FIELDS TERMINATED BY ','
IGNORE 1 LINES;

CREATE TABLE sb_entities
(
	county_code CHAR(2),
    district_code CHAR(5),
    school_code CHAR(7),
    type_id CHAR(2),
    filler CHAR(4),
    test_year CHAR(4),
    county_name VARCHAR(25),
    district_name VARCHAR(40),
    school_name VARCHAR(60),
    school_zip_code VARCHAR(9)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/sb_ca2024_all_csv_v1/sb_ca2024entities_csv.txt' INTO TABLE sb_entities
FIELDS TERMINATED BY '^'
IGNORE 1 LINES;

CREATE TABLE sb_data
(
	county_code CHAR(2),
    district_code CHAR(5),
    district_name VARCHAR(40),
    school_code CHAR(7),
    school_name VARCHAR(60),
    type_id CHAR(2),
    filler CHAR(4),
    test_year CHAR(4),
    test_type CHAR(1),
    test_id CHAR(2),
    student_group_id CHAR(3),
    grade CHAR(2),
    total_students_enrolled VARCHAR(9),
    total_students_tested VARCHAR(9),
    total_students_test_with_scores VARCHAR(9),
    mean_scale_score CHAR(6),
    percent_standard_exceeded CHAR(6),
    count_standard_exceeded VARCHAR(9),
    percent_standard_met CHAR(6),
    count_standard_met VARCHAR(9),
    percent_standard_met_and_above CHAR(6),
    count_standard_met_and_above VARCHAR(9),
    percent_standard_nearly_met CHAR(6),
    count_standard_nearly_met VARCHAR(9),
    percent_standard_not_met CHAR(6),
    count_standard_not_met VARCHAR(9),
    overall_total VARCHAR(9)
);

LOAD DATA LOCAL INFILE '/Users/natewebster/Downloads/sb_ca2024_all_csv_v1/sb_ca2024_all_csv_v1.txt' INTO TABLE sb_data
FIELDS TERMINATED BY '^'
IGNORE 1 LINES;