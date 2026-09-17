# Проверка задания 4

Проверка выполнена 17.09.2026 в Windows PowerShell. Terraform **1.13.5**, провайдер **yandex-cloud/yandex 0.161.0**.

## Фактические результаты

| Команда | Результат | Доказательство |
|---|---|---|
| terraform init -input=false -no-color | Успешно; провайдер установлен, lock-файл создан | [init.txt](evidence/init.txt) |
| terraform fmt -check -recursive -no-color | Exit code 0 | [fmt.txt](evidence/fmt.txt) |
| terraform validate -no-color | Конфигурация корректна, exit code 0 | [validate.txt](evidence/validate.txt) |
| terraform test -no-color | 7 passed, 0 failed | [test.txt](evidence/test.txt) |
| terraform plan -input=false -no-color | Exit code 1; отсутствуют cloud_id, folder_id, admin_cidr, ssh_public_key | [plan.txt](evidence/plan.txt) |
| terraform apply -input=false -no-color | Exit code 1 по тем же отсутствующим параметрам; создание ресурсов не начиналось | [apply.txt](evidence/apply.txt) |

Terraform загружен с официального сервера HashiCorp; SHA256 архива сверена с опубликованным файлом контрольных сумм. Проверка провайдера выполнялась Terraform при init. Локальная авторизация YC CLI и переменные авторизации Yandex Cloud в доступной среде не обнаружены.

## Что проверяют тесты

- Согласованные ссылки между VM, сетью, подсетью, security group и диском; единая зона размещения.
- Единственное входящее разрешение: SSH с заданного /32.
- Cloud-init включает авторизацию публичным ключом и отключает парольный/root SSH.
- Отклоняются открытый SSH для всего интернета, некорректный адрес подсети, приватный ключ вместо публичного, имя root и недостаточная память.
- При заданном image_id не используется изменяемое семейство образов.

Тесты используют `mock_provider`, включая один mock apply, поэтому не проверяют квоты, облачные разрешения, доступность образа/зоны и успешность cloud-init внутри настоящей VM. Это не доказательство развёртывания IaaS.

## Что осталось для завершения пункта 3

1. Настроить локальную авторизацию Yandex Cloud, указать настоящий cloud_id/folder_id, admin_cidr и публичный SSH-ключ.
2. Согласовать стоимость, выполнить успешный plan с сохранением файла, проверить пять создаваемых ресурсов.
3. Выполнить apply этого плана, проверить состояние ВМ, cloud-init и SSH, затем повторный plan без изменений.
4. Приложить настоящий скриншот `evidence/apply-success.png`, обновить этот отчёт фактическими результатами и добавить файлы задания в PR.

**Скриншот успешного apply отсутствует, потому что успешного apply не было.** Диаграмма и mock-тесты не подменяют такое доказательство.
