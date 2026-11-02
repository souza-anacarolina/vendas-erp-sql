-- =====================================================
-- Projeto: vendas-erp-sql  |  Módulo financeiro (v2)
-- =====================================================

DROP VIEW  IF EXISTS vw_rateio;
DROP VIEW  IF EXISTS vw_titulos;
DROP TABLE IF EXISTS rateios               CASCADE;
DROP TABLE IF EXISTS documentos_financeiros CASCADE;
DROP TABLE IF EXISTS projetos              CASCADE;
DROP TABLE IF EXISTS contas_gerenciais     CASCADE;
DROP TABLE IF EXISTS centros_custo         CASCADE;
DROP TABLE IF EXISTS tipos_documento       CASCADE;
DROP TABLE IF EXISTS pessoas               CASCADE;

-- Cadastro único de pessoas, como em muitos ERPs.
-- Cada cliente do módulo de vendas tem uma pessoa correspondente.
-- tipo_cadastro: 1 = cliente, 2 = fornecedor, 3 = colaborador
-- CPF e CNPJ ficam em colunas separadas (só uma deve ser preenchida).
CREATE TABLE pessoas (
    id_pessoa     INT PRIMARY KEY,
    nome          VARCHAR(120) NOT NULL,
    tipo_cadastro SMALLINT     NOT NULL,
    cpf           CHAR(11),
    cnpj          CHAR(14),
    ativo         BOOLEAN      NOT NULL DEFAULT TRUE
);

-- natureza: 'R' = a receber, 'P' = a pagar
CREATE TABLE tipos_documento (
    id_tipo_documento INT PRIMARY KEY,
    descricao         VARCHAR(60) NOT NULL,
    natureza          CHAR(1)     NOT NULL CHECK (natureza IN ('R','P'))
);

CREATE TABLE centros_custo (
    id_centro_custo INT PRIMARY KEY,
    nome            VARCHAR(60) NOT NULL
);

CREATE TABLE contas_gerenciais (
    id_conta_gerencial INT PRIMARY KEY,
    nome               VARCHAR(60) NOT NULL,
    grupo              VARCHAR(40) NOT NULL
);

CREATE TABLE projetos (
    id_projeto INT PRIMARY KEY,
    nome       VARCHAR(60) NOT NULL
);

-- O título financeiro (uma conta a pagar ou a receber).
-- Valores em CENTAVOS (inteiro), como o ERP guarda.
-- situacao: 1 = aberto, 2 = pago, 3 = cancelado
CREATE TABLE documentos_financeiros (
    id_documento        SERIAL PRIMARY KEY,
    id_tipo_documento   INT         NOT NULL REFERENCES tipos_documento (id_tipo_documento),
    id_pessoa           INT         NOT NULL REFERENCES pessoas (id_pessoa),
    id_conta_receber    INT         REFERENCES contas_receber (id_conta),  -- Ligação com a parcela da venda
    numero_documento    VARCHAR(30) NOT NULL,
    data_emissao        DATE        NOT NULL,
    data_vencimento     DATE        NOT NULL,
    data_pagamento      DATE,
    valor_centavos      BIGINT      NOT NULL,
    valor_pago_centavos BIGINT,
    situacao            SMALLINT    NOT NULL
);

-- Rateio: divide um documento entre centros de custo, contas e projetos.
-- Os percentuais de um mesmo documento devem somar 100.
CREATE TABLE rateios (
    id_rateio          SERIAL PRIMARY KEY,
    id_documento       INT          NOT NULL REFERENCES documentos_financeiros (id_documento),
    id_centro_custo    INT          NOT NULL REFERENCES centros_custo (id_centro_custo),
    id_conta_gerencial INT          NOT NULL REFERENCES contas_gerenciais (id_conta_gerencial),
    id_projeto         INT          REFERENCES projetos (id_projeto),
    percentual         NUMERIC(5,2) NOT NULL
);

-- Índice único para garantir 1 título financeiro por conta a receber (parcela)
CREATE UNIQUE INDEX uq_doc_conta_receber ON documentos_financeiros (id_conta_receber) WHERE id_conta_receber IS NOT NULL;
CREATE INDEX idx_doc_situacao_venc ON documentos_financeiros (situacao, data_vencimento);
CREATE INDEX idx_rateios_doc       ON rateios (id_documento);

-- -----------------------------------------------------
-- Liga o cadastro de clientes (vendas) ao cadastro de pessoas
-- -----------------------------------------------------
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS id_pessoa INT;
UPDATE clientes SET id_pessoa = NULL;
ALTER TABLE clientes DROP CONSTRAINT IF EXISTS fk_clientes_pessoa;
ALTER TABLE clientes ADD CONSTRAINT fk_clientes_pessoa
    FOREIGN KEY (id_pessoa) REFERENCES pessoas (id_pessoa);

-- -----------------------------------------------------
-- View 1: um registro por documento, já "traduzido".
-- Aqui ficam as regras de negócio: códigos viram texto,
-- CPF/CNPJ viram um campo só e centavos viram reais.
-- -----------------------------------------------------
CREATE VIEW vw_titulos AS
SELECT
    d.id_documento,
    d.numero_documento,
    cr.id_pedido,
    d.id_conta_receber,
    td.descricao                                   AS tipo_documento,
    CASE td.natureza WHEN 'R' THEN 'RECEBER'
                     ELSE 'PAGAR' END              AS natureza,
    p.id_pessoa,
    p.nome                                         AS pessoa,
    CASE p.tipo_cadastro WHEN 1 THEN 'Cliente'
                         WHEN 2 THEN 'Fornecedor'
                         WHEN 3 THEN 'Colaborador'
                         ELSE 'Não identificado' END AS tipo_pessoa,
    COALESCE(p.cnpj, p.cpf)                        AS documento_pessoa,
    d.data_emissao,
    d.data_vencimento,
    d.data_pagamento,
    ROUND(d.valor_centavos / 100.0, 2)            AS valor,
    CASE d.situacao WHEN 1 THEN 'ABERTO'
                    WHEN 2 THEN 'PAGO'
                    WHEN 3 THEN 'CANCELADO'
                    ELSE 'DESCONHECIDO' END        AS situacao
FROM documentos_financeiros d
JOIN tipos_documento td ON td.id_tipo_documento = d.id_tipo_documento
JOIN pessoas         p  ON p.id_pessoa           = d.id_pessoa
LEFT JOIN contas_receber cr ON cr.id_conta       = d.id_conta_receber;

-- -----------------------------------------------------
-- View 2: um registro por linha de rateio, com o valor
-- já proporcional ao percentual.
-- -----------------------------------------------------
CREATE VIEW vw_rateio AS
SELECT
    t.id_documento,
    t.numero_documento,
    t.natureza,
    t.situacao,
    t.data_emissao,
    t.data_vencimento,
    cc.nome                                    AS centro_custo,
    cg.nome                                    AS conta_gerencial,
    cg.grupo                                   AS grupo_conta,
    pr.nome                                    AS projeto,
    r.percentual,
    ROUND(t.valor * r.percentual / 100, 2)     AS valor_rateado
FROM vw_titulos t
JOIN rateios           r  ON r.id_documento        = t.id_documento
JOIN centros_custo     cc ON cc.id_centro_custo    = r.id_centro_custo
JOIN contas_gerenciais cg ON cg.id_conta_gerencial = r.id_conta_gerencial
LEFT JOIN projetos     pr ON pr.id_projeto         = r.id_projeto;