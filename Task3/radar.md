# Технологический радар

## Как собрать и посмотреть радар

Радар собирается статическим генератором [AOE Technology Radar](https://github.com/AOEpeople/aoe_technology_radar).

```bash
npm install
npm run build   # статическая сборка в ./build
npm run serve   # http://localhost:3000 — режим разработки
```

## Структура радара

Четыре квадранта и четыре кольца, настроенные в `config.json`:

- **Квадранты:** Языки и Фреймворки · Практики и Паттерны · Платформы · Инструменты
- **Кольца:** `Adopt` — используем по умолчанию · `Trial` — разворачиваем, подтверждаем на
  ограниченном числе доменов · `Assess` — пилотируем · `Hold` — новое не делаем, существующее выводим

`Hold` не означает «выключить завтра». Легаси-хранилище, шина и интерфейс оператора клиники
продолжают обслуживать бизнес, пока соответствующие потоки не перенесены — это поэтапный вывод
(strangler), а не единовременная замена. Именно такое временное сосуществование заложено в цель года.

## Распределение по кольцам

| Кольцо | Комментарий |
|--------|-------------|
| Adopt | Текущий стек, который остаётся, плюс решения, принятые без оговорок: облако, IaC, единый доступ, обезличивание, отказоустойчивость |
| Trial | Целевая платформа данных и доменная модель — разворачиваем, но подтверждаем на 2–3 доменах |
| Assess | Каталог данных, качество данных, MLOps, Nessie, FinOps — пилоты, от которых не зависят сроки года |
| Hold | Легаси: SQL Server 2008, ESB на Camel, PowerBuilder, бизнес-логика в T-SQL |

## Состав радара

### Языки и Фреймворки

| Кольцо | Технология / практика | Файл |
|--------|------------------------|------|
| Adopt | Go | [`golang.md`](radar/2026-09-17/golang.md) |
| Adopt | Java | [`java.md`](radar/2026-09-17/java.md) |
| Adopt | Python | [`python.md`](radar/2026-09-17/python.md) |
| Trial | React / Next.js | [`react-nextjs.md`](radar/2026-09-17/react-nextjs.md) |
| Hold | PowerBuilder | [`powerbuilder.md`](radar/2026-09-17/powerbuilder.md) |
| Hold | Бизнес-логика в T-SQL (хранимые процедуры DWH) | [`tsql-business-logic.md`](radar/2026-09-17/tsql-business-logic.md) |

### Практики и Паттерны

| Кольцо | Технология / практика | Файл |
|--------|------------------------|------|
| Adopt | Data Governance и управление доступом | [`data-governance.md`](radar/2026-09-17/data-governance.md) |
| Adopt | Обезличивание и псевдонимизация медицинских данных | [`de-identification.md`](radar/2026-09-17/de-identification.md) |
| Adopt | Отказоустойчивость, резервное копирование и гео-резервирование | [`disaster-recovery.md`](radar/2026-09-17/disaster-recovery.md) |
| Adopt | Выделение доменов по бизнес-способностям (DDD) | [`domain-driven-design.md`](radar/2026-09-17/domain-driven-design.md) |
| Adopt | Infrastructure as Code | [`iac.md`](radar/2026-09-17/iac.md) |
| Adopt | Strangler Fig — поэтапный вывод легаси | [`strangler-fig.md`](radar/2026-09-17/strangler-fig.md) |
| Trial | Data Contracts | [`data-contracts.md`](radar/2026-09-17/data-contracts.md) |
| Trial | Data Mesh | [`data-mesh.md`](radar/2026-09-17/data-mesh.md) |
| Trial | Data as a Product | [`data-products.md`](radar/2026-09-17/data-products.md) |
| Trial | Событийная интеграция вместо централизованной шины | [`event-driven-integration.md`](radar/2026-09-17/event-driven-integration.md) |
| Trial | Lakehouse | [`lakehouse.md`](radar/2026-09-17/lakehouse.md) |
| Trial | Слои bronze / silver / gold | [`medallion-architecture.md`](radar/2026-09-17/medallion-architecture.md) |
| Trial | Self-service аналитика | [`self-service-analytics.md`](radar/2026-09-17/self-service-analytics.md) |
| Assess | FinOps | [`finops.md`](radar/2026-09-17/finops.md) |
| Assess | MLOps | [`mlops.md`](radar/2026-09-17/mlops.md) |

### Платформы

| Кольцо | Технология / практика | Файл |
|--------|------------------------|------|
| Adopt | Облачная инфраструктура (IaaS) | [`cloud-iaas.md`](radar/2026-09-17/cloud-iaas.md) |
| Adopt | Keycloak | [`keycloak.md`](radar/2026-09-17/keycloak.md) |
| Adopt | Объектное хранилище S3 (MinIO) | [`object-storage-s3.md`](radar/2026-09-17/object-storage-s3.md) |
| Adopt | PostgreSQL | [`postgresql.md`](radar/2026-09-17/postgresql.md) |
| Trial | Apache Iceberg | [`apache-iceberg.md`](radar/2026-09-17/apache-iceberg.md) |
| Trial | Apache Kafka | [`apache-kafka.md`](radar/2026-09-17/apache-kafka.md) |
| Trial | Dremio | [`dremio.md`](radar/2026-09-17/dremio.md) |
| Trial | Kubernetes | [`kubernetes.md`](radar/2026-09-17/kubernetes.md) |
| Assess | Project Nessie | [`nessie.md`](radar/2026-09-17/nessie.md) |
| Hold | ESB на Apache Camel | [`apache-camel-esb.md`](radar/2026-09-17/apache-camel-esb.md) |
| Hold | Microsoft SQL Server 2008 (корпоративное DWH) | [`sql-server.md`](radar/2026-09-17/sql-server.md) |

### Инструменты

| Кольцо | Технология / практика | Файл |
|--------|------------------------|------|
| Adopt | Apache Airflow | [`apache-airflow.md`](radar/2026-09-17/apache-airflow.md) |
| Adopt | Power BI | [`power-bi.md`](radar/2026-09-17/power-bi.md) |
| Adopt | Prometheus + Grafana | [`prometheus-grafana.md`](radar/2026-09-17/prometheus-grafana.md) |
| Adopt | Terraform | [`terraform.md`](radar/2026-09-17/terraform.md) |
| Trial | Debezium (CDC) | [`debezium.md`](radar/2026-09-17/debezium.md) |
| Trial | MLflow | [`mlflow.md`](radar/2026-09-17/mlflow.md) |
| Trial | HashiCorp Vault | [`vault.md`](radar/2026-09-17/vault.md) |
| Assess | Каталог данных (DataHub / OpenMetadata) | [`datahub.md`](radar/2026-09-17/datahub.md) |
| Assess | Great Expectations | [`great-expectations.md`](radar/2026-09-17/great-expectations.md) |

## Как радар связан с бизнес-сценариями

Каждая карточка содержит блок «Поддерживаемые бизнес-сценарии». Обратная связка — от сценария
к технологиям:

| Бизнес-сценарий | Ключевые элементы радара |
|-----------------|--------------------------|
| Быстрая подготовка отчётности | Lakehouse, Apache Iceberg, Dremio, слои bronze/silver/gold, dbt, объектное хранилище S3 |
| Портал самообслуживания (витрина данных) | Self-service аналитика, React/Next.js, Dremio, Keycloak, каталог данных, Power BI |
| Независимое развитие финтех- и ИИ-направлений | Data Mesh, Data as a Product, Data Contracts, Kafka, событийная интеграция, CI/CD, Kubernetes |
| Подключение новых бизнесов (фарма, электроника) | Data Contracts, Data as a Product, Terraform, IaC, облачная IaaS |
| Качество медицинских сервисов | Обезличивание, MLOps, MLflow, PostgreSQL, Data Governance |
| Качество финансовых сервисов | Go, Java, Great Expectations, Data Contracts, Prometheus + Grafana |
| Информационная безопасность и требования регуляторов | Data Governance, обезличивание, Keycloak, Vault, каталог данных |
| Надёжность и доступность | Отказоустойчивость и гео-резервирование, облачная IaaS, Kubernetes, Prometheus + Grafana |
| Снижение затрат | Объектное хранилище S3, FinOps, облачная IaaS, вывод легаси (SQL Server, ESB) |
| Уход от легаси без остановки бизнеса | Strangler Fig, Debezium, Airflow, SQL Server 2008 (hold), ESB на Camel (hold) |
