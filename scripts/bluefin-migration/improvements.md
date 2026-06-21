# build-all.sh — improvements & known issues

| # | Что | Статус |
|---|-----|--------|
| 1 | RPM-слой из packages.yaml | ✅ done — 374 чистых RPM |
| 2 | Единый mapping.yaml | ✅ done — 363 маппинга |
| 3 | Fallback на хост | ✅ done — copy_binary |
| 4 | Кеширование cargo/go | ✅ done |
| 5 | Параллельность | ✅ done |
| 6 | Верификация | ✅ done — verify-image.sh |
| 7 | Инкрементальные билды | ✅ done |
| 8 | Логирование | ✅ done |
| 9 | Конфиг SOCKS5 | ✅ done |
| 10 | Тегирование образа | ✅ done |
| 11 | Размер образа | ✅ done |
| 12 | Containerfile.hyprland symlinks | ✅ done — symlinks.txt |

**Первоочерёдное (high):** унифицировать маппинг имён в одном YAML-файле и перегенерить Containerfile из `packages.yaml` — это уберёт дубликаты и false negatives при проверке.
