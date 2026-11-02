-- =====================================================
-- Projeto: vendas-erp-sql  |  Módulo financeiro (v2)
-- Arquivo 6: indicadores de contas a receber, a pagar e caixa
-- Todas as consultas usam as views vw_titulos e vw_rateio
-- (criadas no arquivo 04), onde as regras de negócio já
-- estão aplicadas: códigos em texto, CPF/CNPJ unificado e
-- valores em reais.
-- Regras: títulos CANCELADOS ficam fora dos indicadores.
-- =====================================================

-- ##################  CONTAS A RECEBER  ##################

-- 1. Quanto temos a receber em aberto hoje, e quanto disso já venceu?

SELECT
    COUNT(*)                                                   AS qtd_titulos,
    SUM(valor)                                                 AS total_em_aberto,
    COALESCE(SUM(valor) FILTER (WHERE data_vencimento >= CURRENT_DATE), 0) AS a_vencer,
    COALESCE(SUM(valor) FILTER (WHERE data_vencimento <  CURRENT_DATE), 0) AS vencido
FROM vw_titulos
WHERE natureza = 'RECEBER'
  AND situacao = 'ABERTO';

-- ===================================================================

-- 2. Aging (idade da dívida): como o valor em aberto se distribui por faixa de atraso?

SELECT
    CASE
        WHEN data_vencimento >= CURRENT_DATE            THEN '0. A vencer'
        WHEN CURRENT_DATE - data_vencimento <= 30       THEN '1. Vencido de 1 a 30 dias'
        WHEN CURRENT_DATE - data_vencimento <= 60       THEN '2. Vencido de 31 a 60 dias'
        WHEN CURRENT_DATE - data_vencimento <= 90       THEN '3. Vencido de 61 a 90 dias'
        ELSE                                                 '4. Vencido há mais de 90 dias'
    END                                                        AS faixa,
    COUNT(*)                                                   AS qtd_titulos,
    SUM(valor)                                                 AS valor,
    ROUND(100 * SUM(valor) / SUM(SUM(valor)) OVER (), 1)       AS pct_do_total
FROM vw_titulos
WHERE natureza = 'RECEBER'
  AND situacao = 'ABERTO'
GROUP BY 1
ORDER BY 1;

-- ===================================================================

-- 3. Qual é a taxa de inadimplência?
--    (valor vencido e não pago ÷ valor total que já venceu)

SELECT
    SUM(valor) FILTER (WHERE situacao = 'ABERTO')              AS vencido_em_aberto,
    SUM(valor)                                                 AS total_que_ja_venceu,
    ROUND(100.0 * SUM(valor) FILTER (WHERE situacao = 'ABERTO')
          / SUM(valor), 1)                                     AS pct_inadimplencia
FROM vw_titulos
WHERE natureza = 'RECEBER'
  AND situacao <> 'CANCELADO'
  AND data_vencimento < CURRENT_DATE;

-- ===================================================================

-- 4. A inadimplência está melhorando ou piorando? (por mês de vencimento)
--    Atenção: os meses mais recentes tendem a parecer piores, porque
--    muitos clientes ainda vão pagar com atraso.

SELECT
    to_char(data_vencimento, 'YYYY-MM')                        AS mes_vencimento,
    SUM(valor)                                                 AS total_vencido,
    COALESCE(SUM(valor) FILTER (WHERE situacao = 'ABERTO'), 0) AS ainda_em_aberto,
    ROUND(100.0 * COALESCE(SUM(valor) FILTER (WHERE situacao = 'ABERTO'), 0)
          / SUM(valor), 1)                                     AS pct_inadimplencia
FROM vw_titulos
WHERE natureza = 'RECEBER'
  AND situacao <> 'CANCELADO'
  AND data_vencimento < CURRENT_DATE
GROUP BY 1
ORDER BY 1;

-- ===================================================================

-- 5. Quem são os 10 maiores devedores vencidos e quanto da dívida eles concentram?

WITH devedores AS (
    SELECT
        id_pessoa,
        pessoa,
        COUNT(*)                          AS qtd_titulos,
        SUM(valor)                        AS valor_vencido,
        MAX(CURRENT_DATE - data_vencimento) AS maior_atraso_dias
    FROM vw_titulos
    WHERE natureza = 'RECEBER'
      AND situacao = 'ABERTO'
      AND data_vencimento < CURRENT_DATE
    GROUP BY id_pessoa, pessoa
)
SELECT
    pessoa,
    qtd_titulos,
    valor_vencido,
    maior_atraso_dias,
    ROUND(100.0 * valor_vencido / SUM(valor_vencido) OVER (), 1)                         AS pct_do_vencido,
    ROUND(100.0 * SUM(valor_vencido) OVER (ORDER BY valor_vencido DESC)
          / SUM(valor_vencido) OVER (), 1)                                               AS pct_acumulado
FROM devedores
ORDER BY valor_vencido DESC
LIMIT 10;

-- ===================================================================

-- 6. Quanto foi faturado e quanto foi recebido em cada mês?

WITH emitido AS (
    SELECT date_trunc('month', data_emissao) AS mes, SUM(valor) AS valor_emitido
    FROM vw_titulos
    WHERE natureza = 'RECEBER' AND situacao <> 'CANCELADO'
    GROUP BY 1
),
recebido AS (
    SELECT date_trunc('month', data_pagamento) AS mes, SUM(valor) AS valor_recebido
    FROM vw_titulos
    WHERE natureza = 'RECEBER' AND situacao = 'PAGO' AND data_pagamento IS NOT NULL
    GROUP BY 1
)
SELECT
    to_char(COALESCE(e.mes, r.mes), 'YYYY-MM') AS mes,
    COALESCE(e.valor_emitido, 0)               AS faturado,
    COALESCE(r.valor_recebido, 0)              AS recebido
FROM emitido e
FULL JOIN recebido r ON r.mes = e.mes
ORDER BY 1;

-- ##################  PRAZOS (RECEBER E PAGAR)  ##################

-- 7. Qual o prazo médio de recebimento e de pagamento? Quanto é pago com atraso?

SELECT
    natureza,
    COUNT(*)                                                           AS titulos_pagos,
    ROUND(AVG(data_pagamento - data_emissao), 1)                       AS prazo_medio_dias,
    ROUND(100.0 * COUNT(*) FILTER (WHERE data_pagamento > data_vencimento)
          / COUNT(*), 1)                                               AS pct_pagos_com_atraso,
    ROUND(AVG(data_pagamento - data_vencimento)
          FILTER (WHERE data_pagamento > data_vencimento), 1)          AS atraso_medio_quando_atrasa
FROM vw_titulos
WHERE situacao = 'PAGO'
  AND data_pagamento IS NOT NULL
GROUP BY natureza
ORDER BY natureza;

-- ##################  CONTAS A PAGAR  ##################

-- 8. Quanto vence a pagar nas próximas semanas (30 dias)?

SELECT
    date_trunc('week', data_vencimento)::date AS semana_inicio,
    COUNT(*)                                  AS qtd_titulos,
    SUM(valor)                                AS a_pagar
FROM vw_titulos
WHERE natureza = 'PAGAR'
  AND situacao = 'ABERTO'
  AND data_vencimento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
GROUP BY 1
ORDER BY 1;

-- ===================================================================

-- 9. Quais são os 10 fornecedores para quem mais pagamos?

SELECT
    pessoa                                                     AS fornecedor,
    COUNT(*)                                                   AS qtd_titulos,
    SUM(valor)                                                 AS valor_total,
    ROUND(100 * SUM(valor) / SUM(SUM(valor)) OVER (), 1)       AS pct_do_total
FROM vw_titulos
WHERE natureza = 'PAGAR'
  AND tipo_pessoa = 'Fornecedor'
  AND situacao <> 'CANCELADO'
GROUP BY id_pessoa, pessoa
ORDER BY valor_total DESC
LIMIT 10;

-- ===================================================================

-- 10. Quanto cada centro de custo gastou? (valor dividido conforme o rateio)

SELECT
    centro_custo,
    SUM(valor_rateado)                                         AS despesa,
    ROUND(100 * SUM(valor_rateado) / SUM(SUM(valor_rateado)) OVER (), 1) AS pct_do_total
FROM vw_rateio
WHERE natureza = 'PAGAR'
  AND situacao <> 'CANCELADO'
GROUP BY centro_custo
ORDER BY despesa DESC;

-- ===================================================================

-- 11. Em quais tipos de despesa o dinheiro está indo?

SELECT
    grupo_conta,
    conta_gerencial,
    SUM(valor_rateado)                                         AS despesa
FROM vw_rateio
WHERE natureza = 'PAGAR'
  AND situacao <> 'CANCELADO'
GROUP BY grupo_conta, conta_gerencial
ORDER BY grupo_conta, despesa DESC;

-- ##################  CAIXA  ##################

-- 12. Como foi o fluxo de caixa de cada mês e qual o saldo acumulado?

WITH movimento AS (
    SELECT
        date_trunc('month', data_pagamento)::date AS mes,
        COALESCE(SUM(valor) FILTER (WHERE natureza = 'RECEBER'), 0) AS entradas,
        COALESCE(SUM(valor) FILTER (WHERE natureza = 'PAGAR'), 0)   AS saidas
    FROM vw_titulos
    WHERE situacao = 'PAGO'
      AND data_pagamento IS NOT NULL
    GROUP BY 1
)
SELECT
    to_char(mes, 'YYYY-MM')                      AS mes,
    entradas,
    saidas,
    entradas - saidas                            AS saldo_do_mes,
    SUM(entradas - saidas) OVER (ORDER BY mes)   AS saldo_acumulado
FROM movimento
ORDER BY mes;

-- ===================================================================

-- 13. Qual o fluxo previsto para as próximas 8 semanas (a receber menos a pagar)?

SELECT
    date_trunc('week', data_vencimento)::date                                AS semana_inicio,
    COALESCE(SUM(valor) FILTER (WHERE natureza = 'RECEBER'), 0)              AS a_receber,
    COALESCE(SUM(valor) FILTER (WHERE natureza = 'PAGAR'), 0)                AS a_pagar,
    COALESCE(SUM(valor) FILTER (WHERE natureza = 'RECEBER'), 0)
      - COALESCE(SUM(valor) FILTER (WHERE natureza = 'PAGAR'), 0)            AS saldo_previsto
FROM vw_titulos
WHERE situacao = 'ABERTO'
  AND data_vencimento BETWEEN CURRENT_DATE AND CURRENT_DATE + 56
GROUP BY 1
ORDER BY 1;

-- ===================================================================

-- 14. Qual o resultado (receitas menos despesas) de cada projeto?

SELECT
    COALESCE(projeto, '(sem projeto)')                                       AS projeto,
    COALESCE(SUM(valor_rateado) FILTER (WHERE natureza = 'RECEBER'), 0)      AS receitas,
    COALESCE(SUM(valor_rateado) FILTER (WHERE natureza = 'PAGAR'), 0)        AS despesas,
    COALESCE(SUM(valor_rateado) FILTER (WHERE natureza = 'RECEBER'), 0)
      - COALESCE(SUM(valor_rateado) FILTER (WHERE natureza = 'PAGAR'), 0)    AS resultado
FROM vw_rateio
WHERE situacao <> 'CANCELADO'
GROUP BY 1
ORDER BY resultado DESC;

-- ##################  VENDAS x FINANCEIRO  ##################
-- (usam o vínculo entre o título financeiro e o pedido de venda)

-- 15. Qual a inadimplência por cidade do cliente?

SELECT
    c.cidade,
    COUNT(*)                                                   AS titulos_vencidos,
    SUM(t.valor)                                               AS total_vencido,
    COALESCE(SUM(t.valor) FILTER (WHERE t.situacao = 'ABERTO'), 0) AS em_aberto,
    ROUND(100.0 * COALESCE(SUM(t.valor) FILTER (WHERE t.situacao = 'ABERTO'), 0)
          / SUM(t.valor), 1)                                   AS pct_inadimplencia
FROM vw_titulos t
JOIN pedidos  p ON p.id_pedido  = t.id_pedido
JOIN clientes c ON c.id_cliente = p.id_cliente
WHERE t.natureza = 'RECEBER'
  AND t.situacao <> 'CANCELADO'
  AND t.data_vencimento < CURRENT_DATE
GROUP BY c.cidade
ORDER BY pct_inadimplencia DESC;

-- ===================================================================

-- 16. Quais categorias de produto estão nos pedidos que ficaram em aberto (vencidos)?

SELECT
    pr.categoria,
    COUNT(DISTINCT t.id_pedido)                                AS pedidos_vencidos_em_aberto,
    SUM(ip.quantidade * ip.preco_unitario)                     AS valor_dos_itens
FROM vw_titulos t
JOIN itens_pedido ip ON ip.id_pedido  = t.id_pedido
JOIN produtos     pr ON pr.id_produto = ip.id_produto
WHERE t.natureza = 'RECEBER'
  AND t.situacao = 'ABERTO'
  AND t.data_vencimento < CURRENT_DATE
GROUP BY pr.categoria
ORDER BY valor_dos_itens DESC;
