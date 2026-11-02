-- =====================================================
-- Projeto: vendas-erp-sql  |  Módulo financeiro (v2)
-- Arquivo 7: verificações de qualidade dos dados
-- =====================================================

-- 1. Quais títulos têm rateio que não soma 100%?

SELECT
    d.id_documento,
    d.numero_documento,
    SUM(r.percentual) AS soma_percentual
FROM documentos_financeiros d
JOIN rateios r ON r.id_documento = d.id_documento
GROUP BY d.id_documento, d.numero_documento
HAVING SUM(r.percentual) <> 100
ORDER BY d.id_documento;

-- ===================================================================

-- 2. Quais títulos estão como PAGO, mas sem data de pagamento?

SELECT id_documento, numero_documento, data_vencimento, valor
FROM vw_titulos
WHERE situacao = 'PAGO'
  AND data_pagamento IS NULL
ORDER BY id_documento;

-- ===================================================================

-- 3. Quais cadastros não têm CPF nem CNPJ?

SELECT id_pessoa, nome, tipo_cadastro
FROM pessoas
WHERE cpf IS NULL
  AND cnpj IS NULL
ORDER BY id_pessoa;

-- ===================================================================

-- 4. Quais cadastros têm CPF e CNPJ ao mesmo tempo (ambíguo)?

SELECT id_pessoa, nome, cpf, cnpj
FROM pessoas
WHERE cpf IS NOT NULL
  AND cnpj IS NOT NULL
ORDER BY id_pessoa;

-- ===================================================================

-- ##################  LIGAÇÃO ENTRE VENDAS E FINANCEIRO  ##################
-- Estas consultas devem vir VAZIAS (ou com resultado 0).

-- 5. Algum pedido não cancelado ficou sem título financeiro (em nenhuma parcela)?

SELECT p.id_pedido, p.data_pedido
FROM pedidos p
WHERE p.status <> 'CANCELADO'
  AND NOT EXISTS (
      SELECT 1 
      FROM contas_receber cr 
      JOIN documentos_financeiros d ON d.id_conta_receber = cr.id_conta
      WHERE cr.id_pedido = p.id_pedido
  );

-- ===================================================================

-- 6. Algum título financeiro diverge da conta a receber de vendas?
--    (valor, vencimento ou data de pagamento diferentes)

SELECT cr.id_pedido,
       cr.parcela,
       cr.valor                       AS valor_vendas,
       d.valor_centavos / 100.0       AS valor_financeiro,
       cr.data_vencimento             AS venc_vendas,
       d.data_vencimento              AS venc_financeiro,
       cr.data_pagamento              AS pgto_vendas,
       d.data_pagamento               AS pgto_financeiro
FROM contas_receber cr
JOIN documentos_financeiros d ON d.id_conta_receber = cr.id_conta
WHERE ROUND(cr.valor * 100) <> d.valor_centavos
   OR cr.data_vencimento <> d.data_vencimento
   OR cr.data_pagamento IS DISTINCT FROM d.data_pagamento;

-- ===================================================================

-- 7. O valor da soma das parcelas do pedido bate com a soma dos itens do pedido?

SELECT p.id_pedido,
       SUM(cr.valor)                                     AS valor_total_parcelas,
       SUM(ip.quantidade * ip.preco_unitario)            AS soma_itens
FROM pedidos p
JOIN contas_receber cr ON cr.id_pedido = p.id_pedido
JOIN itens_pedido   ip ON ip.id_pedido = p.id_pedido
GROUP BY p.id_pedido
HAVING ROUND(SUM(cr.valor), 2) <> ROUND(SUM(ip.quantidade * ip.preco_unitario), 2);

-- ===================================================================

-- 8. Algum cliente ficou sem cadastro de pessoa (ou com nome diferente)?

SELECT c.id_cliente, c.nome AS nome_vendas, p.nome AS nome_financeiro
FROM clientes c
LEFT JOIN pessoas p ON p.id_pessoa = c.id_pessoa
WHERE p.id_pessoa IS NULL
   OR p.nome <> c.nome;

-- ===================================================================

-- 9. O cliente do pedido é o mesmo do título financeiro?

SELECT d.id_documento, cr.id_pedido
FROM documentos_financeiros d
JOIN contas_receber cr ON cr.id_conta = d.id_conta_receber
JOIN pedidos        p  ON p.id_pedido  = cr.id_pedido
JOIN clientes       c  ON c.id_cliente = p.id_cliente
WHERE c.id_pessoa <> d.id_pessoa;

-- ===================================================================

-- 10. Mapa de relacionamentos: quais tabelas se ligam a quais?

SELECT
    conrelid::regclass  AS tabela,
    a.attname           AS coluna,
    confrelid::regclass AS ligada_a
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
WHERE c.contype = 'f'
ORDER BY 1, 2;

-- ===================================================================

-- 11. Existe alguma tabela sem nenhum relacionamento? (deve vir vazio)

SELECT c.relname AS tabela_sem_relacionamento
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.oid NOT IN (SELECT conrelid FROM pg_constraint WHERE contype = 'f')
  AND c.oid NOT IN (SELECT confrelid FROM pg_constraint WHERE contype = 'f');

-- ===================================================================

-- 12. Resumo: quantos problemas de cada tipo existem?

SELECT 'Rateio que não fecha 100%' AS problema, COUNT(*) AS quantidade
FROM (SELECT id_documento FROM rateios GROUP BY id_documento HAVING SUM(percentual) <> 100) t
UNION ALL
SELECT 'Pago sem data de pagamento', COUNT(*)
FROM documentos_financeiros WHERE situacao = 2 AND data_pagamento IS NULL
UNION ALL
SELECT 'Pessoa sem CPF e sem CNPJ', COUNT(*)
FROM pessoas WHERE cpf IS NULL AND cnpj IS NULL
UNION ALL
SELECT 'Pessoa com CPF e CNPJ', COUNT(*)
FROM pessoas WHERE cpf IS NOT NULL AND cnpj IS NOT NULL
UNION ALL
SELECT 'Pedido sem título financeiro', COUNT(*)
FROM pedidos p WHERE p.status <> 'CANCELADO'
  AND NOT EXISTS (
      SELECT 1 
      FROM contas_receber cr 
      JOIN documentos_financeiros d ON d.id_conta_receber = cr.id_conta
      WHERE cr.id_pedido = p.id_pedido
  )
UNION ALL
SELECT 'Título diverge da conta a receber', COUNT(*)
FROM contas_receber cr 
JOIN documentos_financeiros d ON d.id_conta_receber = cr.id_conta
WHERE ROUND(cr.valor * 100) <> d.valor_centavos
   OR cr.data_vencimento <> d.data_vencimento
   OR cr.data_pagamento IS DISTINCT FROM d.data_pagamento
UNION ALL
SELECT 'Cliente sem pessoa correspondente', COUNT(*)
FROM clientes c LEFT JOIN pessoas p ON p.id_pessoa = c.id_pessoa
WHERE p.id_pessoa IS NULL OR p.nome <> c.nome;