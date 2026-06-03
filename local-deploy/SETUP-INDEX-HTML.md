# 🔧 Шаг 8. Подмена index.html для работы с локальным сервером

После того как Docker-контейнеры запущены (Шаг 4 из основного README), нужно подменить файл `local-deploy/nginx/index.html` на главный сайт с настройками под локальный сервер.

---

## Что нужно поменять

В корневом файле `index.html` (тот, что лежит в корне репозитория) в самом начале `<script>` есть четыре строки:

```javascript
const SUPABASE_URL = "https://fpvusjatdwqzedhgljru.supabase.co";
const SUPABASE_KEY = "sb_publishable_GnvmwL6B_MPvDdiqDRljmA_VrfsX7da";
```

Их нужно заменить на:

```javascript
const SUPABASE_URL = "http://" + location.hostname + ":8000";
const SUPABASE_KEY = "local-dev-key";
```

Так сайт автоматически будет обращаться к Kong на том же сервере, откуда его открыли (через IP из браузера).

---

## Способ 1 — автоматический (PowerShell)

В PowerShell от админа, в папке `C:\cert-tracker`:

```powershell
$src = Get-Content -Raw index.html -Encoding UTF8
$src = $src -replace 'const SUPABASE_URL = "https://fpvusjatdwqzedhgljru\.supabase\.co";', 'const SUPABASE_URL = "http://" + location.hostname + ":8000";'
$src = $src -replace 'const SUPABASE_KEY = "sb_publishable_GnvmwL6B_MPvDdiqDRljmA_VrfsX7da";', 'const SUPABASE_KEY = "local-dev-key";'
Set-Content -Path local-deploy
ginx\index.html -Value $src -Encoding UTF8
docker compose -f local-deploy\docker-compose.yml restart nginx
```

Готово. Сайт по адресу `http://<твой-IP>` теперь обращается к локальной базе.

---

## Способ 2 — вручную

1. Скопируй файл `index.html` из корня репозитория в `local-deploy/nginx/index.html` (заменив существующий placeholder).
2. Открой `local-deploy/nginx/index.html` в Блокноте или VS Code.
3. Через Ctrl+F найди строку `const SUPABASE_URL` и замени значение.
4. Найди `const SUPABASE_KEY` — замени значение.
5. Сохрани файл в кодировке UTF-8 (важно — без BOM).
6. Перезапусти nginx:
```
docker compose restart nginx
```

---

## Проверка

Открой в браузере с другого устройства в сети: `http://<IP-сервера>` (например, `http://192.168.1.50`).
Должен открыться экран входа. Введи admin / cert2026 — попадёшь внутрь.
Если в правом нижнем углу видишь облачную иконку «☁️ Облако» — это нормально, текст остался от облачной версии. Хочешь сменить на «🏠 Локально» — открой файл и замени строку:

```html
<span class="cloud-badge">☁️ Облако</span>
```
на
```html
<span class="cloud-badge">🏠 Локально</span>
```

---

## Если данных нет

После подмены и захода — таблица будет пустая. Это нормально: локальная база только что создалась.

Чтобы перенести данные из облака:
1. На том же компьютере открой `local-deploy/migration/migrate.html` (двойной клик).
2. В поле «URL локального сервера» введи `http://localhost:8000` (или `http://<IP-сервера>:8000`).
3. Нажми «🚀 Начать перенос».
4. Дождись «=== ГОТОВО ===».
5. Обнови страницу приложения — увидишь все данные.
