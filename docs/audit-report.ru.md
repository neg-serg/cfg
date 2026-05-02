# Отчёт аудита Salt-инфраструктуры

## История версий

| Версия | Дата | Область |
|--------|------|---------|
| v1.0 | 2026-03-07 | Качество кода: идемпотентность, зависимости, сетевая устойчивость, безопасность, стиль |
| v2.0 | 2026-03-07 | Воспроизводимость: полный walkthrough развёртывания, секреты, feature flags, URL, границы |

---

## Краткое резюме

| Серьёзность | Кол-во | Описание |
|-------------|--------|----------|
| Критическая | 0 | Нет блокирующих проблем |
| Высокая | 5 | Деградация развёртывания или runtime-сбои |
| Средняя | 10 | Субоптимальная устойчивость, косметика, неявные зависимости |
| Низкая | 7 | Пробелы в документации, мёртвый код, дублирование |

**Общая оценка: В ОСНОВНОМ ВОСПРОИЗВОДИМО.** Свежая установка CachyOS по документированным
шагам даст работающую рабочую станцию, но с несколькими пробелами, требующими ручного
вмешательства или предварительных знаний. Слой Salt-состояний надёжен — отличная идемпотентность
(100% покрытие guards), корректные цепочки зависимостей и комплексное применение макросов.
Основные пробелы на **границах**: пересечение Salt/chezmoi, зависимость от gopass для `.tmpl`
файлов chezmoi, документирование ручных шагов после развёртывания и незафиксированные внешние URL.

**Уровень уверенности**: разработчик, знакомый с системой, развернёт успешно.
Новый разработчик, следуя только документации, столкнётся с 3-5 блокерами.

---

## Walkthrough развёртывания

Трассировка свежего развёртывания по задокументированному потоку (`docs/deploy-cachyos.md`):

### Шаг 1: Bootstrap (`scripts/bootstrap-cachyos.sh`)

| Действие | Ожидание | Результат | Пробел |
|----------|----------|-----------|--------|
| Запуск bootstrap от root | rootfs в `/mnt/one/cachyos-root/` | Работает | Нет |
| Наличие podman | Требуется скриптом | Валидация есть | **Документация не упоминает prerequisite podman** |
| Копирование Salt-репо | В `/mnt/one/salt/` | Работает | Нет |
| Сборка кастомных пакетов | iosevka-neg-fonts, raise и т.д. | Работает, но `gem install ansi` падает молча | **F01: ruby отсутствует в PACMAN_PKGS** |

### Шаг 2: Deploy (`scripts/deploy-cachyos.sh /dev/nvme0n1`)

| Действие | Ожидание | Результат | Пробел |
|----------|----------|-----------|--------|
| Разметка NVMe | GPT + LVM + btrfs | Работает | **В документации нет предупреждения об уничтожении данных** |
| Установка Limine | Bootloader настроен | Работает | Нет |
| Генерация fstab | Корректные точки монтирования | Работает | Нет |
| Запись POST-BOOT.md | Инструкции после загрузки в /root/ | Работает | POST-BOOT.md подробнее deploy-cachyos.md |

### Шаг 3: Первая загрузка

| Действие | Ожидание | Результат | Пробел |
|----------|----------|-----------|--------|
| Активация VG | `vgchange -ay xenon argon` | Работает | Нет |
| Монтирование XFS | `/mnt/one`, `/mnt/zero` | Работает | Нет |
| hostname = "cachyos" | Алиас на telfir-конфиг | Работает | **Вторая машина получит конфиг telfir (4K/fancontrol)** |

### Шаг 4: gopass + Salt Apply

| Действие | Ожидание | Результат | Пробел |
|----------|----------|-----------|--------|
| `gopass clone <store-url>` | Секреты доступны | **Placeholder URL в документации** | **F06: нет URL хранилища и GPG key ID** |
| `scripts/salt-apply.sh` | Все состояния проходят | Работает | Нет |
| Salt: mpdas_config | Настройка Last.fm scrobbler | **Падает без gopass** | **F02: raw gopass без fallback** |
| chezmoi apply | Dotfiles развёрнуты | **Падает без gopass** | **F03: 7 .tmpl файлов требуют gopass** |
| floorp config (не-telfir) | Профиль браузера настроен | **Файлы в неправильной директории** | **F04: пустой floorp_profile** |

### Шаг 5: Перезагрузка и проверка

| Действие | Ожидание | Результат | Пробел |
|----------|----------|-----------|--------|
| Запуск greetd | Экран входа | Работает (cage + regreet, agreety fallback) | Нет |
| Сервисы запущены | Все включённые сервисы работают | Работает | Нет |
| DNS настроен | Unbound + опционально AdGuardHome | Работает | **В документации нет упоминания, что DNS изменится** |

---

## Находки по серьёзности

### ВЫСОКАЯ

**F01 — Отсутствует пакет `ruby` для цветного вывода taoup**
- Задача: T1 (Карта зависимостей)
- Файл: `scripts/cachyos-packages.sh:507`
- Проблема: `gem install ansi --no-document --no-user-install` требует `ruby`, которого нет
  в `PACMAN_PKGS` или `AUR_PKGS`. Падает молча (`|| true`), taoup без ANSI-цветов.
- Исправление: добавить `ruby` в `PACMAN_PKGS` в `scripts/cachyos-packages.sh`.
- Проверка: `gem install ansi` успешен; `taoup` выводит цветной текст.

**F02 — `mpdas_config` использует raw gopass без fallback**
- Задача: T2 (Секреты)
- Файл: `states/mpd.sls:80-92`
- Проблема: Использует inline `gopass show -o lastfm/username` и `gopass show -o lastfm/password`
  внутри `set -eo pipefail`. Если gopass недоступен при первом запуске (до создания
  `~/.config/mpdasrc`), состояние падает жёстко. Все остальные Salt-состояния используют макрос
  `gopass_secret()` с graceful fallback.
- Что ломается: состояние `mpdas_config` падает, Salt сообщает об ошибке. Последующие запуски
  пропускают его (guard `creates:`).
- Исправление: рефакторинг на макрос `gopass_secret()` или добавить `|| true` с проверкой пустого значения.
- Проверка: `just test` с недоступным gopass; состояние должно деградировать, не падать.

**F03 — chezmoi apply падает без gopass (7 `.tmpl` файлов)**
- Задача: T2 (Секреты)
- Файл: `scripts/salt-apply.sh:282`, `dotfiles/dot_config/` (7 template files)
- Проблема: `chezmoi apply --force` вызывается после успешного Salt. Все `.tmpl` файлы с
  `{{ gopass "..." }}` падают, если gopass недоступен. Из-за `set -euo pipefail` скрипт
  завершается с ненулевым кодом, хотя все Salt-состояния прошли.
- Затронутые шаблоны: `proxypilot/config.yaml.tmpl`, `mbsync/private_mbsyncrc.tmpl`,
  `imapnotify/private_gmail.json.tmpl`, `msmtp/private_config.tmpl`,
  `rescrobbled/private_config.toml.tmpl`, `vdirsyncer/private_config.tmpl`,
  `zsh/private_10-secrets.zsh.tmpl`
- Варианты исправления: (a) добавить `--exclude` для `.tmpl` файлов при первом запуске,
  или (b) обернуть chezmoi в нефатальный блок с диагностическим выводом,
  или (c) документировать, что Yubikey/gopass должны быть настроены до salt-apply.
- Проверка: `salt-apply.sh` выполняется end-to-end с настроенным gopass.

**F04 — `floorp_profile=""` создаёт orphaned конфиги**
- Задача: T4 (Feature Flags) / T8 (Host Config)
- Файл: `states/floorp.sls:7`
- Проблема: По умолчанию `floorp_profile: ""` при `floorp: true` (тоже по умолчанию) приводит
  к тому, что `{% set floorp_profile = home ~ '/.floorp/' ~ host.floorp_profile %}` резолвится
  в `~/.floorp/` (корень профиля, а не конкретный профиль). Все конфиги (user.js,
  userChrome.css, расширения) пишутся в директорию, которую Floorp игнорирует.
- Затрагивает: любой хост не-telfir, использующий значения по умолчанию.
- Исправление: добавить guard в `floorp.sls`: `{% if host.features.floorp and host.floorp_profile %}`,
  чтобы пропускать состояния, когда профиль не настроен.
- Проверка: `just render-matrix` с синтетическим хостом, имеющим пустой `floorp_profile`.

**F05 — Хрупкий sed-патч Python 3.14**
- Задача: T11 (Runtime stability)
- Файл: `scripts/salt-apply.sh:55-61`
- Проблема: `sed -i` патчит исходный код Salt `url.py` фиксированным шаблоном. Если код Salt
  изменится (даже в пределах `>=3006,<3008`), sed молча ничего не сделает, и Salt сломается
  на поведении `urlunparse` в Python 3.14. Ручной `pip install --upgrade salt` теряет патч.
- Исправление: зафиксировать точную версию Salt в `requirements.txt` (например, `salt==3006.10`),
  или перенести патч в `salt_compat.py` как runtime monkey-patch (переживает pip upgrade).
- Проверка: удалить `.venv`, перезапустить `salt-apply.sh`, подтвердить работу Salt.

### СРЕДНЯЯ

**F06 — placeholder gopass store URL в документации**
- Задача: T9 (Документация)
- Файл: `docs/deploy-cachyos.md` (Шаг 4)
- Проблема: `gopass clone <store-url>` содержит placeholder. Нет GPG key ID, нет шагов инициализации Yubikey.
  Новый развёртывающий не сможет выполнить этот шаг.
- Исправление: добавить URL gopass store (или ссылку на `docs/gopass-setup.md`) и отпечатки GPG-ключей.

**F07 — Неявный порядок выполнения относительно `user_neg`**
- Задача: T3 (Порядок выполнения)
- Файлы: `zsh.sls`, `desktop.sls`, `greetd.sls` и другие
- Проблема: Состояния, устанавливающие владельца файлов `neg`, полагаются на порядок include
  (users.sls выполняется первым), но не имеют явного `require: user: user_neg`.
- Риск: НИЗКИЙ на практике (users.sls всегда первый include), СРЕДНИЙ архитектурно.
- Исправление: добавить `require: user: user_neg` в ключевые состояния zsh.sls, владеющие файлами как `neg`.

**F08 — Promtail без Loki = лог-спам в runtime**
- Задача: T4 (Feature Flags)
- Файл: `states/monitoring.sls`, `states/configs/promtail.yaml.j2:7`
- Проблема: Если `promtail=true` и `loki=false`, Promtail бесконечно шлёт данные на `127.0.0.1:3100`.
  Salt apply успешен, но journal заполняется ошибками соединения.
- Исправление: добавить кросс-флаговую валидацию: `{% if host.features.monitoring.promtail and not host.features.monitoring.loki %}` → warning или пропуск promtail.

**F09 — Нет hash pinning в requirements.txt**
- Задача: T11 (Стабильность runtime)
- Файл: `requirements.txt`
- Проблема: Нет флага `--require-hashes`. Salt venv работает от root — скомпрометированный
  PyPI-пакет может выполнить произвольный код от root во время bootstrap.
- Исправление: добавить hash pinning или использовать lockfile (`pip-compile` с хешами).

**F10 — Salt/chezmoi двойная запись для 8 путей**
- Задача: T7 (Границы)
- Файлы: `opencode.sls`, `mpd.sls`, `zsh.sls`, `user_services.sls`
- Проблема: 8 файловых путей управляются и Salt (`file.managed`/`file.recurse` из `salt://dotfiles/...`),
  и chezmoi (разворачивает из того же дерева исходников). Контент идентичен, но двойная запись
  избыточна, и права доступа могут расходиться.
- Исправление: выбрать одного владельца для каждого файла. Salt должен управлять файлами,
  нужными для триггеров `watch`/`onchanges`; chezmoi должен владеть чисто декларативными dotfiles.

**F11 — chezmoi apply без retry и диагностики при сбое**
- Задача: T7 (Границы) / T11 (Runtime)
- Файл: `scripts/salt-apply.sh:282`
- Проблема: `chezmoi apply --force` выполняется один раз, без retry. При сбое (gopass timeout,
  отсутствие Yubikey) `set -euo pipefail` завершает скрипт без указания, какие файлы упали.
- Исправление: обернуть в диагностический блок, перечисляющий `.tmpl` файлы, требующие gopass,
  или добавить `|| { echo "chezmoi failed — check gopass/Yubikey"; exit 1; }`.

**F12 — amnezia.sls без явного require на mount_one**
- Задача: T4 (Feature Flags) / T3 (Порядок выполнения)
- Файл: `states/amnezia.sls:4`
- Проблема: Использует `host.mnt_one` для директории кэша без явного `require: mount: mount_one`.
  Полагается на выполнение `mounts.sls` раньше через порядок include.
- Исправление: добавить явный require.

**F13 — Pre-release версия ProxyPilot (0.3.0-dev-0.39)**
- Задача: T5 (Устойчивость URL)
- Файл: `states/data/versions.yaml:32`
- Проблема: Pre-release версия может быть удалена из GitHub при выходе стабильного релиза.
  Кэш загрузки смягчает проблему для существующих установок, но свежие развёртывания упадут.
- Мitigation: уже закэшировано локально. Отслеживать стабильный релиз.

**F14 — В документации отсутствует guidance по восстановлению после ошибок**
- Задача: T9 (Документация)
- Файл: `docs/deploy-cachyos.md`
- Проблема: Нет указаний: (a) что делать при частичном сбое salt-apply, (b) безопасен ли
  повторный запуск, (c) какие ручные шаги нужны после salt-apply (Floorp profile, Steam login,
  настройка email).
- Исправление: добавить раздел «Troubleshooting», покрывающий восстановление после частичных
  сбоев и чеклист после развёртывания.

**F15 — Риск смены display manager при частичном сбое**
- Задача: T11 (Стабильность runtime)
- Файл: `states/greetd.sls`
- Проблема: Если SDDM отключён, но включение greetd не удаётся, после перезагрузки не будет
  display manager. Смягчено `getty@tty2` аварийным TTY, но документация должна упоминать
  этот путь восстановления.

### НИЗКАЯ

**F16 — `kernel.variant` — мёртвый feature flag**
- Задача: T4 (Feature Flags)
- Файл: `states/data/hosts.yaml:32`
- Проблема: `features.kernel.variant: lto` определён в defaults, но ни один `.sls` файл его не использует.
- Исправление: удалить мёртвый флаг или реализовать поведение, зависящее от варианта ядра.

**F17 — Feature matrix без тестов edge case**
- Задача: T4 (Feature Flags)
- Файл: `states/data/feature_matrix.yaml`
- Проблема: Нет тестового сценария для `floorp=true, floorp_profile=""` или «все флаги выключены».
- Исправление: добавить синтетические сценарии хостов для этих edge case.

**F18 — 2 случайных дубликата AUR-пакетов**
- Задача: T10 (Пересечение пакетов)
- Файлы: `scripts/cachyos-packages.sh`, `states/installers_desktop.sls`, `states/desktop.sls`
- Проблема: `overskride-bin` и `xdg-desktop-portal-termfilechooser-...-git` устанавливаются
  и `cachyos-packages.sh`, и Salt, без дополнительного управления конфигами от Salt.
- Исправление: удалить из одного места (предпочтительно `cachyos-packages.sh`, так как Salt
  не добавляет конфигурации).

**F19 — 26+ HIGH-risk незафиксированных внешних URL**
- Задача: T5 (Устойчивость URL)
- Файлы: Различные `.sls`, `data/mpv_scripts.yaml`, `data/floorp.yaml`
- Проблема: Множество URL, указывающих на git HEAD (`zi`, `hyprevents`, `dr14_tmeter`, `rustnet`,
  `kora-icons`, `matugen-themes`), master raw-файлы (mpv scripts, qmk udev rules,
  blesh nightly), `/latest/` endpoints (все 21 расширение Floorp) и незафиксированные
  PyPI/crates.io пакеты (`httpstat`, `scdl`, `faker`, `pzip`, `wiremix`).
- Все имеют retry + idempotency guards (нет CRITICAL), но воспроизводимость контента не гарантируется.
- Исправление: зафиксировать версии где возможно. Для git-репозиториев использовать
  tagged releases или commit SHA.

**F20 — Grafana datasource ссылается на мёртвый Loki при loki=false**
- Задача: T4 (Feature Flags)
- Файл: `states/monitoring.sls:80-88`
- Проблема: Когда `grafana=true` но `loki=false`, datasource Loki создаётся, указывая на
  `127.0.0.1:3100`. Grafana работает, но показывает красный/ошибочный datasource.
- Исправление: сделать provisioning datasource условным от флага `loki`.

**F21 — Алиас `cachyos -> telfir` влияет на все свежие установки CachyOS**
- Задача: T8 (Конфигурация хоста)
- Файл: `states/data/hosts.yaml:87`
- Проблема: Любая свежая установка CachyOS (hostname = "cachyos") получает telfir-специфичную
  конфигурацию (4K-дисплей, fancontrol, monitoring stack). Вторая машина потребует ручного
  изменения hostname перед запуском Salt.
- Исправление: задокументировать это поведение в `docs/adding-host.md` или удалить алиас.

**F22 — opencode.sls без feature gate** (openclaw_agent удалён 2026-04-11)
- Задача: T4 (Feature Flags)
- Файлы: `states/opencode.sls`
- Проблема: Это состояние всегда выполняется независимо от конфигурации хоста. На минимальном
  профиле хоста оно установит npm-пакеты и настроит сервисы безусловно.
- Серьёзность: Низкая — в настоящее время осознанно (одна рабочая станция), но ограничивает
  гибкость multi-host.

---

## Карты зависимостей

### Зависимости от инструментов (T1)

100+ внешних команд проверены во всех 37 `.sls` файлах. **1 отсутствующий инструмент:**

| Инструмент | Источник | Используется в | Влияние |
|------------|----------|----------------|---------|
| `gem` (Ruby) | **ОТСУТСТВУЕТ** | `scripts/cachyos-packages.sh:507` | taoup без цветного вывода (молчаливый сбой) |

Все остальные инструменты корректно предоставлены: BASE system (coreutils, systemd, kmod, btrfs-progs),
PACMAN_PKGS (ripgrep, curl, git, cargo, pipx, npm, gopass, podman и т.д.),
AUR_PKGS (paru, mpdas, mpdris2 и т.д.) или Salt-installed бинарники (через макросы).
**Проблем с порядком не найдено** — все цепочки require корректны.

### Зависимости от секретов (T2)

16 уникальных gopass key paths:

| Secret Key | Слой | Fallback | Влияние при отсутствии |
|------------|------|----------|------------------------|
| `api/proxypilot-local` | Salt + chezmoi | awk parse config | Деградация (пустой ключ) |
| `api/proxypilot-management` | Salt + chezmoi | awk parse config | Деградация (нет dashboard) |
| `api/anthropic` | Salt | пустая строка | Деградация (нет Anthropic API) |
| `api/nanoclaw-telegram` | Salt | пустая строка | Деградация (нет Telegram бота) |
| `api/nanoclaw-telegram-uid` | Salt | пустая строка | Деградация (то же) |
| `lastfm/username` | Salt (raw!) | **НЕТ** | **СЛОМАНО** (F02) |
| `lastfm/password` | Salt (raw!) | **НЕТ** | **СЛОМАНО** (F02) |
| `lastfm/api-key` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `lastfm/api-secret` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `email/gmail/address` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `email/gmail/app-password` | runtime only | N/A | Сбой аутентификации на уровне приложения |
| `caldav/google/client-id` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `caldav/google/client-secret` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `api/github-token` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `api/brave-search` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |
| `api/context7` | chezmoi | **НЕТ** | **СЛОМАНО** (chezmoi падает) |

**Salt-рендеринг**: деградирует gracefully (кроме mpdas_config F02).
**chezmoi-фаза**: hard fail на всех 7 .tmpl файлах (F03).

### Риски внешних URL (T5)

| Уровень риска | Кол-во | Примеры |
|---------------|--------|---------|
| LOW | 16 | Все записи из `data/installers.yaml` (version + hash + retry + guard) |
| MEDIUM | 15 | kanata (нет hash), tailray (cargo git), AUR пакеты |
| HIGH | 26+ | git HEAD клоны, master raw файлы, Floorp /latest/, unpinned pip/cargo |
| CRITICAL | 0 | Все URL имеют хотя бы retry + idempotency guard |

---

## План исправлений

### Фаза 1: Блокеры развёртывания

| Находка | Исправление | Трудоёмкость |
|---------|-------------|--------------|
| F03 | Обернуть chezmoi apply диагностической обработкой | 15 мин |
| F06 | Заполнить gopass store URL + GPG key IDs в документации | 10 мин |
| F14 | Добавить секцию troubleshooting/recovery | 30 мин |

### Фаза 2: Высокая серьёзность

| Находка | Исправление | Трудоёмкость |
|---------|-------------|--------------|
| F01 | Добавить `ruby` в PACMAN_PKGS | 1 мин |
| F02 | Рефакторинг mpdas_config на gopass_secret() | 15 мин |
| F04 | Добавить guard floorp_profile в floorp.sls | 5 мин |
| F05 | Зафиксировать версию Salt или перенести патч | 30 мин |

### Фаза 3: Средняя серьёзность

| Находка | Исправление | Трудоёмкость |
|---------|-------------|--------------|
| F07 | Добавить явный `require: user: user_neg` в zsh.sls | 5 мин |
| F08 | Добавить cross-flag валидацию promtail/loki | 10 мин |
| F09 | Добавить hash pinning в requirements.txt | 20 мин |
| F10 | Разделить владение файлами Salt/chezmoi | 30 мин |
| F11 | Добавить chezmoi retry/диагностику | 15 мин |
| F12 | Добавить mount_one require в amnezia.sls | 2 мин |

### Фаза 4: Низкая серьёзность

| Находка | Исправление | Трудоёмкость |
|---------|-------------|--------------|
| F16 | Удалить мёртвый kernel.variant flag | 2 мин |
| F17 | Добавить edge case сценарии в feature matrix | 10 мин |
| F18 | Удалить 2 AUR-дубликата из одного источника | 5 мин |
| F19 | Зафиксировать версии для high-risk URL | Постоянно |
| F20 | Сделать Grafana Loki datasource условным | 5 мин |
| F21 | Задокументировать поведение алиаса cachyos | 5 мин |
| F22 | Рассмотреть feature gate для opencode | 5 мин |

---

## Находки v1.0 (сохранены)

Все находки v1.0 остаются валидными. Все HIGH исправлены в предыдущих коммитах.

### Сводка v1.0

| Серьёзность | Всего | Исправлено | Принято |
|-------------|-------|------------|---------|
| Критическая | 0 | — | — |
| Высокая | 4 | 4 | 0 |
| Средняя | 3 | 1 | 2 |
| Низкая | 2 | 1 | 1 |

Все 59 состояний cmd.run/cmd.script прошли проверки идемпотентности.
Проверено 25+ цепочек зависимостей между файлами.
Проанализировано 21 systemd unit на hardening.
Проверено 34 макроса в 5 файлах.
17 YAML-файлов данных синтаксически корректны и потребляются.

### Справочник находок v1.0

| ID | Серьёзность | Описание | Статус |
|----|-------------|----------|--------|
| F01-v1 | Высокая | Отсутствующие health checks для Jellyfin и Transmission | Исправлено |
| F02-v1 | Высокая | DuckDNS token через аргументы curl | Исправлено (ba8880c) |
| F03-v1 | Высокая | Секретные файлы без chezmoi `private_` префикса | Исправлено (ba8880c) |
| F04-v1 | Высокая | npm без `--prefix`; отсутствие gopass fallback | Исправлено (8ad94a8) |
| F05-v1 | Средняя | Сервисы без hardening директив | Исправлено (cd91a38) |
| F06-v1 | Средняя | Ollama/llama-embed без ProtectHome | Принято |
| F07-v1 | Средняя | Fancontrol/sing-box без PrivateDevices | Принято |
| F08-v1 | Низкая | Неиспользуемые Jinja imports | Исправлено (24c7b35) |
| F09-v1 | Низкая | gopass_secret с python_shell=True | Принято |
| F10-v1 | Высокая | Bare service.enabled без pacman_install | Исправлено |
