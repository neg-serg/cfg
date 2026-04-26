# Восстановление хранилища паролей

Полное восстановление gopass, age identity и Vaultwarden из одного
age-зашифрованного backup-архива.

Понадобится пароль восстановления. В рабочей системе он лежит в gopass
по пути `backup/recovery-passphrase`. Если gopass недоступен, пароль нужно
знать наизусть или найти в записях.

Backup-файлы находятся в `~/backups/vault-full-<дата>.age`.

## Что нужно

- установленный `age`
- backup-файл в `~/backups/`
- пароль восстановления

## Расшифровать и распаковать

```bash
mkdir -p /tmp/vault-restore
age -d ~/backups/vault-full-$(date +%F).age | tar xzf - -C /tmp/vault-restore
```

Появятся:
- `/tmp/vault-restore/store/` — git-репозиторий gopass
- `/tmp/vault-restore/identities` — age identity
- `/tmp/vault-restore/vaultwarden.db` — дамп Vaultwarden SQLite

Если сегодняшняя дата неизвестна, посмотрите список доступных backup-файлов:

```bash
ls ~/backups/vault-full-*.age
```

И подставьте нужную дату вручную.

## Восстановить gopass store

```bash
rm -rf ~/.local/share/gopass/store
cp -a /tmp/vault-restore/store ~/.local/share/gopass/
```

## Восстановить age identity

```bash
mkdir -p ~/.config/gopass/age
cp -a /tmp/vault-restore/identities ~/.config/gopass/age/
chmod -R 600 ~/.config/gopass/age
```

## Проверить расшифровку gopass

```bash
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
gopass ls bw/
```

Если `gopass ls` работает, но расшифровка не удаётся — проблема в identity
или пароле. Повторите восстановление identity или используйте break-glass.

## Восстановить Vaultwarden

Остановить контейнер, заменить базу данных, запустить снова:

```bash
sudo systemctl stop vaultwarden.service
sudo cp /tmp/vault-restore/vaultwarden.db /var/lib/vaultwarden/db.sqlite3
sudo systemctl start vaultwarden.service
```

Проверка:

```bash
curl -sf http://127.0.0.1:8222
# Ожидается: 200 OK — веб-интерфейс Vaultwarden доступен
```

## Очистка

```bash
rm -rf /tmp/vault-restore
```

## Восстановление только по паролю (без backup-файла)

Если backup-файла нет, но известен мастер-пароль gopass и пароль от age
identity, можно восстановиться из git-remotes:

```bash
gopass init --store ~/.local/share/gopass/store
gopass git remote add origin <git-url>
gopass sync
```

Затем смените пароли в Vaultwarden через веб-интерфейс.

## Восстановление из git без age identity

Понадобится процедура break-glass с YubiKey — см. `docs/gopass-breakglass-recovery.ru.md`.
