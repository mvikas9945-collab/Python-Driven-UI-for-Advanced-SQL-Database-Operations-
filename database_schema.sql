-- 1 Total Supplers
select count(*) as Total_Supplers
from suppliers
-- 2 Total_suppliers
select * as Total_Products
from products

-- 3 Total product categories
select count(distinct category) from products

-- 4 Total sales in last 3 months value (quantity * price)
select round(sum(abs(se.change_quantity)*p.price),2) as TOTAL3monthSALES
from stock_entries as se
join products p on se.product_id=p.product_id
where se.change_type='sale'
and 
se.entry_date>=(select date_sub(max(entry_date),interval 3 month)from stock_entries)

-- 5 total restock value last 3month

select round(sum(abs(se.change_quantity)*p.price),2) as TOTAL3monthSALES
from stock_entries as se
join products p on se.product_id=p.product_id
where se.change_type='restock'
and 
se.entry_date>=(select date_sub(max(entry_date),interval 3 month)from stock_entries)

-- 6 Reorder data
select count(*) from products p where p.stock_quantity<p.reorder_level
and product_id not in(select distinct product_id from reorders where status='Pending')

-- 7 Supplier contact Details

select supplier_name,contact_name,email,phone from suppliers

-- 8 product with thier suppliers and current stock

select p.product_name,s.supplier_name,p.stock_quantity,p.reorder_level from products p
join suppliers s on p.supplier_id=s.supplier_id
order by p.product_name asc

-- 9 product needing reorder
select product_id,product_name,stock_quantity,reorder_level from products where stock_quantity<reorder_level

-- 10. Add new product // for that need to change 3 table for example if new peroduct arrives it has be update stock entries and the shippment arrives 
-- for we create store procedure to know about restock and changes in all dependent tables
-- Add an new product to the database
delimiter $$
create procedure AddNewProductManualID(
   in p_name varchar(255),
   in p_category  varchar(100),
   in p_price decimal(10,2),
   in p_stock int,
   in p_reorder int,
   in p_supplier int
)
Begin
  declare  new_prod_id int;
  declare  new_shipment_id int;
  declare new_entry_id int;
  
  #make chnages in product table
  #generate the product id
  select max(product_id)+1  into  new_prod_id from products;
  insert into products( product_id,product_name , category, price , stock_quantity, reorder_level, supplier_id)
  values(new_prod_id,p_name,p_category,p_price,p_stock,p_reorder,p_supplier);
  
  
  #make changes in shipment table
  # generate the shipment id
  select max(shipment_id)+1 into new_shipment_id from shipments;
  insert into shipments (shipment_id , product_id , supplier_id , quantity_received, shipment_date)
  values(new_shipment_id,new_prod_id,p_supplier,p_stock, curdate());
  
  
  # make chnages in stock_entries
  select max(entry_id)+1 into new_entry_id from stock_entries;
  insert  into stock_entries(entry_id , product_id , change_quantity , change_type , entry_date)
  values (new_entry_id,new_prod_id, p_stock, "Restock", curdate());
end $$
Delimiter ;

call AddNewProductManualID('Smart Watch', 'Electronics', 99.99,100,25,5)

select * from products where product_name="smart watch"
select * from shipments where product_id=201

-- 11 Product History , [ finding shipment , sales , purchase]
create or replace view product_inventory_history as 
select 
pih.product_id ,
pih.record_type,
pih.record_date,
pih.Quantity,
pih.change_type,
pr.supplier_id
 from 
(
select product_id ,
"Shipment" as record_type,
shipment_date  as record_date,
quantity_received as Quantity,
null change_type
from shipments

union all

select 
product_id ,
"Stock Entry" as record_type,
entry_date as record_date,
change_quantity  as quantity,
change_type
from stock_entries
)pih
join products  pr on pr.product_id= pih.product_id
select * from reorders
where reorder_date =curdate()

-- 13  receive reorder
delimiter $$
create procedure  MarkReorderAsReceived( in in_reorder_id int)
begin
declare prod_id int;
declare qty int;
declare sup_id int;
declare new_shipment_id int;
declare new_entry_id int;

start Transaction;

# get product_id , quantity  from reorders
select Product_id , reorder_quantity 
into prod_id,qty
from  reorders
where reorder_id = in_reorder_id;

# Get supplier_id from Products
select supplier_id
into sup_id 
from products 
where product_id= prod_id;

# upate reorder table -- Received
update reorders 
set status= "Received"
where reorder_id=in_reorder_id;

# update quantity in product table
update products 
set stock_quantity= stock_quantity+qty
where product_id= prod_id;

# Insert record into shipment table
select max(shipment_id)+1  into new_shipment_id from shipments ;
insert  into shipments(shipment_id , product_id , supplier_id , quantity_received , shipment_date)
values (new_shipment_id, prod_id , sup_id , qty, curdate());

# Insert record into  Restock 
select max(entry_id)+1  into new_entry_id from stock_entries;
insert  into stock_entries(entry_id , product_id , change_quantity , change_type , entry_date)
values(new_entry_id,prod_id, qty , "Restock", curdate());

commit;
End$$ 

Delimiter;

set sql_safe_updates=0

call MarkReorderAsReceived(2)




select * from reorders where  reorder_id=13


select * from products where product_name= "Someone Shirt"


select * from reorders where reorder_id= 1

select * from stock_entries where product_id=164 order by entry_date desc
select * from shipments  order  by shipment_id desc
