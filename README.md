# 📊 ERP Vendas & Financeiro — Modelagem Relacional e Análise SQL
 
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-blue?logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-Supported-blue?logo=docker)
![Status](https://img.shields.io/badge/Status-Em%20Evolu%C3%A7%C3%A3o-blue)
 
Projeto prático desenvolvido para simular um banco de dados relacional completo de um **ERP Integrado (Módulos de Vendas e Financeiro)**, com suporte a **vendas parceladas**, **rateio de centros de custo/contas gerenciais** e **rotinas automatizadas de validação e qualidade de dados (Data Quality)**.
 
> Todos os dados são fictícios e gerados por script. Nada neste repositório vem de uma empresa real.
 
---
 
## 📌 1. Visão Geral do Projeto
 
Em ambientes corporativos reais, os módulos operacionais (Vendas) e financeiros precisam interagir de forma consistente sem duplicação ou contradições de dados.
 
Este projeto recria essa dinâmica modelando:
1. **Cadastro Único de Pessoas (`pessoas`):** Unificação de clientes, fornecedores e colaboradores.
2. **Vendas Operacionais (`pedidos` & `itens_pedido`):** Registro de transações comerciais.
3. **Parcelamento de Vendas (`contas_receber`):** Suporte a vendas à vista e parceladas em até 10 vezes ($1 : N$).
4. **Módulo Financeiro (`documentos_financeiros` & `rateios`):** Origem dos títulos a receber nascidos das parcelas operacionais, além do controle detalhado de contas a pagar e rateios por centro de custo e projetos.
5. **Data Quality & Auditoria:** Scripts focados na detecção proposital e automática de inconsistências de dados (rateios incorretos, títulos pagos sem data de quitação, cadastros ambíguos, etc.).
---
 
### 📊 Análises de Negócio e KPIs
O projeto responde a perguntas estratégicas divididas em dois níveis:
 
1. **Análises Comerciais (`03_perguntas.sql`):**
   * Evolução do faturamento mensal (considerando apenas pedidos entregues).
   * Top 10 produtos mais vendidos e Top 10 clientes que mais geraram faturamento.
   * Alertas de estoque baixo e inatividade de clientes (> 90 dias sem comprar).
   * Ticket médio por pedido, pagamentos em atraso e faturamento por categoria.
   * Comparativo mês a mês (`LAG`) e Top 3 produtos mais vendidos por cidade (`DENSE_RANK`).
2. **Análises Financeiras e Caixa (`06_indicadores_financeiros.sql`):**
   * Contas a receber em aberto (a vencer x vencido), aging por faixa de atraso e taxa de inadimplência por mês de vencimento.
   * Maiores devedores e concentração da dívida.
   * Faturado x recebido por mês, prazo médio de recebimento/pagamento e % pago com atraso.
   * Contas a pagar das próximas semanas e maiores fornecedores.
   * Despesa por centro de custo e por tipo de conta gerencial (via rateio).
   * Fluxo de caixa realizado por mês (com saldo acumulado) e fluxo previsto das próximas 8 semanas.
   * Resultado (receitas − despesas) por projeto.
   * Cruzamentos Vendas x Financeiro: inadimplência por cidade e categorias dos pedidos vencidos em aberto.
---
 
## 📐 2. Modelagem de Dados & Arquitetura
 
### Relacionamentos Principais
* **`clientes` $\rightarrow$ `pessoas`**: cada cliente aponta para uma pessoa do cadastro único (nos dados de exemplo, $1 : 1$).
* **`pedidos` $\rightarrow$ `contas_receber`**: Relação $1 : N$ (um pedido gera de 1 a $N$ parcelas).
* **`contas_receber` $\rightarrow$ `documentos_financeiros`**: Relação $1 : 1$ por parcela (garantida por índice único).
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
 
## 📁 3. Estrutura do Repositório
 
```
.
├── README.md
├── docker-compose.yml
└── sql_scripts
    ├── 01_criar_tabelas.sql
    ├── 02_dados_exemplo.sql
    ├── 03_perguntas.sql
    ├── 04_modelo_financeiro.sql
    ├── 05_dados_financeiros.sql
    ├── 06_indicadores_financeiros.sql
    └── 07_verificacoes_qualidade.sql
```
 
| Arquivo | Descrição |
| :--- | :--- |
| **`01_criar_tabelas.sql`** | Estrutura DDL do módulo de Vendas (Clientes, Produtos, Pedidos, Itens e Contas a Receber com parcelamento). |
| **`02_dados_exemplo.sql`** | Geração de massa de dados fictícios: vendas à vista ou parceladas em 10x, com pagamentos parcela a parcela (em dia, com atraso ou nunca pagos). |
| **`03_perguntas.sql`** | Consultas e indicadores comerciais de vendas (Top produtos, ticket médio, faturamento por categoria, etc.). |
| **`04_modelo_financeiro.sql`** | Estrutura DDL do Financeiro (Pessoas, Documentos, Rateios) e criação das Views Analíticas (`vw_titulos`, `vw_rateio`). |
| **`05_dados_financeiros.sql`** | Carga de títulos a receber (nascidos das parcelas), títulos a pagar (fornecedores/reembolsos) e inserção proposital de defeitos de qualidade. |
| **`06_indicadores_financeiros.sql`** | Consultas analíticas de Aging, Inadimplência, Fluxo de Caixa, despesas por centro de custo e Resultado por Projeto. |
| **`07_verificacoes_qualidade.sql`** | Testes de Data Quality e integridade relacional, com um resumo final de problemas por tipo. |
 
**Volume gerado (aproximado):** 200 clientes, 30 produtos, 1.000 pedidos, cerca de 2.400 itens, cerca de 3.900 parcelas a receber (580 pedidos à vista e 335 em 10x), 700 títulos a pagar e 250 pessoas (clientes, fornecedores e colaboradores).
 
> Os dados usam semente fixa (`setseed`), mas as datas partem de `CURRENT_DATE`. Por isso os resultados de consultas como atraso, aging e fluxo de caixa mudam conforme o dia em que você roda.
 
---
 
## 🚀 4. Como Executar com Docker
 
### Pré-requisitos
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e em execução.
* No Windows, use o Docker Desktop com a integração do **WSL 2** ligada e rode os comandos no terminal do Ubuntu (WSL). Clone o projeto dentro do Linux (por exemplo, `~/projetos`) e não em `/mnt/c/...`, que é bem mais lento.
### Passo a Passo
 
1. **Clone o repositório:**
```bash
   git clone https://github.com/souza-anacarolina/vendas-erp-sql.git
   cd vendas-erp-sql
```
 
2. **Suba o container com o PostgreSQL:**
```bash
   docker compose up -d
```
   > Em instalações antigas o comando é `docker-compose up -d`.
 
   Na **primeira** subida, o PostgreSQL executa sozinho, em ordem alfabética, todos os `.sql` da pasta `sql_scripts/` (de `01` a `07`). Acompanhe até terminar:
```bash
   docker logs -f erp_postgres
```
   A carga acabou quando aparecer `PostgreSQL init process complete; ready for start up.` seguido de `database system is ready to accept connections`. Os resultados das consultas dos arquivos 03, 06 e 07 também aparecem nesse log, e isso é esperado.
 
3. **Acesse o banco de dados via terminal (ou DBeaver/pgAdmin):**
```bash
   docker exec -it erp_postgres psql -U postgres -d erp_db
```
 
   * **Host:** `localhost`
   * **Porta:** `5432`
   * **Usuário:** `postgres`
   * **Senha:** `postgres`
   * **Database:** `erp_db`
   > Credenciais apenas para estudo. Não use em ambiente real.
 
4. **Confira se carregou:**
```sql
   \dt
   SELECT COUNT(*) FROM contas_receber;
   SELECT * FROM vw_titulos LIMIT 5;
```
 
5. **Rode as consultas de análise e de qualidade quando quiser** (a pasta `sql_scripts/` fica montada dentro do container):
```bash
   docker exec -it erp_postgres psql -U postgres -d erp_db -f /docker-entrypoint-initdb.d/06_indicadores_financeiros.sql
   docker exec -it erp_postgres psql -U postgres -d erp_db -f /docker-entrypoint-initdb.d/07_verificacoes_qualidade.sql
```
 
### Comandos úteis
 
| O que fazer | Comando |
| :--- | :--- |
| Parar o container (mantém os dados) | `docker compose stop` |
| Subir de novo | `docker compose start` |
| **Recriar o banco do zero** (apaga o volume e roda os scripts outra vez) | `docker compose down -v && docker compose up -d` |
 
> ⚠️ **Importante:** os scripts da pasta `sql_scripts/` só rodam automaticamente quando o volume `postgres_data` está vazio. Se você editar um `.sql` e subir o container de novo, nada muda. Para aplicar a alteração, recrie o banco com `docker compose down -v`.
 
> 🔌 **Porta 5432 ocupada?** Se você já tem um PostgreSQL instalado na máquina, troque no `docker-compose.yml` para `"5433:5432"` e conecte em `localhost:5433`.
 
### Sem Docker (PostgreSQL instalado na máquina)
 
```bash
createdb vendas_erp
psql -d vendas_erp -f sql_scripts/01_criar_tabelas.sql
psql -d vendas_erp -f sql_scripts/02_dados_exemplo.sql
psql -d vendas_erp -f sql_scripts/04_modelo_financeiro.sql
psql -d vendas_erp -f sql_scripts/05_dados_financeiros.sql
# Consultas (podem ser rodadas quando quiser):
psql -d vendas_erp -f sql_scripts/03_perguntas.sql
psql -d vendas_erp -f sql_scripts/06_indicadores_financeiros.sql
psql -d vendas_erp -f sql_scripts/07_verificacoes_qualidade.sql
```
 
Os scripts 01, 02, 04 e 05 devem rodar nessa ordem. Rodar o `02` outra vez recria os dados de vendas e apaga os títulos financeiros, então rode o `05` depois dele. Rodar o `05` de novo apaga e recria os dados financeiros sem duplicar.
 
---
 
## 🔎 5. Qualidade de Dados (Data Quality)
 
O script `07_verificacoes_qualidade.sql` atua como uma suíte de testes de auditoria de dados. Ele foi construído para identificar problemas como:
 
* Rateios de custo cujos percentuais não somam 100%.
* Títulos marcados como `PAGO` mas com `data_pagamento IS NULL`.
* Pessoas com inconsistências no documento (CPF e CNPJ simultâneos ou ausentes).
* Descasamento entre a soma das parcelas e a soma dos itens de cada pedido.
* Pedidos sem título financeiro, títulos divergentes da conta a receber de origem e clientes sem cadastro de pessoa.
* Títulos pagos com data de pagamento no futuro.
* Mapa de relacionamentos entre as tabelas e tabelas sem nenhuma ligação.
Os defeitos do primeiro grupo (rateio, pago sem data, CPF/CNPJ) são **inseridos de propósito** pelo `05` para que o script de auditoria tenha o que encontrar: 12 rateios, 6 títulos pagos sem data, 3 pessoas sem documento e 2 com CPF e CNPJ. As verificações de ligação entre vendas e financeiro **devem vir vazias**. O resumo final (item 12 do script) mostra a contagem de cada tipo.
 
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
 