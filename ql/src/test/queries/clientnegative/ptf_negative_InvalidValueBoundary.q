DROP TABLE part;

CREATE TABLE part( 
    p_partkey INT,
    p_name STRING,
    p_mfgr STRING,
    p_brand STRING,
    p_type STRING,
    p_size INT,
    p_container STRING,
    p_retailprice DOUBLE,
    p_comment STRING
);

LOAD DATA LOCAL INPATH '../data/files/part_tiny.txt' overwrite into table part;

-- testInvalidValueBoundary
select  p_mfgr,p_name, p_size,   
sum(p_size) over (w1) as s ,    
dense_rank() as dr  
from part  
window w1 as (partition by p_mfgr order by p_name range between p_name 2 preceding and current row);
