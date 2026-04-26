# TODO

## Периодическая очистка кэшей (cron / systemd timer)

После уборки ~34G кэшей вручную стоит автоматизировать очистку того, что не покрывает `paccache.timer`:

- **`paru -Sc`** — очистка AUR clone-кэша (14G было). Paru хранит все клонированные PKGBUILD-ы. Добавить еженедельный systemd timer или cron.
- **`pip cache purge`** — 2.9G кэша pip. Ежемесячно.
- **`npm cache clean --force`** — 1.7G кэша npm. Ежемесячно.
- **`flatpak uninstall --unused`** — удаление неиспользуемых flatpak-рантаймов. Раз в месяц.
- **`cargo cache -a`** — очистка cargo registry (если cargo используется активно). Ежемесячно.

Предпочтительный вариант: systemd timers (единообразно с существующим `paccache.timer`), по одному юниту на сервис. Либо один shell-скрипт, запускаемый из `cron` или одного systemd timer.

## Пайплайн анализа музыки (essentia + annoy)

Скрипты `music-highlevel`, `music-similar`, `music-index` требуют:
- `essentia` (предоставляет `streaming_extractor_music`) — нет в репозиториях Arch, нужен AUR или собственный PKGBUILD
- `python-annoy` — библиотека приближённых ближайших соседей, pip или AUR

Создать отдельный Salt-стейт (`music_analysis.sls` или расширить `installers.sls`):
1. Сборка/установка `essentia` через paru или PKGBUILD
2. Установка `python-annoy` через макрос pip_pkg
3. Идемпотентные проверки для обоих


## Сервис ydotool не включён

`ydotool.service` (systemd user unit) установлен, но **отключён и неактивен**.
Инструменты Hyprland MCP (`mouse_click`, `click_text`, `key_press` и др.) зависят от работающего `ydotoold`.

**Исправление**: включить пользовательский сервис через Salt (`user_services.sls` или аналог):
```
systemctl --user enable --now ydotool.service
```

Без этого инструменты автоматизации мыши/клавиатуры Hyprland MCP молча падают или выдают ошибки при click/type операциях. Скриншоты работают (используют `grim`/`slurp`, а не ydotool).


## Косметические улучшения

**npmrc prefix**: глобальный npm prefix установлен на `/nonexistent` (из `/etc/npmrc`).
Создать `~/.npmrc` с `prefix=$HOME/.local` через chezmoi (`dotfiles/dot_npmrc`).
Без этого `npm list -g` и `npm outdated -g` не работают (Salt-установка обходит проблему через `--prefix`).

**Комментарий к alias ProxyPilot**: формат `name/alias` в `proxypilot.yaml.j2` неочевиден. Добавить комментарий, объясняющий направление маппинга (alias = что шлёт клиент, name = локальный ID модели).


## Упаковка браузера Nyxt

`nyxt-bin` — бинарная упаковка браузера Nyxt. Требуется исследование:
текущий AUR-пакет может быть достаточным, или может потребоваться собственный PKGBUILD.


## Домашний LLM-кластер — exo / llama.cpp RPC

При сборке многонодового домашнего кластера оценить варианты распределённого LLM-инференса:

- **[exo](https://github.com/exo-explore/exo)** (~42k звёзд) — P2P-кластер, auto-discovery через libp2p, автошардинг по разнородным устройствам. AMD ROCm поддерживается через tinygrad. Нет AUR-пакета (только pip). OpenAI-совместимый API — подключается к ProxyPilot. Лучше всего для: моделей >VRAM (класс 70B–235B).
- **llama.cpp RPC backend** — уже установлен (`llama.cpp-vulkan`). Запуск `rpc-server` на удалённых нодах, подключение через `--rpc host:50052`. Без дополнительных зависимостей. Поддержка Vulkan. Лучше всего для: расширения текущего стека с минимальными накладными расходами.
- **Ollama cluster mode** — в разработке upstream, может появиться до сборки кластера. Отслеживать прогресс.

Решение: предпочтителен llama.cpp RPC (уже в стеке, AUR-пакет, Vulkan). Пересмотреть exo, когда созреет поддержка AMD ROCm и/или появится AUR-пакет.


## tg-cli: зарегистрировать собственные API-ключи Telegram

`tg-cli` (pipx, `kabi-tg-cli`) установлен и работает с дефолтными ключами Telegram Desktop (`api_id=2040`).
Это повышает риск ограничения аккаунта со стороны Telegram.

- [ ] Зарегистрировать приложение на https://my.telegram.org/apps (потребуется SMS/код из Telegram)
- [ ] Создать `~/.config/tg-cli/.env` с `TG_API_ID` и `TG_API_HASH`
- [ ] Переавторизоваться: `tg status` (подхватит новые ключи)
- [ ] Опционально: сохранить ключи в gopass (`api/telegram-api`)

Примечание: форма my.telegram.org может молча отказывать — известная проблема, попробовать позже или из другого браузера/IP.


## SaluteSpeech — оценка STT/TTS

Оценить [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Сбер) для распознавания (STT) и синтеза (TTS) русской речи.

- Freemium: ~1000 мин/мес STT бесплатно
- Сравнить с локальными альтернативами: `faster-whisper` (large-v3), Vosk
- Решение: облачный API (SaluteSpeech) vs self-hosted (Whisper на GPU)
- При внедрении: Salt-стейт для установки, API-ключ в gopass, systemd-сервис


## IPv6 диагностика и настройка

Проверка IPv6 показала, что стек работает, но глобальные адреса отсутствуют и внешняя связь невозможна.

**Проблемы:**
- ❌ Глобальные IPv6‑адреса отсутствуют (только link‑local `fe80::`)
- ❌ Маршрут по умолчанию (`default`) не настроен
- ❌ Связь с внешними IPv6‑хостами невозможна (`Network is unreachable`)
- ✅ DNS разрешение AAAA‑записей работает
- ❌ Туннельные механизмы (6to4, Teredo, Miredo) не установлены
- ⚠️  `ip6tables` активен с политикой `DROP` на INPUT/FORWARD (может блокировать ICMPv6)

**Действия:**
1. Проверить настройки IPv6 на маршрутизаторе/коммутаторе (включить SLAAC/DHCPv6)
2. Если провайдер не предоставляет IPv6, настроить туннель (Hurricane Electric, SixXS)
3. При необходимости временно отключить `ufw` для IPv6 (`sudo ufw disable` для IPv6) или добавить правила для ICMPv6
4. Для тестирования можно использовать `ping -6` с указанием интерфейса (`-I`) или `curl --interface`
