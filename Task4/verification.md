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
      + airflow = "airflow | ru-central1-b | 2 vCPU (20%) | 4 GB RAM | boot 20 GB network-hdd | data —"
      + bastion = "bastion | ru-central1-a | 2 vCPU (20%) | 2 GB RAM | boot 20 GB network-hdd | data —"
      + dremio  = "dremio | ru-central1-a | 2 vCPU (100%) | 8 GB RAM | boot 20 GB network-hdd | data 20 GB network-ssd"
      + portal  = "portal | ru-central1-a | 2 vCPU (20%) | 4 GB RAM | boot 20 GB network-hdd | data —"
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
выполняется вами. Шаги — в [`README.md`](README.md), раздел «Как запустить».

После успешного `apply` приложите к пул-реквесту скриншот вывода: строка вида
`Apply complete! Resources: 20 added, 0 changed, 0 destroyed.` и блок `Outputs:`.
Файл положите рядом под именем `apply-screenshot.png` и сошлитесь на него здесь:

> `![Результат terraform apply](apply-screenshot.png)`

---

## Ожидаемый состав изменений

При успешном `apply` с текущим `terraform.tfvars` создаётся **20 ресурсов**:

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
| `yandex_compute_disk` | 1 |
| `yandex_compute_instance` | 4 |
| `yandex_lb_target_group` | 1 |
| `yandex_lb_network_load_balancer` | 1 |
| **Итого** | **20** |

Суммарная потребность: 8 vCPU, 18 ГБ RAM, 80 ГБ network-hdd, 20 ГБ network-ssd.
