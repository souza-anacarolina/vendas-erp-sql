-- =====================================================
-- Projeto: vendas-erp-sql
-- Arquivo 1: cria as tabelas de uma loja fictícia
-- Banco: PostgreSQL
-- Atenção: este arquivo APAGA e recria as tabelas.
-- =====================================================

DROP TABLE IF EXISTS contas_receber CASCADE;
DROP TABLE IF EXISTS itens_pedido   CASCADE;
DROP TABLE IF EXISTS pedidos        CASCADE;
DROP TABLE IF EXISTS produtos       CASCADE;
DROP TABLE IF EXISTS clientes       CASCADE;


CREATE TABLE clientes (
    id_cliente    SERIAL PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    cidade        VARCHAR(60)  NOT NULL,
    estado        CHAR(2)      NOT NULL,
    data_cadastro DATE         NOT NULL
);


CREATE TABLE produtos (
    id_produto SERIAL PRIMARY KEY,
    nome       VARCHAR(100)  NOT NULL,
    categoria  VARCHAR(50)   NOT NULL,
    preco      NUMERIC(10,2) NOT NULL,
    estoque    INT           NOT NULL
);


CREATE TABLE pedidos (
    id_pedido   SERIAL PRIMARY KEY,
    id_cliente  INT         NOT NULL REFERENCES clientes (id_cliente),
    data_pedido DATE        NOT NULL,
    status      VARCHAR(20) NOT NULL   
);


CREATE TABLE itens_pedido (
    id_item        SERIAL PRIMARY KEY,
    id_pedido      INT           NOT NULL REFERENCES pedidos (id_pedido),
    id_produto     INT           NOT NULL REFERENCES produtos (id_produto),
    quantidade     INT           NOT NULL,
    preco_unitario NUMERIC(10,2) NOT NULL   
);


CREATE TABLE contas_receber (
    id_conta        SERIAL PRIMARY KEY,
    id_pedido       INT           NOT NULL REFERENCES pedidos (id_pedido),
    parcela         INT           NOT NULL DEFAULT 1,
    total_parcelas  INT           NOT NULL DEFAULT 1,
    valor           NUMERIC(12,2) NOT NULL,
    data_vencimento DATE          NOT NULL,
    data_pagamento  DATE                   
);