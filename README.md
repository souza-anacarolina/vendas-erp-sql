# Vendas ERP: perguntas de negócio respondidas com SQL

Projeto de estudo que simula o banco de dados de uma loja, no estilo de um sistema ERP, e responde com SQL 10 perguntas que um gerente faria no dia a dia.

> Todos os dados são fictícios e gerados por script. Nada neste repositório vem de uma empresa real.

## O que o projeto mostra

- Modelagem de um banco relacional simples, com 5 tabelas
- Geração de dados de exemplo usando só SQL
- Consultas com `JOIN`, `GROUP BY`, subconsultas, CTE e funções de janela (`LAG`, `DENSE_RANK`)
- Cuidado com a regra de negócio: pedidos cancelados não entram no faturamento

## Tecnologias

- PostgreSQL
- SQL

## Estrutura do repositório

```
.
├── 01_criar_tabelas.sql   # cria as tabelas
├── 02_dados_exemplo.sql   # gera os dados fictícios
├── 03_perguntas.sql       # as 10 consultas
└── README.md
```

## Modelo de dados

| Tabela | O que guarda |
|---|---|
| `clientes` | Quem compra: nome, cidade, estado e data de cadastro |
| `produtos` | O que a loja vende: nome, categoria, preço e estoque |
| `pedidos` | Cada compra feita por um cliente, com data e status (ENTREGUE ou CANCELADO) |
| `itens_pedido` | Os produtos dentro de cada pedido, com quantidade e preço cobrado |
| `contas_receber` | O que o cliente deve pagar por pedido, com vencimento e data de pagamento |

Relações: um cliente tem vários pedidos, um pedido tem vários itens e cada pedido não cancelado gera uma conta a receber.

## Como rodar

1. Instale o PostgreSQL.
2. Crie um banco vazio:

```bash
createdb vendas_erp
```

3. Execute os arquivos na ordem:

```bash
psql -d vendas_erp -f 01_criar_tabelas.sql
psql -d vendas_erp -f 02_dados_exemplo.sql
psql -d vendas_erp -f 03_perguntas.sql
```

Também funciona no DBeaver ou no pgAdmin: abra cada arquivo e execute como script.

Ao final do `02_dados_exemplo.sql`, o script mostra quantas linhas ficaram em cada tabela: 200 clientes, 30 produtos, 1.000 pedidos, cerca de 2.400 itens e 915 contas a receber.

Rodar o `02_dados_exemplo.sql` de novo apaga e recria os dados, sem duplicar.

## Regra de negócio

O faturamento considera apenas pedidos com status `ENTREGUE`. Pedidos cancelados ficam de fora de todas as consultas de vendas.

## As 10 perguntas

| # | Pergunta | Técnica |
|---|---|---|
| 1 | Quanto a loja vendeu em cada mês? | `GROUP BY` com `to_char` |
| 2 | Quais são os 10 produtos mais vendidos? | `JOIN` + `ORDER BY` + `LIMIT` |
| 3 | Quais são os 10 clientes que mais geraram faturamento? | `COUNT(DISTINCT)` + `SUM` |
| 4 | Quais produtos estão com estoque baixo? | `WHERE` |
| 5 | Quais clientes não compram há mais de 90 dias? | `LEFT JOIN` + `HAVING` |
| 6 | Qual o valor médio de cada pedido (ticket médio)? | Subconsulta |
| 7 | Quais pagamentos estão atrasados e há quantos dias? | `JOIN` + cálculo de datas |
| 8 | Quais categorias dão mais faturamento? | `JOIN` + `GROUP BY` |
| 9 | As vendas deste mês subiram ou caíram em relação ao mês passado? | CTE + `LAG` |
| 10 | Quais são os 3 produtos que mais vendem em cada cidade? | CTE + `DENSE_RANK` |

## Exemplos de resultado

**Pergunta 2: produtos mais vendidos (3 primeiros)**

| Produto | Quantidade vendida |
|---|---|
| Fone de Ouvido Bluetooth | 521 |
| Carregador Portátil 10000mAh | 372 |
| Mouse Sem Fio | 316 |

**Pergunta 4: estoque baixo**

| Produto | Quantidade em estoque |
|---|---|
| Halteres 2kg (par) | 4 |
| Webcam Full HD | 5 |
| Mochila Escolar | 6 |
| Carregador Portátil 10000mAh | 8 |
| Liquidificador | 9 |

**Pergunta 6: ticket médio**

| Ticket médio |
|---|
| R$ 635,45 |

**Pergunta 8: faturamento por categoria**

| Categoria | Faturamento |
|---|---|
| Eletrônicos | R$ 350.956,90 |
| Casa | R$ 113.134,80 |
| Esporte | R$ 79.263,20 |
| Papelaria | R$ 38.080,70 |


## Prints dos resultados

**Pergunta 3: clientes que mais geraram faturamento**

<img width="685" height="300" alt="image" src="https://github.com/user-attachments/assets/ebcde6a7-c312-47a2-9861-32368ca13dd9" />


**Pergunta 7: pagamentos atrasados**

<img width="667" height="315" alt="image" src="https://github.com/user-attachments/assets/b51faeb0-d145-496c-af7b-0e644f10287a" />

## Decisões de modelagem e cuidados com os dados

- **Regra de faturamento única:** só pedidos `ENTREGUE` entram nas consultas de venda. Aplicar a mesma regra em todas evita que totais de consultas diferentes deixem de bater.
- **Contagem de pedidos com `COUNT(DISTINCT)`:** o pedido aparece uma vez por item, então a contagem simples infla o resultado (um cliente com 9 pedidos aparecia com 26).
- **Agrupamento por `id`, não por nome:** nomes se repetem entre clientes diferentes e juntariam pessoas distintas numa linha só.
- **`LEFT JOIN` na análise de inatividade:** com `INNER JOIN`, os clientes que nunca compraram desapareceriam do resultado.
- **Preço no item do pedido:** `itens_pedido` guarda o preço cobrado no dia, então mudar o preço do produto depois não altera o histórico de vendas.

## Próximos passos

- [ ] Painel no Grafana conectado a este banco (vendas, estoque e atrasos)
- [ ] Carga automática dos dados com Python
- [ ] Versão em Docker, para rodar tudo com um comando

## Autora

Ana Carolina, analista de suporte ERP em transição para a área de dados.
[LinkedIn](https://www.linkedin.com/in/souza-anacarolina/) · [GitHub](https://github.com/souza-anacarolina)
