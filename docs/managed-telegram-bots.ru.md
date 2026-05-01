# Managed Telegram Bots (Bot API 9.6+)

## Обзор

Bot API 9.6 (3 апреля 2026) представил **Managed Bots** — возможность боту
программно создавать и управлять другими ботами без BotFather.

Это позволяет сделать мульти-бот раннер: один бот-менеджер создаёт, получает
токены и управляет десятками ботов для разных задач без ручного вмешательства.

## Как это работает

1. Бот-менеджер включает управление ботами в мини-аппе @BotFather.
2. `getMe` возвращает `can_manage_bots: true`.
3. Бот показывает пользователю кнопку или ссылку.
4. Пользователь нажимает → Telegram предлагает создать бота → готово.
5. Бот-менеджер получает токен нового бота через `getManagedBotToken(user_id)`.

## Требования

- Бот-менеджер должен включить управление ботами в @BotFather Mini App
- Только боты с `can_manage_bots: true` (из `getMe`) могут участвовать
- Создание managed-ботов работает только в **личных чатах**

## API Reference

### Поле User: `can_manage_bots`

```
Field             Type      Description
can_manage_bots   Boolean   True, если можно создавать других ботов
                            для управления. Только в getMe.
```

### Запуск создания бота

**1. Кнопка** — `KeyboardButton` с `request_managed_bot`:

```json
{
  "text": "Создать бота",
  "request_managed_bot": {
    "request_id": 0,
    "suggested_name": "Мой помощник",
    "suggested_username": "my_helper_bot"
  }
}
```

**2. Ссылка** — `t.me` ссылка:
```
https://t.me/newbot/{manager_username}/{suggested_username}?name={name}
```

**3. Mini App** — сохранение кнопки через `savePreparedKeyboardButton`.

### Получение созданного бота

Бот-менеджер получает два события:

1. **Update** с `managed_bot` → `ManagedBotUpdated`:
   - `user` — пользователь, создавший бота
   - `bot` — объект User нового бота

2. **Message** с `managed_bot_created` → `ManagedBotCreated`:
   - `bot` — объект User нового бота

### Управление токенами

```python
# Получить токен
GET /bot<manager_token>/getManagedBotToken?user_id=<new_bot_user_id>
→ "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"

# Заменить (отозвать старый, сгенерировать новый)
GET /bot<manager_token>/replaceManagedBotToken?user_id=<new_bot_user_id>
→ "654321:XYZ-DEF5678ghIkl-zyx57W2v1u123ew11"
```

### Обновления токена/владельца

Если токен или владелец managed-бота меняется, бот-менеджер получает
новый `ManagedBotUpdated` через поле `managed_bot`.

## Пример workflow

```
1. Бот-менеджер отправляет кнопку request_managed_bot
2. Пользователь нажимает → Telegram показывает диалог создания бота
3. Пользователь выбирает имя/username → бот создан
4. Бот-менеджер получает:
   - Update.managed_bot (кто создал, информация о боте)
   - Message.managed_bot_created (информация о боте)
5. Бот-менеджер вызывает getManagedBotToken → получает токен
6. Бот-менеджер может управлять новым ботом (установить webhook и т.д.)
```

## Варианты использования

- Мульти-бот раннер: один systemd-сервис под Salt управляет ботом-менеджером,
  который создаёт ботов под конкретные задачи
- Self-service: пользователи нажимают кнопку → получают личного бота для
  мониторинга, скриншотов, доступа к секретам, управления VPN и т.д.
- Без BotFather: создание и ротация токенов полностью автоматизированы

## Ссылки

- [Документация Telegram Bot API](https://core.telegram.org/bots/api)
- [@BotNews](https://t.me/botnews) — официальный changelog Bot API
- [@BotFather](https://t.me/BotFather) — включить управление ботами
