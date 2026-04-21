# Объяснимость Salt

Репозиторий сохраняет `states/**/*.sls` как основной исполняемый контракт, но теперь поверх него есть слой explainability.

Цель этого слоя простая: отвечать на такие вопросы без ручного и тяжёлого `grep`-разбора:

- Почему вообще существует это состояние?
- Какой state владеет этим state ID?
- Какой YAML-инвентарь питает этот state?
- Какие states импортируют этот data-файл?
- Какой macro, вероятно, используется этим state?

## Источник истины

Инструменты explainability намеренно строятся поверх явного Salt, а не вместо него.

Что остаётся источником истины:

- `states/**/*.sls`
  Исполняемое дерево Salt.
- `states/system_description.sls`
  Явная верхнеуровневая карта оркестрации.
- `states/host_config.jinja`
  Runtime-источник правды для host-конфигурации.
- `states/data/*.yaml`
  Структурированные инвентари и декларативные входные данные.

Что является производным слоем:

- `scripts/salt_source_model.py`
  Канонический обход дерева и извлечение source metadata.
- `scripts/index-salt.py`
  Rendered state IDs, include-связи и сгенерированные индексы.
- `scripts/render-matrix.py`
  Проверка рендера по сценариям и JSON-результаты.
- `scripts/dep-graph.py`
  Граф include/requisite в text, dot, svg и json.
- `scripts/salt_provenance.py`
  Обратные lookup-индексы по states, state IDs, YAML-файлам, data keys и macros.

Правило такое: производный tooling может объяснять дерево, но не подменяет само дерево.

## Почему `system_description.sls` остаётся явным

`states/system_description.sls` намеренно не генерируется.

Это человекочитаемая карта верхнеуровневой оркестрации хоста и самый быстрый способ понять общий порядок сборки и основные feature gates. Explainability-слой дополняет её более точными ответами, но не прячет top-level graph за новым DSL.

## Общая модель discovery

Explainability-слой начинается с `scripts/salt_source_model.py`.

Он даёт канонический recursive-discovery и source metadata для всех `states/**/*.sls`, включая:

- канонический dotted `state_name`
- repo-relative `relpath`
- `top_level_entrypoint`
- `workflow_apply_target`
- импортируемые YAML-файлы
- feature guards, извлечённые из условных Jinja-выражений

Эта shared model уже используется текущими explainability scripts, чтобы они перестали иметь разные версии того, как выглядит дерево states.

## Provenance-запросы

Для reverse lookup используется `scripts/salt_provenance.py`.

Поддерживаемые запросы:

```bash
.venv/bin/python3 scripts/salt_provenance.py --state services
.venv/bin/python3 scripts/salt_provenance.py --state-id unbound_restart_or_reload
.venv/bin/python3 scripts/salt_provenance.py --data-file states/data/service_catalog.yaml
.venv/bin/python3 scripts/salt_provenance.py --data-key service_catalog.loki
.venv/bin/python3 scripts/salt_provenance.py --macro ensure_dir
```

Для любого режима доступен JSON-вывод:

```bash
.venv/bin/python3 scripts/salt_provenance.py --state services --json
```

Сокращения через `Justfile`:

```bash
just provenance services
just provenance-id unbound_restart_or_reload
```

## Что provenance-слой умеет уже сейчас

Текущие lookup-режимы сделаны прагматично, а не ради полной формальности.

`--state`
- Возвращает owning state file, entrypoint-флаги, импортируемые YAML-файлы, includes, state IDs и feature guards.

`--state-id`
- Возвращает owning state или states для rendered Salt state ID.

`--data-file`
- Возвращает states, которые импортируют или иначе используют YAML-файл.

`--data-key`
- Сначала пытается найти source-level match вроде `catalog.loki`, а не только владение файлом целиком.
- Если точное сопоставление невозможно, безопасно откатывается к file-level consumers.

`--macro`
- Возвращает states, которые, по исходнику, вызывают реальную macro из `states/_macros_*.jinja`.
- Lookup по macros ограничен реально определёнными macros, поэтому обычные вызовы вроде `get(...)` или `items(...)` не считаются provenance macros.

## Ограничения текущего provenance-слоя

Текущая реализация уже полезна, но местами она всё ещё эвристическая.

- `--data-key` точен только там, где в исходнике явно виден imported alias и key path.
- Lookup по macros опирается на реальные определения, но всё ещё работает по source-level анализу, а не по полноценному Jinja AST.
- Provenance для requisites пока заметно проще, чем полная семантика state graph.

На этом этапе это нормально: задача слоя — сначала улучшить повседневную отладку и навигацию, а потом уже углублять точность.

## Связанные инструменты

Explainability-слой шире, чем только provenance.

Полезные соседние команды:

```bash
.venv/bin/python3 scripts/render-matrix.py --json
.venv/bin/python3 scripts/dep-graph.py --format json
VALIDATE_SUMMARY_FILE=/tmp/validate-summary.json scripts/salt-validate.sh
```

Эти команды дают machine-readable outputs, не ломая текущий человеческий CLI.

## Архитектурный смысл

Репозиторий движется к explainable Salt system, а не к generated Salt system.

Это означает:

- верхнеуровневая topology остаётся явной
- inventories остаются обычными YAML-файлами
- state files остаются ревьюемыми артефактами
- tooling добавляет traceability и reverse lookup capability
- новая абстракция оправдана только тогда, когда она улучшает observability, а не просто делает код более DRY

Это и есть базовое ограничение, которое задаёт текущий рефакторинг.
