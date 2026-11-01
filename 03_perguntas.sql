---- Regra: faturamento considera apenas pedidos com status ENTREGUE

--===========================================================================

-- 1. Quanto a loja vendeu em cada mês?

select 
to_char(p.data_pedido, 'YYYY-MM') as mes_ano,
sum(ip.quantidade * ip.preco_unitario) as valor_venda
from pedidos p
inner join itens_pedido ip on ip.id_pedido = p.id_pedido 
where p.status = 'ENTREGUE'
group by mes_ano
order by 1;

-- ===========================================================

-- 2. Quais são os 10 produtos mais vendidos?

select 
prod.nome as produto,
sum(ip.quantidade) as quantidade_vendida
from itens_pedido ip 
inner join produtos prod on prod.id_produto = ip.id_produto 
inner join pedidos p on p.id_pedido = ip.id_pedido 
where p.status = 'ENTREGUE'
group by prod.nome
order by quantidade_vendida desc
limit 10;

-- ==============================================================

-- 3. Quais são os 10 clientes que mais geraram faturamento?

select 
c.nome as cliente,
count(distinct p.id_pedido) as quantidade_de_pedidos,
sum(ip.quantidade * ip.preco_unitario) as valor_total_comprado
from pedidos p 
inner join clientes c on c.id_cliente = p.id_cliente 
inner join itens_pedido ip on ip.id_pedido = p.id_pedido 
where p.status = 'ENTREGUE'
group by c.id_cliente
order by valor_total_comprado desc
limit 10;

-- ====================================================================

-- 4. Quais produtos estão com estoque baixo?

select nome as produto, estoque as quantidade_em_estoque
from produtos
where estoque < 10
order by estoque;

-- ===================================================================

-- 5. Quais clientes não compram há mais de 90 dias?

select c.nome as cliente,
       max(p.data_pedido) as data_ultimo_pedido
from clientes c
left join pedidos p on p.id_cliente = c.id_cliente and p.status = 'ENTREGUE'
group by c.id_cliente, c.nome
having max(p.data_pedido) < current_date - 90
    or max(p.data_pedido) is null
order by data_ultimo_pedido;

-- ===================================================================

-- 6. Qual o valor médio de cada pedido?

select round(avg(valor_pedido), 2) as ticket_medio
from (
  select p.id_pedido,
         sum(ip.quantidade * ip.preco_unitario) as valor_pedido
  from pedidos p
  inner join itens_pedido ip on ip.id_pedido = p.id_pedido
  where p.status = 'ENTREGUE'
  group by p.id_pedido
) t;

-- ===================================================================

-- 7. Quais pagamentos estão atrasados e há quantos dias?

select 
cr.id_conta,
c.nome as cliente,
cr.valor,
current_date - cr.data_vencimento as dias_de_atraso
from contas_receber cr 
inner join pedidos p on p.id_pedido = cr.id_pedido 
inner join clientes c on c.id_cliente = p.id_cliente 
where cr.data_pagamento is null
and cr.data_vencimento < current_date 
order by dias_de_atraso desc;

-- ======================================================================

-- 8. Quais categorias dão mais faturamento?

select 
p.categoria as categoria,
sum(ip.quantidade * ip.preco_unitario ) as valor_faturamento
from produtos p
inner join itens_pedido ip on ip.id_produto = p.id_produto 
inner join pedidos ped on ped.id_pedido = ip.id_pedido 
where ped.status = 'ENTREGUE'
group by categoria
order by valor_faturamento desc;

-- ====================================================================

-- 9. As vendas deste mês subiram ou caíram em relação ao mês passado?

WITH vendas_mensais AS (
    SELECT 
        DATE_TRUNC('month', p.data_pedido ) AS mes,
        SUM(ip.quantidade * ip.preco_unitario ) AS total_vendido
    FROM pedidos p 
    inner join itens_pedido ip on ip.id_pedido = p.id_pedido 
    where p.status = 'ENTREGUE'
    GROUP BY DATE_TRUNC('month', p.data_pedido )
),
comparativo AS (
    SELECT 
        mes,
        total_vendido,
        LAG(total_vendido) OVER (ORDER BY mes) AS total_mes_passado
    FROM vendas_mensais
)
SELECT 
    TO_CHAR(mes, 'YYYY-MM') AS mes,
    total_vendido,
    total_mes_passado,
    (total_vendido > total_mes_passado) AS vendeu_mais_que_mes_passado,
    (total_vendido - total_mes_passado) AS diferenca
FROM comparativo
ORDER BY mes desc;

-- =====================================================================

-- 10. Quais são os 3 produtos que mais vendem em cada cidade?

WITH VendasPorCidade AS (
    SELECT 
        c.cidade,
        ip.id_produto ,
        prod.nome as produto,
        SUM(ip.quantidade ) AS total_vendido,
        DENSE_RANK() OVER (PARTITION BY c.cidade ORDER BY SUM(ip.quantidade) DESC) AS ranking
    from pedidos p
    JOIN itens_pedido ip ON p.id_pedido  = ip.id_pedido 
    JOIN clientes c ON c.id_cliente = p.id_cliente 
    join produtos prod on prod.id_produto = ip.id_produto 
    where p.status = 'ENTREGUE'
    GROUP BY c.cidade, ip.id_produto ,prod.nome 
)
SELECT 
    cidade,
    produto,
    total_vendido
FROM VendasPorCidade
where ranking <= 3
order by cidade, ranking ;
