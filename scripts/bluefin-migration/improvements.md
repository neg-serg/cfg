# build-all.sh — improvements & known issues

| # | Что | Сейчас | Как улучшить | Приоритет |
|---|-----|--------|-------------|-----------|
| 1 | **RPM-слой** | Containerfile с жёстко вписанными 390 пакетами | Генерить из `packages.yaml` через `generate-bluefin-image.py`, убрать дубликаты | 🔴 high |
| 2 | **Маппинг имён** | Разбросан по коду, Containerfile, generate-bluefin-image.py | Единый `mapping.yaml`: Arch→Fedora. Скрипт читает его при генерации | 🔴 high |
| 3 | **Fallback на хост** | `copy_binary /usr/bin/$bin` — бинарник может быть другой версии | Собирать ВСЁ из исходников. Хост только для Hyprland (сложная сборка) | 🟡 med |
| 4 | **Кеширование cargo/go** | Каждый запуск — чистый `cargo install` с нуля | `CARGO_HOME=/tmp/cargo-cache`, `GOMODCACHE=/tmp/go-cache` | 🟡 med |
| 5 | **Параллельность** | Всё последовательно | `cargo install` поддерживает `--jobs`, git clone можно параллелить через `&` | 🟡 med |
| 6 | **Верификация** | Нет проверки что все 563 пакета в образе | `verify-image.sh` — запускает контейнер и проверяет каждый пакет через `rpm -q`/`command -v` | 🟡 med |
| 7 | **Инкрементальные билды** | `--no-cache` всегда | Podman layer caching для RPM-слоя, пересобирать только host-built слой | 🟢 low |
| 8 | **Логирование** | Всё в stdout, ошибки теряются | `build-all.sh 2>&1 | tee build.log`, сводка ошибок в конце | 🟢 low |
| 9 | **Конфиг SOCKS5** | Прокси только в ad-hoc командах | `proxy.conf` с креденшелами, `source proxy.conf` в скриптах | 🟢 low |
| 10 | **Тегирование образа** | `:latest` всегда | `:latest` + `:$(date +%Y%m%d)` + `:$(git rev-parse --short HEAD)` | 🟢 low |
| 11 | **Размер образа** | 34 GB | Убрать `--no-cache` для RPM-слоя, использовать `--squash`, вынести `lib32` в отдельный слой | 🟢 low |
| 12 | **Containerfile.hyprland** | Ручные `ln -sf`, `RUN echo` для каждого симлинка | Список симлинков в `symlinks.txt`, один `RUN` применяет все | 🟢 low |

**Первоочерёдное (high):** унифицировать маппинг имён в одном YAML-файле и перегенерить Containerfile из `packages.yaml` — это уберёт дубликаты и false negatives при проверке.
