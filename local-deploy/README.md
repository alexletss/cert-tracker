# 🏠 Локальный сервер — учёт сертификатов

Полная инструкция по поднятию приложения на локальном компьютере (Windows 10) без выхода в интернет. После настройки сайт будет доступен по IP-адресу твоего компьютера всем устройствам в твоей сети.

---

## 📦 Что входит в локальную сборку

- **Postgres 15** — база данных
- **PostgREST** — REST API над базой (то же что использует Supabase)
- **GoTrue** — авторизация (опционально, можно не использовать — у тебя своя)
- **Storage API** — хранилище файлов (для сканов и заявлений)
- **Realtime** — синхронизация изменений между пользователями
- **Kong API Gateway** — единая точка входа (как у облачного Supabase)
- **Nginx** — раздаёт статичный сайт `index.html`

Всё запускается одной командой `docker compose up -d`.

---

## 🖥️ Требования к компьютеру

- Windows 10 64-bit (build 19041+) или Windows 11
- Минимум 8 ГБ оперативной памяти (рекомендую 16 ГБ)
- 20 ГБ свободного места на диске
- Включённая виртуализация в BIOS (обычно включена по умолчанию)
- Права администратора

---

## 🛠 Шаг 1. Установка Docker Desktop

1. Скачай Docker Desktop для Windows: https://www.docker.com/products/docker-desktop/
2. Запусти установщик, оставь все галки по умолчанию (WSL 2 backend)
3. Перезагрузи компьютер
4. Запусти Docker Desktop, дождись пока в трее не появится зелёная иконка кита
5. Проверка — открой PowerShell и набери:
```
docker --version
docker compose version
```
Должно показать версии без ошибок.

---

## 📁 Шаг 2. Скачивание проекта

Открой PowerShell (правой кнопкой → Запустить от имени администратора) и выполни:

```
cd C:\
git clone https://github.com/alexletss/cert-tracker.git
cd cert-tracker\local-deploy
```

Если git не установлен — скачай вручную ZIP с GitHub и распакуй в `C:\cert-tracker\`.

---

## 🔑 Шаг 3. Настройка секретов

В папке `local-deploy` создай файл `.env` (пример уже лежит в `.env.example`):

```
copy .env.example .env
notepad .env
```

В файле смени `POSTGRES_PASSWORD` и `JWT_SECRET` на свои значения (минимум 32 символа). Можно сгенерировать через PowerShell:
```
-join ((48..57) + (97..122) | Get-Random -Count 40 | % {[char]$_})
```

Сохрани файл.

---

## 🚀 Шаг 4. Запуск всех сервисов

В той же папке `local-deploy`:

```
docker compose up -d
```

Первый запуск займёт 3-5 минут (скачивает образы). Когда закончит — все сервисы будут работать в фоне.

Проверка:
```
docker compose ps
```

Должны быть `running` все сервисы: `postgres`, `postgrest`, `storage`, `realtime`, `kong`, `nginx`.

---

## 🗄️ Шаг 5. Создание схемы базы данных

Схема создаётся автоматически при первом старте Postgres из файла `init-db.sql`. Если уже запустил `docker compose up -d` — она уже создалась.

Проверить можно через PowerShell:
```
docker exec -it certtracker-postgres psql -U postgres -d certtracker -c "\dt"
```

Должны быть таблицы: `certificates`, `users`, `audit_log`, `purposes`.

---

## 📥 Шаг 6. Перенос данных из облачного Supabase

В папке `local-deploy/migration/` есть готовый скрипт `migrate.html` — открой его в браузере (двойной клик).

Что он делает:
1. Подключается к твоему облачному Supabase (URL и ключ уже зашиты).
2. Выкачивает все строки из `certificates`, `users`, `audit_log`, `purposes`.
3. Загружает их в локальный Postgres через локальный PostgREST.
4. Скачивает все файлы из облачного Storage и загружает в локальный Storage.

Перенос займёт 1-5 минут в зависимости от количества данных. По окончании — увидишь зелёный «✅ Готово».

---

## 🌐 Шаг 7. Доступ из сети

### Узнать IP компьютера
```
ipconfig
```
Ищи строку `IPv4-адрес`. Например: `192.168.1.50`.

### Открыть порт в брандмауэре Windows

В PowerShell от админа:
```
New-NetFirewallRule -DisplayName "CertTracker" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "CertTracker API" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### Зайти с другого компьютера
В браузере: `http://192.168.1.50` (замени на свой IP)

Логин: `admin`
Пароль: `cert2026`

---

## 🔄 Полезные команды

| Команда | Что делает |
|---|---|
| `docker compose up -d` | Запустить все сервисы |
| `docker compose down` | Остановить все сервисы |
| `docker compose restart` | Перезапустить |
| `docker compose logs -f` | Смотреть логи в реальном времени |
| `docker compose ps` | Статус сервисов |
| `docker exec -it certtracker-postgres psql -U postgres -d certtracker` | Войти в SQL-консоль |

---

## 💾 Бэкап базы

Раз в неделю выполняй:
```
docker exec certtracker-postgres pg_dump -U postgres certtracker > C:\backups\certtracker_$(Get-Date -Format yyyy-MM-dd).sql
```

Восстановление из бэкапа:
```
docker exec -i certtracker-postgres psql -U postgres certtracker < C:\backups\certtracker_2026-06-03.sql
```

---

## 🚨 Автозапуск при включении компьютера

Docker Desktop сам запускается с Windows. А контейнеры в `docker-compose.yml` помечены `restart: unless-stopped` — то есть запустятся автоматически.

Чтобы Docker Desktop стартовал сам: Settings → General → ✅ Start Docker Desktop when you sign in.

---

## ❓ Если что-то не работает

1. **Не открывается сайт** — проверь `docker compose ps` (все running?). Если нет — `docker compose logs <имя-сервиса>` покажет причину.
2. **Не подключается к API** — проверь брандмауэр Windows (Шаг 7).
3. **Файлы не загружаются** — проверь права на папку `local-deploy/data/storage`.
4. **Realtime не работает** — перезапусти `docker compose restart realtime`.

Если что-то совсем не идёт — напиши мне, приложи вывод `docker compose logs --tail=100`.

---

## 📂 Структура проекта

```
local-deploy/
├── README.md              ← эта инструкция
├── docker-compose.yml     ← все сервисы
├── .env.example           ← шаблон для секретов
├── init-db.sql            ← схема базы при первом запуске
├── kong.yml               ← конфиг API Gateway
├── nginx/
│   ├── nginx.conf         ← конфиг веб-сервера
│   └── index.html         ← сам сайт (локальная версия)
├── migration/
│   └── migrate.html       ← скрипт переноса из облака
└── data/                  ← создастся автоматически при первом запуске
 ├── postgres/
 └── storage/
```
