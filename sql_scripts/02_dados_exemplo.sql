-- =====================================================
-- Projeto: vendas-erp-sql
-- Arquivo 2: gera dados fictícios 
-- Rode DEPOIS do 01_criar_tabelas.sql
-- =====================================================
 
 
SELECT setseed(0.42);
 
 
TRUNCATE contas_receber, itens_pedido, pedidos, produtos, clientes
RESTART IDENTITY CASCADE;
 
 
INSERT INTO clientes (nome, cidade, estado, data_cadastro)
SELECT
    (ARRAY['Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabriela','Hugo','Isabela','João',
           'Karina','Lucas','Marina','Nathan','Olívia','Paulo','Renata','Rafael','Sofia','Tiago'])[n1]
    || ' ' ||
    (ARRAY['Silva','Souza','Oliveira','Santos','Pereira','Costa','Rodrigues','Almeida',
           'Nascimento','Lima','Araújo','Ribeiro','Carvalho','Gomes','Martins'])[n2],
    (ARRAY['Belo Horizonte','Contagem','Betim','Uberlândia','São Paulo','Campinas','Rio de Janeiro','Curitiba'])[c],
    (ARRAY['MG','MG','MG','MG','SP','SP','RJ','PR'])[c],
    CURRENT_DATE - (400 + floor(random() * 300))::int   
FROM (
    SELECT 1 + floor(random() * 20)::int AS n1,
           1 + floor(random() * 15)::int AS n2,
           1 + floor(random() * 8)::int  AS c
    FROM generate_series(1, 200)
) AS sorteio;
 
 
INSERT INTO produtos (nome, categoria, preco, estoque) VALUES
('Fone de Ouvido Bluetooth', 'Eletrônicos', 159.90, 45),
('Carregador Portátil 10000mAh', 'Eletrônicos', 119.90, 8),
('Mouse Sem Fio', 'Eletrônicos', 69.90, 60),
('Teclado Compacto', 'Eletrônicos', 139.90, 32),
('Webcam Full HD', 'Eletrônicos', 189.90, 5),
('Caixa de Som Portátil', 'Eletrônicos', 229.90, 21),
('Smartwatch Básico', 'Eletrônicos', 299.90, 14),
('Cabo USB-C 2m', 'Eletrônicos', 29.90, 120),
('Caderno Universitário', 'Papelaria', 24.90, 150),
('Caneta Gel (caixa com 10)', 'Papelaria', 19.90, 200),
('Agenda 2026', 'Papelaria', 39.90, 70),
('Mochila Escolar', 'Papelaria', 119.90, 6),
('Marcador de Texto (kit)', 'Papelaria', 14.90, 180),
('Pasta Organizadora', 'Papelaria', 22.90, 90),
('Jogo de Panelas', 'Casa', 249.90, 18),
('Conjunto de Facas', 'Casa', 89.90, 40),
('Liquidificador', 'Casa', 169.90, 9),
('Jogo de Toalhas', 'Casa', 79.90, 55),
('Luminária de Mesa', 'Casa', 59.90, 33),
('Organizador de Armário', 'Casa', 49.90, 75),
('Garrafa Térmica 1L', 'Casa', 64.90, 48),
('Tapete de Yoga', 'Esporte', 79.90, 28),
('Halteres 2kg (par)', 'Esporte', 59.90, 4),
('Corda de Pular', 'Esporte', 24.90, 85),
('Bola de Futebol', 'Esporte', 99.90, 30),
('Garrafa Esportiva 750ml', 'Esporte', 34.90, 110),
('Faixa Elástica (kit)', 'Esporte', 44.90, 65),
('Mochila de Hidratação', 'Esporte', 149.90, 12),
('Munhequeira (par)', 'Esporte', 19.90, 95),
('Bolsa Térmica', 'Esporte', 89.90, 22);
 
 
INSERT INTO pedidos (id_cliente, data_pedido, status)
SELECT
    1 + floor(random() * 200)::int,
    CURRENT_DATE - floor(random() * 365)::int,
    CASE WHEN random() < 0.08 THEN 'CANCELADO' ELSE 'ENTREGUE' END
FROM generate_series(1, 1000);
 
 
INSERT INTO itens_pedido (id_pedido, id_produto, quantidade, preco_unitario)
SELECT
    s.id_pedido,
    s.id_produto,
    1 + floor(random() * 4)::int,
    pr.preco
FROM (
    SELECT DISTINCT
        q.id_pedido,
        1 + floor(30 * power(random(), 1.5))::int AS id_produto
    FROM (
        SELECT id_pedido, 1 + floor(random() * 4)::int AS qtd_itens
        FROM pedidos
    ) AS q
    CROSS JOIN generate_series(1, 4) AS g
    WHERE g <= q.qtd_itens
) AS s
JOIN produtos pr ON pr.id_produto = s.id_produto;
 
 
-- Contas a receber: cada pedido não cancelado gera 1 parcela (60%) ou 10 parcelas (40%).
-- Pagamento (realista, parcela por parcela):
--   * ~90% das parcelas são pagas; ~10% nunca são pagas (inadimplência de verdade);
--   * 75% pagam em dia ou até 5 dias antes do vencimento; 25% pagam com 1 a 20 dias de atraso;
--   * só existe data de pagamento se ela já aconteceu (nunca fica no futuro).
WITH parcelas AS MATERIALIZED (
    SELECT
        p.id_pedido,
        g.n                                    AS parcela,
        sub.qtd_parcelas                       AS total_parcelas,
        ROUND(sub.total / sub.qtd_parcelas, 2) AS valor,
        p.data_pedido + (g.n * 30)             AS data_vencimento,
        random()                               AS r_paga,
        random()                               AS r_atraso,
        floor(random() * 6)::int               AS dias_adiantado,
        1 + floor(random() * 20)::int          AS dias_atraso
    FROM (
        SELECT
            pd.id_pedido,
            pd.data_pedido,
            SUM(i.quantidade * i.preco_unitario) AS total,
            CASE WHEN random() < 0.4 THEN 10 ELSE 1 END AS qtd_parcelas
        FROM pedidos pd
        JOIN itens_pedido i ON i.id_pedido = pd.id_pedido
        WHERE pd.status <> 'CANCELADO'
        GROUP BY pd.id_pedido, pd.data_pedido
    ) sub
    JOIN pedidos p ON p.id_pedido = sub.id_pedido
    CROSS JOIN LATERAL generate_series(1, sub.qtd_parcelas) AS g(n)
),
calculo AS (
    SELECT pa.*,
           pa.data_vencimento
             + CASE WHEN pa.r_atraso < 0.75 THEN -pa.dias_adiantado
                    ELSE pa.dias_atraso END AS data_pgto_prevista
    FROM parcelas pa
)
INSERT INTO contas_receber (id_pedido, parcela, total_parcelas, valor, data_vencimento, data_pagamento)
SELECT
    id_pedido,
    parcela,
    total_parcelas,
    valor,
    data_vencimento,
    CASE WHEN r_paga < 0.90 AND data_pgto_prevista <= CURRENT_DATE
         THEN data_pgto_prevista END
FROM calculo
ORDER BY id_pedido, parcela;
 
 
SELECT 'clientes'       AS tabela, COUNT(*) AS linhas FROM clientes
UNION ALL SELECT 'produtos',       COUNT(*) FROM produtos
UNION ALL SELECT 'pedidos',        COUNT(*) FROM pedidos
UNION ALL SELECT 'itens_pedido',   COUNT(*) FROM itens_pedido
UNION ALL SELECT 'contas_receber', COUNT(*) FROM contas_receber;