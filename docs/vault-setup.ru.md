# Первоначальная настройка Vaultwarden

Пошаговая процедура настройки Vaultwarden на новой машине.

## 1. Применить Salt state

```bash
just apply vaultwarden
```

Это устанавливает vaultwarden (контейнер Podman Quadlet на localhost:8222), bitwarden-cli, развёртывает systemd user-юниты и таймеры, создаёт `/var/lib/vaultwarden`.

**Примечание:** Salt state развёртывает systemd *user* таймеры (`bw-sync.timer`, `vault-full-backup.timer`). Эти таймеры срабатывают только если у пользователя включён lingering. Выполните один раз:

```bash
sudo loginctl enable-linger "$(whoami)"
```

**Режимы отказа:**
- Порт 8222 уже занят → отредактируйте `states/units/vaultwarden-container.container` строку 20 перед применением, или остановите конфликтующий сервис.
- Отсутствует `just` → выполните `scripts/salt-apply.sh vaultwarden` напрямую.
- Таймеры не срабатывают после перезагрузки → забыли `loginctl enable-linger` (см. выше).

## 2. Первоначальная регистрация пользователя Vaultwarden

Перейдите на `http://localhost:8222` и зарегистрируйте начальную учётную запись администратора.

После этого регистрация новых пользователей блокируется: в контейнере установлено `SIGNUPS_ALLOWED=false` в Quadlet unit (`states/units/vaultwarden-container.container:27`). Только первая регистрация будет успешной.

Убедитесь в админ-панели (http://localhost:8222/admin), что "Allow new signups" снят.

**Режимы отказа:**
- Контейнер не запущен → проверьте `sudo systemctl status vaultwarden.service`. Если неактивен, возможно, нужно запустить Quadlet unit: `sudo systemctl start vaultwarden.service`. При первой установке systemd мог не подхватить новый unit — проверьте, что `sudo systemctl daemon-reload` был выполнен (Salt делает это автоматически).

## 3. Аутентификация bw CLI

Получите API-ключ из `https://vault.bitwarden.com/#/organizations/<org>/api` (или из панели администрирования Vaultwarden http://localhost:8222/admin → API Key).

```bash
bw logout 2>/dev/null || true
bw config server http://localhost:8222
bw login --apikey
```

Введите `BW_CLIENTID` (например `user.xxxx`) и `BW_CLIENTSECRET` когда будет предложено.

Проверьте, что сессия работает:

```bash
bw list items --search test
```

**Режимы отказа:**
- `bw login --apikey` зависает → убедитесь, что `bw config server` установлен правильно. Команда `bw config server` сохраняет URL сервера в `~/.config/Bitwarden CLI/settings.json`. Если видите ошибку несоответствия сервера, выполните `bw config server http://localhost:8222` заново.
- Запрос API-ключа не работает → передайте через окружение: `BW_CLIENTID=user.xxxx BW_CLIENTSECRET=yyyy bw login --apikey`.

## 4. Проверка таймера синхронизации

Таймер `bw-sync.timer` срабатывает каждый час. Для ручной проверки:

```bash
systemctl --user start bw-sync.service && journalctl --user -u bw-sync.service -n 20 --no-pager
```

Скрипт `bw-sync.py` требует разблокированной сессии Bitwarden. Oneshot-сервис (`~/.config/systemd/user/bw-sync.service`) по умолчанию **не** устанавливает `BW_SESSION` или `BW_PASSWORD` — он вызывает `bw unlock --raw`, который запросит ввод с stdin и завершится ошибкой в контексте systemd.

Чтобы таймер работал, установите ключ сессии:

```bash
export BW_SESSION="$(bw unlock --raw)"   # запросит мастер-пароль один раз
systemctl --user set-environment BW_SESSION="$BW_SESSION"
```

В качестве альтернативы установите `BW_PASSWORD` через systemd drop-in:

```bash
systemctl --user edit bw-sync.service
# Добавьте:
# [Service]
# Environment=BW_PASSWORD=<ваш-мастер-пароль>
```

Проверьте, что элементы появляются в gopass:

```bash
gopass ls bw/
```

**Режимы отказа:**
- `bw unlock --raw` не работает → убедитесь, что `bw login --apikey` выполнен успешно (шаг 3). Сессия могла истечь — повторно аутентифицируйтесь с `bw login --apikey` или `bw unlock --raw`.
- Нет элементов в gopass → скрипт синхронизации импортирует только те элементы, которых ещё нет в gopass. Если хранилище bw пусто, сначала добавьте элемент. Проверьте логи синхронизации: `journalctl --user -u bw-sync.service --no-pager`.

## 5. Настройка пароля восстановления

```bash
gopass generate backup/recovery-passphrase 32
```

Это генерирует 32-символьный пароль, сохранённый в gopass. Скрипт `vault-full-backup.sh` читает его через `gopass show -o backup/recovery-passphrase` для шифрования backup-архива с помощью `age -p`.

> **ПРЕДУПРЕЖДЕНИЕ:** Запишите этот пароль на бумаге или сохраните в отдельном физическом месте. Backup-архив содержит хранилище gopass и age identity — если вы потеряете и gopass, и пароль, backup будет навсегда нерасшифровываем. Пароль является единственной точкой отказа для аварийного восстановления.

**Режим отказа:** Скрипт backup завершается ошибкой, если пароль отсутствует. Проверьте: `gopass show -o backup/recovery-passphrase`.

## 6. Тестирование backup

```bash
systemctl --user start vault-full-backup.service && journalctl --user -u vault-full-backup.service -n 20 --no-pager
ls -la ~/backups/
```

Ожидается файл вида `~/backups/vault-full-<ДАТА>.age` (~/backups/ по умолчанию; можно переопределить переменной окружения `BACKUP_DIR`).

Tarball содержит:
- хранилище gopass (`~/.local/share/gopass/store/`)
- age identity gopass (`~/.config/gopass/age/identities/`)
- дамп SQLite Vaultwarden (если `/var/lib/vaultwarden/db.sqlite3` существует)

Команда восстановления (для справки — не часть настройки):

```bash
age -d ~/backups/vault-full-<ДАТА>.age | tar xzf -
```

**Режимы отказа:**
- Отсутствует `/var/lib/vaultwarden/db.sqlite3` → скрипт backup обрабатывает это корректно (пропускает дамп SQLite, пишет предупреждение в journal).
- `gopass` не инициализирован → сначала `gopass setup`. Backup завершится ошибкой «gopass store not found».
- `age` не установлен → `sudo pacman -S age` или позвольте Salt state установить. Скрипту backup требуется `age` для шифрования.
