/* Question No 1 : You are a data analyst. I need help to extract insights from a customer database. 
I need an overview of sales for 2004, broken down by product, country and city. Ensure you also show sales value, cost of sales and net profit in your output. Add comments to the code to explain the query. 
*/

select t1.orderNumber, t1.orderDate, quantityOrdered, priceEach, productName, productLine, buyPrice, city, country
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join products t3
on t2.productCode = t3.productCode
inner join customers t4
on t1.customerNumber = t4.customerNumber
where year (orderDate) = 2004;


/* Question No 2: You are a data analyst. I need help to extract insights from a customer database. 

I need a MYSQL query to show customer sales by customer and include a column which shows the value of their previous sale, and the difference in this sale compared to their previous sale.
  */
  
/* Question No 3 : You are a data analyst. I need help to extract insights from a customer database. 

I need a MYSQL query to show customer sales by customer, but I also need a money owed column to see if any customers go over their credit limit. */
  

/* Breakdown of what products purchased commonly together? And any products that are rarely purchased together? */

with prod_sales as 
(
select orderNumber, t1.productCode, productLine
from orderdetails t1
inner join products t2
on t1.productCode = t2.productCode
)
select distinct t1.orderNumber, t1.productLine as product_one, t2.productLine as product_two
from prod_sales t1
left join prod_sales t2
on t1.orderNumber = t2.orderNumber and t1.productLine <> t2.productLine;

/* can you show the breakdown of sales, but also show their credit limit? 
maybe group the credit limits as I want a high level view to see if we get higher sales for customers who 
have a higher credit limit which we would expect. */

with sales as
(
select t1.orderNumber, productCode, t1.customerNumber, quantityOrdered, priceEach, priceEach * quantityOrdered as sales_value, creditLimit
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
)
select ordernumber, customerNumber, 
case when creditLimit < 75000 then 'a:less than 75k'
when creditLimit between 75000 and 100000 then 'b:75k-100k'
when creditLimit between 100000 and 150000 then 'c:100k-150k'
when creditLimit > 150000 then 'c: over 150k'
else 'other'
end 
as creditlimit_grouped,
sum(sales_value) as sales_value
from sales
group by ordernumber, customernumber, creditlimit_grouped;


/* customers sales include a column which shows the difference in value from previous sale? 
new customers who make their first purchase are likely to spend more */

with main_cte as
(
select ordernumber, orderdate, customernumber, sum(sales_value) as sales_value
from
(select t1.orderNumber, orderDate, productcode, customerNumber, quantityOrdered * priceEach as Sales_Value
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber) main
group by ordernumber, orderdate, customernumber
),

sales_query as 
(
select t1.*, customerName, row_number() over (partition by customerName order by orderdate) as purchase_number,
lag(sales_value) over (partition by customerName order by orderdate) as previ_sales_value
from main_cte t1
inner join customers t2
on t1.customernumber = t2.customernumber
)
select *, sales_value - previ_sales_value as perchase_value_change
from sales_query
where previ_sales_value is not null;

/* where the customers each office located?*/

with cte_main as
(
select t1.orderNumber, 
t2.productCode, t2.quantityOrdered, t2.priceEach,
quantityOrdered * priceEach as sales_value,
t3.city as customer_city,
t3.country as customer_country,
t4.productLine,
t6.city as office_city, 
t6.country as office_country 
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
inner join products t4
on t2.productCode = t4.productCode
inner join employees t5
on t3.salesRepEmployeeNumber = t5.employeeNumber
inner join offices t6
on t5.officeCode = t6.officeCode
)
select 
ordernumber, 
customer_city,
customer_country,
productline,
office_city,
office_country,
sum(sales_value) as sales_value
from cte_main
group by
ordernumber, 
customer_city,
customer_country,
productline,
office_city,
office_country;

/* we have discovered that shipping is delayed due to bad weather and
 it is possible they will take up to 3 days to arrive. can you get me a list of affected orders?*/
 
 select *,
 date_add(shippeddate, interval 3 day) as latest_arrival,
 case when date_add(shippeddate, interval 3 day) > requiredDate then 1 
 else 0 end as late_flag
 from orders
 where
 (case when date_add(shippeddate, interval 3 day) > requiredDate then 1 
 else 0 end) = 1;
 
 
 
 /* breakdown of each customer and their sales, 
 but include a money owed column as I would like to see if any 
 customers have gone over their credit limit. 
 First Part: */
 
 with cte_main as
 (
 select orderdate, t1.orderNumber, t1.customernumber, customername, productCode, creditlimit, 
 quantityOrdered * priceEach as sales_value
 from orders t1
 inner join orderdetails t2
 on t1.orderNumber = t2.orderNumber
 inner join customers t3
 on t1.customernumber = t3.customerNumber
 ),
 
 running_total_sales as
 (
 select *, lead(orderdate) over (partition by customernumber order by orderdate) as next_order_date
 from 
 
 (
 select orderdate, 
 ordernumber, 
 customernumber, 
 customername, 
 creditlimit, 
 sum(sales_value) as sales_value
 from cte_main
 group by
 orderdate, 
 ordernumber, 
 customernumber, 
 customername, 
 creditlimit
 )subquery
 )
 
 ,
 
 payments_cte as 
 (
 select *
from payments 
 ),
 
 main_cte as 
 
 (
 select t1.*,
 /*row_number() over(partition by customernumber order by orderdate) as purchase_number*/
 sum(sales_value) over(partition by t1.customernumber order by orderdate) as running_total_sales,
 sum(amount) over (partition by t1.customerNumber order by orderdate) as running_total_payments
 from running_total_sales t1
 left join payments_cte t2
 on t1.customerNumber = t2.customerNumber and t2.paymentdate between t1.orderdate and 
 case when 
 t1.next_order_date is null
 then current_date else next_order_date end
)
 select *, running_total_sales - running_total_payments as money_owed,
 creditlimit - (running_total_sales - running_total_payments) as difference 
 from main_cte;
/* Second Part of that question */

/* select *, sum(amount) over (partition by customerNumber order by paymentdate) as running_total_payments
from payments /
 
 