-- get Registered Patients 
select count(1)
from   patients p;

-- Find out how many patients have a registered date of birth
select count(1)
from   patients p
where  p.dob is not null;

-- Get the minimum and maximum date of birth and date of death of the patients
select min(p.dob) as min_fecha_nacimiento
       , max(p.dob) as max_fecha_nacimiento
       , min(a.deathtime) as min_fecha_muerte
       , max(a.deathtime) as max_fecha_muerte
from   patients p
join   admissions a on a.subject_id  = p.subject_id;

-- Get patients admitted between 211001 and 221410 and born between 211001 and 221410
select count(1)
from
(
  select subject_id
        , (
            select a.hadm_id
            from   admissions a 
            where  a.subject_id = p.subject_id
            and    TO_CHAR(a.admittime, 'YYYYMM') >= '211001' 
            and    TO_CHAR(a.admittime, 'YYYYMM')  <= '221410'
            and    a.admittime = (
                                  select min(admittime)
                                  from   admissions a2
                                  where  a2.subject_id = a.subject_id   
                                  and    TO_CHAR(a.admittime, 'YYYYMM') >= '211001' 
                                  and    TO_CHAR(a.admittime, 'YYYYMM')  <= '221410'       						
                                )
            ) as hadm_id
  from   patients p
  where  p.dob is not null
  and    TO_CHAR(p.dob, 'YYYYMM') >= '211001' 
  and    TO_CHAR(p.dob, 'YYYYMM')  <= '221410'	   
) X

SELECT *
FROM   diagnoses_icd


SELECT * 
FROM   mimiciv.cohort_newborn_diagnoses d
WHERE  d.diagnoses_group = 'GDG_80'


