# Настройка SonoBus

Peer-to-peer потоковая передача аудио с низкой задержкой между устройствами. Устанавливается из AUR (`sonobus`), запускается как отдельное GTK-приложение с поддержкой плагинов VST3/LV2.

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│  SonoBus (standalone)                                   │
│  ┌──────────┐    ┌──────────┐    ┌───────────────────┐  │
│  │ Входной  │    │ Эффекты  │    │ Протокол AOO     │  │
│  │ микшер   │───→│ (EQ,     │───→│ (Opus / PCM по   │──→ P2P peers
│  │          │    │  Gate,   │    │  UDP)            │  │
│  └──────────┘    │  Reverb) │    └───────────────────┘  │
│                  └──────────┘              ▲             │
│  ┌──────────┐    ┌──────────┐              │             │
│  │ Рекордер │←───│ Выходной │←─────────────┘             │
│  │ (multi-  │    │ микшер   │                             │
│  │  track)  │    └──────────┘                             │
└─────────────────────────────────────────────────────────┘
         │
         │ PipeWire / ALSA
         ▼
  RME ADI-2 / USB Audio / HDMI
```

## Компоненты

| Компонент | Пакет | Версия | Источник |
|---|---|---|---|
| SonoBus (отдельное приложение) | `sonobus` (AUR) | 1.7.2 | AUR |
| SonoBus VST3 plugin | bundled | 1.7.2 | AUR build |
| SonoBus LV2 plugin | bundled | 1.7.2 | AUR build |
| SonoBus Instrument VST3 | bundled | 1.7.2 | AUR build |
| JUCE framework | vendored | bundled | upstream |
| AOO (Audio Over OSC) | vendored | bundled | upstream |

## Быстрый старт

### 1. Запуск GUI

```bash
sonobus
```

Либо через меню приложений, если установлен desktop entry.

### 2. Подключение к группе

В GUI:
1. Введите **Group Name** (общий секрет: все с одинаковым именем попадут в одну группу)
2. При необходимости задайте **Group Password**
3. Укажите **Display Name**
4. Нажмите **Connect**

### 3. Запуск через CLI (преднастроенный)

```bash
# Подключиться к группе напрямую из командной строки
sonobus --group "my-session" --username "neg"

# С паролем и собственным сервером
sonobus --group "my-session" --username "neg" \
  --group-password "secret" \
  --connectionserver "myserver.example.com"

# Headless (без GUI, для серверов и автоматизации)
sonobus --headless --group "my-session" --username "neg"
```

### 4. Сохранение и загрузка пресетов

В GUI: **Options → Save Setup** создаёт файл `.setup` со всеми выбранными устройствами, настройками микшера и опциями. Позже его можно загрузить так:

```bash
sonobus --load-setup ~/music/sonobus/my-preset.setup
```

## Опции командной строки

| Флаг | Описание |
|---|---|
| `--group <name>` | Имя группы для подключения |
| `--username <name>` | Отображаемое имя |
| `--group-password <pw>` | Пароль группы (необязательно) |
| `--connectionserver <addr[:port]>` | Собственный AOO-сервер |
| `--load-setup <file>` | Загрузить сохранённый пресет |
| `--headless` | Режим без GUI |
| `--version` | Показать версию |
| `--help` | Показать справку |

## Интеграция с аудиоустройствами

В этой системе SonoBus использует PipeWire через ALSA/JACK-совместимость. Доступные устройства:

| Устройство | Роль | Примечания |
|---|---|---|
| RME ADI-2 | Основной I/O | 8 каналов, управляется через PipeWire |
| USB Audio | Дополнительный I/O | Обычный USB-аудиоинтерфейс |
| Navi 48 HDMI/DP | Только вывод | Аудио с GPU по DisplayPort |

Чтобы направить SonoBus через конкретные узлы PipeWire, используйте `pw-cli` или `qpwgraph` после того, как SonoBus создаст свои аудиопорты.

## Подключение с других устройств

| Платформа | Как получить |
|---|---|
| **iOS** | App Store — найдите "SonoBus" |
| **Android** | Google Play / F-Droid — найдите "SonoBus" |
| **macOS** | Скачать с [sonobus.net](https://sonobus.net) |
| **Windows** | Скачать с [sonobus.net](https://sonobus.net) |
| **Linux (other)** | Сборка из исходников или AUR |
| **DAW (any)** | Использовать bundled VST3/LV2 plugin |

Все устройства подключаются в одну группу, если ввести одинаковое имя группы. Центральный сервер не требуется: peers соединяются напрямую друг с другом.

## Варианты кодирования

| Режим | Качество | Пропускная способность | Сценарий использования |
|---|---|---|---|
| PCM (без сжатия) | Без потерь | ~1.4 Mbps (stereo 44.1kHz) | LAN, студийное качество |
| Opus (high) | Почти без потерь | ~128-256 kbps | Хороший интернет |
| Opus (medium) | Хорошее | ~64-128 kbps | Обычный интернет |
| Opus (low) | Приемлемое | ~32-64 kbps | Плохое соединение |

## Расположение файлов

| Путь | Назначение |
|---|---|
| `/usr/bin/sonobus` | Основной исполняемый файл |
| `/usr/share/applications/sonobus.desktop` | Desktop entry |
| `~/.config/SonoBus/` | Пользовательские настройки и пресеты |
| VST3: `/usr/lib/vst3/SonoBus.vst3/` | VST3 plugin |
| VST3: `/usr/lib/vst3/SonoBusInstrument.vst3/` | VST3 instrument plugin |
| LV2: `/usr/lib/lv2/SonoBus.lv2/` | LV2 plugin |

## Устранение неполадок

### SonoBus не видит аудиоустройства

SonoBus использует ALSA напрямую. Проверьте, что ALSA-устройства доступны:

```bash
aplay -l   # список устройств вывода
arecord -l # список устройств захвата
```

Если устройств нет, проверьте, что PipeWire запущен:

```bash
systemctl --user status pipewire wireplumber
```

### Высокая задержка

1. Переключите кодирование с PCM на Opus: меньшая полоса пропускания = меньше джиттера
2. Немного увеличьте jitter buffer в настройках SonoBus
3. Проверьте сеть: `ping <peer_ip>` — в LAN должно быть <5ms
4. Для LAN-сессий обычно подходит PCM, для интернета используйте Opus

### Не удаётся подключиться к группе

1. Убедитесь, что оба peers используют **точно одно и то же** имя группы с учётом регистра
2. Проверьте firewall: SonoBus требует открытых UDP-портов в динамическом диапазоне
3. Если вы за NAT, публичный AOO-сервер помогает с discovery, но для P2P всё равно нужны достижимые IP-адреса
4. Попробуйте собственный `--connectionserver`, если сервер по умолчанию недоступен

### Headless mode сразу завершается

Для headless-режима необходимо указать `--group`. Без него SonoBus выводит ошибку и завершает работу с `exit code 0`.
