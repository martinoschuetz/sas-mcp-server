libname test "C:\Program Files\SASHome94\SASFoundation\9.4\dmine\sample";

data tmp;
set test.assocs;
product2=product;
run;

proc sql; create table tmp2 as select
distinct a.product as first,
         b.product as second,
        count(distinct a.customer) as n_Trans
from tmp as a left join tmp as b on a.customer=b.customer
group by a.product, b.product;
quit;

