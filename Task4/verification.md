# Проверка конфигурации

## Что проверено автоматически

Прогон выполнен на Terraform v1.16.2 с провайдером `yandex-cloud/yandex v0.228.0`,
установленным командой `terraform init` из официального реестра.

### `terraform init`

```
Initializing the backend...
Initializing provider plugins...
- Finding yandex-cloud/yandex versions matching "~> 0.140"...
- Installing yandex-cloud/yandex v0.228.0...
- Installed yandex-cloud/yandex v0.228.0 (self-signed, key ID E40F590B50BB8E40)

Terraform has been successfully initialized!
```

### `terraform fmt -check -recursive`

```
(вывод пуст, код возврата 0 — форматирование соответствует стандарту)
```

### `terraform validate`

```
Success! The configuration is valid.
```

Валидация выполняется против реальной схемы провайдера: проверены имена ресурсов, состав
и типы атрибутов, вложенные блоки и ссылки между ресурсами.

### `terraform test` — plan и apply на мок-провайдере

`mock_provider "yandex"` подменяет провайдер: Terraform строит граф, выполняет настоящие
`plan` и `apply`, но не обращается в облако и не создаёт ресурсов. Это позволяет гонять
проверки в CI на каждом merge request без облачных учётных данных и без затрат.

```
tests\platform.tftest.hcl... in progress
  run "network_and_nat"... pass
  run "single_public_node"... pass
  run "data_disks"... pass
  run "apply_platform"... pass
  run "reject_open_ssh_to_internet"... pass
  run "reject_second_public_node"... pass
  run "reject_invalid_ssh_key"... pass
tests\platform.tftest.hcl... tearing down
tests\platform.tftest.hcl... pass

Success! 7 passed, 0 failed.
```

Что именно проверяют тесты:

| Проверка | Что подтверждает |
|----------|------------------|
| `network_and_nat` | Подсеть создаётся на каждую зону из `subnets`; в таблице маршрутов ровно один маршрут `0.0.0.0/0` на NAT-шлюз |
| `single_public_node` | Публичный адрес (`nat = true`) ровно у одного узла, и это бастион; у `dremio` публичного адреса нет |
| `data_disks` | Диск данных создаётся только для узлов с `data_disk_size_gb > 0`, размер совпадает с заявленным, метки проставлены |
| `apply_platform` | Полный `apply` проходит: создаются все ВМ и роли, имена собираются из префикса, подсети привязаны к таблице маршрутов, выводы заполнены |
| `reject_open_ssh_to_internet` | Валидация не пропускает `0.0.0.0/0` в `admin_cidr_blocks` |
| `reject_second_public_node` | Валидация не пропускает второй узел с публичным адресом |
| `reject_invalid_ssh_key` | Валидация не пропускает строку, не являющуюся SSH-ключом |

Последние три — отрицательные тесты: они проходят именно тогда, когда конфигурация
**отклоняется**. Это защита от типовых ошибок, которые иначе всплыли бы уже в облаке.

### `terraform plan` против реального провайдера

Выполнен и остановился ровно там, где и должен без учётных данных:

```
Changes to Outputs:
  + node_summary = {
      + airflow  = "airflow | ru-central1-b | 4 vCPU (100%) | 16 GB RAM | boot 40 GB network-ssd | data 100 GB network-ssd"
      + bastion  = "bastion | ru-central1-a | 2 vCPU (20%) | 2 GB RAM | boot 20 GB network-ssd | data —"
      + dremio   = "dremio | ru-central1-a | 8 vCPU (100%) | 32 GB RAM | boot 40 GB network-ssd | data 200 GB network-ssd"
      + keycloak = "keycloak | ru-central1-b | 2 vCPU (50%) | 4 GB RAM | boot 30 GB network-ssd | data 20 GB network-hdd"
      + portal   = "portal | ru-central1-a | 4 vCPU (100%) | 8 GB RAM | boot 30 GB network-ssd | data —"
    }

Error: Failed to configure
  with provider["registry.terraform.io/yandex-cloud/yandex"],
  on main.tf line 40, in provider "yandex":
  40: provider "yandex" {

one of 'token' or 'service_account_key_file' should be specified
```

Terraform успел вычислить значения, не зависящие от облака (состав узлов из `terraform.tfvars`),
и остановился на настройке провайдера — учётных данных нет.

---

## Что нужно выполнить с реальными учётными данными

Реальный `terraform apply` создаёт платные ресурсы в вашем каталоге Yandex Cloud, поэтому
выполняется вами.

### 1. Подставить свои значения

В [`terraform.tfvars`](terraform.tfvars) заменить заполнители:

- `cloud_id` и `folder_id` — идентификаторы вашего облака и каталога;
- `ssh_public_key` — содержимое вашего `~/.ssh/id_ed25519.pub`;
- `lakehouse_bucket_name` — имя бакета должно быть глобально уникальным, добавьте свой суффикс;
- `admin_cidr_blocks` — сети, из которых вы будете подключаться.

### 2. Авторизоваться

```bash
export YC_TOKEN="$(yc iam create-token)"
```

### 3. Запустить

```bash
terraform init
```

```bash
terraform plan -out=plan.tfplan
```

```bash
terraform apply plan.tfplan
```

### 4. Приложить скриншот

Скриншот вывода `terraform apply` — со строкой вида
`Apply complete! Resources: 24 added, 0 changed, 0 destroyed.` и блоком `Outputs:` —
положить в этот каталог под именем `apply-screenshot.png` и сослаться на него здесь.

> **Место под скриншот:**
> `![Результат terraform apply](apply-screenshot.png)`

### 5. Убрать за собой

Среда `dev` не нужна постоянно — после снятия скриншота ресурсы стоит удалить,
чтобы не платить за простой:

```bash
terraform destroy
```

---

## Ожидаемый состав изменений

При успешном `apply` с текущим `terraform.tfvars` создаётся **24 ресурса**:

| Ресурс | Кол-во |
|--------|--------|
| `yandex_vpc_network` | 1 |
| `yandex_vpc_gateway` | 1 |
| `yandex_vpc_route_table` | 1 |
| `yandex_vpc_subnet` | 2 |
| `yandex_vpc_security_group` | 2 |
| `yandex_iam_service_account` | 1 |
| `yandex_resourcemanager_folder_iam_member` | 4 |
| `yandex_iam_service_account_static_access_key` | 1 |
| `yandex_storage_bucket` | 1 |
| `yandex_compute_disk` | 3 |
| `yandex_compute_instance` | 5 |
| `yandex_lb_target_group` | 1 |
| `yandex_lb_network_load_balancer` | 1 |
| **Итого** | **24** |

> Число выведено из карт `nodes` (5 узлов, из них 3 с диском данных), `subnets` (2 зоны)
> и `service_account_roles` (4 роли). При изменении этих карт состав меняется — точное
> значение всегда показывает `plan` до применения.
