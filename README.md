# 📊 ERP Vendas & Financeiro — Modelagem Relacional e Análise SQL

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-blue?logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-Supported-blue?logo=docker)
![Status](https://img.shields.io/badge/Status-Em%20Evolu%C3%A7%C3%A3o-blue)

Projeto prático desenvolvido para simular um banco de dados relacional completo de um **ERP Integrado (Módulos de Vendas e Financeiro)**, com suporte a **vendas parceladas**, **rateio de centros de custo/contas gerenciais** e **rotinas automatizadas de validação e qualidade de dados (Data Quality)**.

---

## 📌 1. Visão Geral do Projeto

Em ambientes corporativos reais, os módulos operacionais (Vendas) e financeiros precisam interagir de forma consistente sem duplicação ou contradições de dados. 

Este projeto recria essa dinâmica modelando:
1. **Cadastro Único de Pessoas (`pessoas`):** Unificação de clientes, fornecedores e colaboradores.
2. **Vendas Operacionais (`pedidos` & `itens_pedido`):** Registro de transações comerciais.
3. **Parcelamento de Vendas (`contas_receber`):** Suporte a vendas à vista e parceladas em até 10 vezes ($1 : N$).
4. **Módulo Financeiro (`documentos_financeiros` & `rateios`):** Origem dos títulos a receber nascidos das parcelas operacionais, além do controle detalhado de contas a pagar e rateios por centro de custo e projetos.
5. **Data Quality & Auditoria:** Scripts focados na detecção proposital e automática de inconsistências de dados ( rateios incorretos, títulos pagos sem data de quitação, cadastros ambíguos, etc.).

---

### 📊 Análises de Negócio e KPIs
O projeto responde a perguntas estratégicas divididas em dois níveis:

1. **Análises Comerciais (`03_perguntas.sql`):**
   * Evolução do faturamento mensal (considerando apenas pedidos entregues).
   * Curva ABC / Top 10 produtos e clientes de maior valor.
   * Alertas de estoque baixo e inatividade de clientes (> 90 dias sem comprar).
   * Ticket médio por pedido e ranking de produtos mais vendidos por cidade (Window Functions).

2. **Análises Financeiras e Caixa (`06_indicadores_financeiros.sql`):**
   * Aging de contas a receber parceladas e taxa de inadimplência por mês de vencimento.
   * Fluxo de caixa realizado vs. previsto (entradas e saídas por semana/mês).
   * DRE gerencial por centro de custo e projetos.

---

## 📐 2. Modelagem de Dados & Arquitetura

### Relacionamentos Principais
* **`clientes` $\rightarrow$ `pessoas`**: Relação $1 : 1$.
* **`pedidos` $\rightarrow$ `contas_receber`**: Relação $1 : N$ (um pedido gera de 1 a $N$ parcelas).
* **`contas_receber` $\rightarrow$ `documentos_financeiros`**: Relação $1 : 1$ por parcela.
* **`documentos_financeiros` $\rightarrow$ `rateios`**: Relação $1 : N$ (um título é dividido entre centros de custo/contas gerenciais).

### Diagrama Simplificado do Fluxo
```
[clientes] ──> [pessoas] 
     │
     └──> [pedidos] ──> [itens_pedido]
              │
              └──> [contas_receber] (1:N Parcelas)
                        │
                        └──> [documentos_financeiros] ──> [rateios]
```

---

## 📁 3. Estrutura dos Scripts SQL

| Arquivo | Descrição |
| :--- | :--- |
| **`01_criar_tabelas.sql`** | Estrutura DDL do módulo de Vendas (Clientes, Produtos, Pedidos, Itens e Contas a Receber com parcelamento). |
| **`02_dados_exemplo.sql`** | Geração de massa de dados fictícios para vendas e parcelas à vista/parceladas em até 10x. |
| **`03_perguntas.sql`** | Consultas e indicadores comerciais de vendas (Top produtos, ticket médio, faturamento por cidade, etc.). |
| **`04_modelo_financeiro.sql`** | Estrutura DDL do Financeiro (Pessoas, Documentos, Rateios) e criação das Views Analíticas (`vw_titulos`, `vw_rateio`). |
| **`05_dados_financeiros.sql`** | Carga de títulos a receber (nascidos das parcelas), títulos a pagar (fornecedores/reembolsos) e inserção proposital de defeitos de qualidade. |
| **`06_indicadores_financeiros.sql`** | Consultas analíticas para DRE, Aging de Dívidas, Inadimplência, Fluxo de Caixa e Resultado por Projeto. |
| **`07_verificacoes_qualidade.sql`** | Testes automatizados de Data Quality e integridade relacional. |

---

## 🚀 4. Como Executar com Docker

### Pré-requisitos
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado.

### Passo a Passo

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/souza-anacarolina/vendas-erp-sql.git
   cd vendas-erp-sql
   ```

2. **Suba o container com o PostgreSQL:**
   ```bash
   docker-compose up -d
   ```

3. **Acesse o banco de dados via terminal (ou DBeaver/PgAdmin):**
   ```bash
   docker exec -it erp_postgres psql -U postgres -d erp_db
   ```

   * **Host:** `localhost`
   * **Porta:** `5432`
   * **Usuário:** `postgres`
   * **Senha:** `postgres`
   * **Database:** `erp_db`

---

## 🔎 5. Qualidade de Dados (Data Quality)

O script `07_verificacoes_qualidade.sql` atua como uma suíte de testes de auditoria de dados. Ele foi construído para identificar problemas como:

* Rateios de custo cujos percentuais não somam 100%.
* Títulos marcados como `PAGO` mas com `data_pagamento IS NULL`.
* Pessoas com inconsistências no documento (CPF e CNPJ simultâneos ou ausentes).
* Descasamento de valores entre o total dos itens de venda e a soma das parcelas geradas.

---

## 📈 6. Próximos Passos (Roadmap de Engenharia de Dados)

Como evolução deste projeto para o portfólio de Engenharia de Dados, as próximas etapas serão:

- [ ] **Pipeline ETL em Python (`pandas` / `SQLAlchemy`):** Automação do fluxo de extração e transformação fora da camada de banco de dados.
- [ ] **Construção de um Data Warehouse (Star Schema):** Modelagem dimensional (`fato_vendas`, `fato_financeiro`, `dim_cliente`, `dim_tempo`).
- [ ] **Orquestração de Dados:** Configuração de DAGs simples para carga diária simulada via **Apache Airflow**.
- [ ] **Dashboard de Business Intelligence:** Conexão do modelo analítico ao **Power BI / Looker Studio** para exibição de indicadores operacionais e financeiros.

---

## 👩‍💻 Autora

**Ana Carolina de Souza**  
*Analista de Suporte em transição para a área de Engenharia de Dados.*  
[LinkedIn](https://linkedin.com/in/souza-anacarolina/) | [GitHub](https://github.com/souza-anacarolina)