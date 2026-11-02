-- =====================================================
-- Projeto: vendas-erp-sql  |  Módulo financeiro (v2)
-- Arquivo 5: dados do módulo financeiro 
-- Rode DEPOIS dos arquivos 01, 02 e 04.
-- =====================================================

-- Garante que as vendas já foram carregadas
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM contas_receber) = 0 THEN
        RAISE EXCEPTION 'Rode antes os arquivos 01 e 02 (vendas).';
    END IF;
END $$;

SELECT setseed(0.42);

-- Limpeza (sem CASCADE, para não apagar os dados de vendas)
UPDATE clientes SET id_pessoa = NULL;
TRUNCATE rateios, documentos_financeiros RESTART IDENTITY;
DELETE FROM projetos;
DELETE FROM contas_gerenciais;
DELETE FROM centros_custo;
DELETE FROM tipos_documento;
DELETE FROM pessoas;

-- -----------------------------------------------------
-- 1) Tabelas de apoio
-- -----------------------------------------------------
INSERT INTO tipos_documento (id_tipo_documento, descricao, natureza) VALUES
(1, 'Fatura de Venda',            'R'),
(2, 'Nota Fiscal de Serviço',     'R'),
(3, 'Boleto de Cliente',          'R'),
(4, 'Nota Fiscal de Compra',      'P'),
(5, 'Boleto de Fornecedor',       'P'),
(6, 'Despesa Fixa',               'P'),
(7, 'Reembolso de Colaborador',   'P');

INSERT INTO centros_custo (id_centro_custo, nome) VALUES
(1, 'Comercial'), (2, 'Operações'), (3, 'Financeiro'),
(4, 'Tecnologia'), (5, 'Marketing'), (6, 'Administrativo');

INSERT INTO contas_gerenciais (id_conta_gerencial, nome, grupo) VALUES
(1,  'Receita de Produtos',        'Receitas'),
(2,  'Receita de Serviços',        'Receitas'),
(3,  'Outras Receitas',            'Receitas'),
(4,  'Compra de Mercadorias',      'Custos'),
(5,  'Aluguel e Condomínio',       'Despesas Fixas'),
(6,  'Energia e Utilidades',       'Despesas Fixas'),
(7,  'Pessoal e Reembolsos',       'Pessoal'),
(8,  'Marketing e Publicidade',    'Despesas Comerciais'),
(9,  'Impostos e Taxas',           'Impostos'),
(10, 'Despesas Administrativas',   'Despesas Administrativas');

INSERT INTO projetos (id_projeto, nome) VALUES
(1, 'Expansão Região Sul'), (2, 'Novo Site de Vendas'), (3, 'Campanha de Fim de Ano'),
(4, 'Migração de Sistema'), (5, 'Programa de Fidelidade'), (6, 'Reforma da Loja Matriz');

-- -----------------------------------------------------
-- 2) Pessoas
--    ids 1-200 = clientes (iguais ao id_cliente das vendas)
--    ids 201-240 = fornecedores | 241-250 = colaboradores
-- -----------------------------------------------------
INSERT INTO pessoas (id_pessoa, nome, tipo_cadastro, cpf)
SELECT id_cliente, nome, 1, '999' || lpad(id_cliente::text, 6, '0') || '00'
FROM clientes;

-- A ligação entre os dois módulos
UPDATE clientes SET id_pessoa = id_cliente;

INSERT INTO pessoas (id_pessoa, nome, tipo_cadastro, cnpj)
SELECT g,
       (ARRAY['Papelaria','Gráfica','Transportadora','Energia','Telecom','Limpeza','Segurança','Consultoria','Tecnologia','Manutenção'])[1 + floor(random()*10)::int]
       || ' ' ||
       (ARRAY['Aurora','Bandeirante','Cruzeiro','Diamante','Estrela','Futuro','Global','Mineira'])[1 + floor(random()*8)::int]
       || ' Ltda',
       2,
       '99' || lpad(g::text, 6, '0') || '000100'
FROM generate_series(201, 240) AS g;

INSERT INTO pessoas (id_pessoa, nome, tipo_cadastro, cpf)
SELECT g,
       (ARRAY['Marina','Nathan','Olívia','Paulo','Renata','Rafael','Sofia','Tiago'])[1 + floor(random()*8)::int]
       || ' ' ||
       (ARRAY['Lima','Araújo','Ribeiro','Carvalho','Gomes','Martins'])[1 + floor(random()*6)::int],
       3,
       '999' || lpad(g::text, 6, '0') || '00'
FROM generate_series(241, 250) AS g;

-- -----------------------------------------------------
-- 3) Títulos A RECEBER: um para cada parcela (conta a receber)
-- -----------------------------------------------------
INSERT INTO documentos_financeiros
    (id_tipo_documento, id_pessoa, id_conta_receber, numero_documento, data_emissao,
     data_vencimento, data_pagamento, valor_centavos, valor_pago_centavos, situacao)
SELECT
    1 + (cr.id_pedido % 3),
    c.id_pessoa,
    cr.id_conta,
    'R' || lpad(cr.id_pedido::text, 6, '0') || '-' || lpad(cr.parcela::text, 2, '0'),
    p.data_pedido,
    cr.data_vencimento,
    cr.data_pagamento,
    ROUND(cr.valor * 100)::bigint,
    CASE WHEN cr.data_pagamento IS NOT NULL THEN ROUND(cr.valor * 100)::bigint END,
    CASE WHEN cr.data_pagamento IS NOT NULL THEN 2 ELSE 1 END
FROM contas_receber cr
JOIN pedidos  p ON p.id_pedido  = cr.id_pedido
JOIN clientes c ON c.id_cliente = p.id_cliente
ORDER BY cr.id_conta;

-- -----------------------------------------------------
-- 4) Títulos A PAGAR (700): fornecedores e reembolsos
--    - cerca de 20% pagos com atraso, 3% cancelados
-- -----------------------------------------------------
WITH sorteio AS (
    SELECT g,
           4 + floor(random() * 4)::int                       AS id_tipo_documento,
           201 + floor(random() * 40)::int                    AS id_fornecedor,
           241 + floor(random() * 10)::int                    AS id_colaborador,
           CURRENT_DATE - floor(random() * 360)::int          AS data_emissao,
           (ARRAY[7,15,30,30,45])[1 + floor(random()*5)::int] AS prazo,
           random()                                           AS r_cancel,
           random()                                           AS r_atraso,
           floor(random() * 6)::int                           AS dias_adiantado,
           1 + floor(random() * 15)::int                      AS atraso_curto,
           (15000 + floor(power(random(), 2) * 135000))::bigint AS valor_centavos
    FROM generate_series(1, 700) AS g
),
calculo AS (
    SELECT s.*,
           CASE WHEN s.id_tipo_documento = 7 THEN s.id_colaborador
                ELSE s.id_fornecedor END AS id_pessoa,
           s.data_emissao + s.prazo AS data_vencimento,
           s.data_emissao + s.prazo
             + CASE WHEN s.r_atraso < 0.80 THEN -s.dias_adiantado
                    ELSE s.atraso_curto END AS data_pgto,
           (s.r_atraso >= 0.97) AS nunca_paga
    FROM sorteio s
),
final AS (
    SELECT c.*,
           CASE WHEN c.r_cancel < 0.03 THEN 3
                WHEN c.nunca_paga THEN 1
                WHEN c.data_pgto <= CURRENT_DATE THEN 2
                ELSE 1 END AS situacao
    FROM calculo c
)
INSERT INTO documentos_financeiros
    (id_tipo_documento, id_pessoa, id_conta_receber, numero_documento, data_emissao, data_vencimento,
     data_pagamento, valor_centavos, valor_pago_centavos, situacao)
SELECT f.id_tipo_documento, f.id_pessoa, NULL,
       'P' || lpad(f.g::text, 6, '0'),
       f.data_emissao, f.data_vencimento,
       CASE WHEN f.situacao = 2 THEN f.data_pgto END,
       f.valor_centavos,
       CASE WHEN f.situacao = 2 THEN f.valor_centavos END,
       f.situacao
FROM final f
ORDER BY f.g;

-- -----------------------------------------------------
-- 5) Rateio: cada título é dividido em 1 a 3 linhas
--    (100% | 60/40 | 50/30/20) entre centros de custo.
-- -----------------------------------------------------
WITH qtd AS MATERIALIZED (
    SELECT id_documento, 1 + floor(random() * 3)::int AS linhas
    FROM documentos_financeiros
)
INSERT INTO rateios (id_documento, id_centro_custo, id_conta_gerencial, id_projeto, percentual)
SELECT d.id_documento,
       1 + ((d.id_documento + 2 * k) % 6),
       CASE d.id_tipo_documento
            WHEN 1 THEN 1
            WHEN 2 THEN 2
            WHEN 3 THEN CASE WHEN d.id_documento % 4 = 0 THEN 3 ELSE 1 END
            WHEN 4 THEN 4
            WHEN 5 THEN CASE WHEN d.id_documento % 2 = 0 THEN 8 ELSE 10 END
            WHEN 6 THEN CASE d.id_documento % 3 WHEN 0 THEN 5 WHEN 1 THEN 6 ELSE 9 END
            WHEN 7 THEN 7
       END,
       CASE WHEN (d.id_documento + k) % 3 = 0 THEN NULL
            ELSE 1 + (((d.id_documento / 3) + k) % 6) END,
       CASE q.linhas WHEN 1 THEN 100
                     WHEN 2 THEN (ARRAY[60,40])[k]
                     ELSE (ARRAY[50,30,20])[k] END
FROM documentos_financeiros d
JOIN qtd q ON q.id_documento = d.id_documento
CROSS JOIN generate_series(1, 3) AS k
WHERE k <= q.linhas
ORDER BY d.id_documento, k;

-- -----------------------------------------------------
-- 6) Defeitos colocados DE PROPÓSITO (como num ERP real)
-- -----------------------------------------------------
-- 12 rateios que não fecham 100%
UPDATE rateios SET percentual = percentual - 10
WHERE id_rateio IN (SELECT id_rateio FROM rateios WHERE percentual = 100
                    ORDER BY id_rateio LIMIT 12);

-- 6 títulos A PAGAR marcados como pagos, mas sem data de pagamento
UPDATE documentos_financeiros SET data_pagamento = NULL
WHERE id_documento IN (SELECT d.id_documento
                       FROM documentos_financeiros d
                       JOIN tipos_documento t ON t.id_tipo_documento = d.id_tipo_documento
                       WHERE d.situacao = 2 AND t.natureza = 'P'
                       ORDER BY d.id_documento LIMIT 6);

-- 3 clientes sem CPF e 2 clientes com CPF e CNPJ ao mesmo tempo
UPDATE pessoas SET cpf = NULL WHERE id_pessoa IN (5, 17, 33);
UPDATE pessoas SET cnpj = '99' || lpad(id_pessoa::text, 6, '0') || '000100'
WHERE id_pessoa IN (12, 44);

-- -----------------------------------------------------
-- Conferência
-- -----------------------------------------------------
SELECT 'pessoas' AS tabela, COUNT(*) AS linhas FROM pessoas
UNION ALL SELECT 'documentos_financeiros', COUNT(*) FROM documentos_financeiros
UNION ALL SELECT 'rateios', COUNT(*) FROM rateios;