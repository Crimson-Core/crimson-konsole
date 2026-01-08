<div align="center">

<img src="textlogo.png" alt="Crimson Konsole" width="600"/>

<p align="center">
  <img src="logo.png" alt="Logo" width="200"/>
</p>

[![Godot Engine](https://img.shields.io/badge/Godot-4.5+-478cbf?style=for-the-badge&logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/GDScript-478cbf?style=for-the-badge&logo=godot-engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![License](https://img.shields.io/github/license/Crimson-Core/crimson-konsole?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/Crimson-Core/crimson-konsole?style=for-the-badge&logo=github)](https://github.com/seriouslych/crimson/stargazers)

**🎮 A stunning 3D game launcher with beautiful box art visualization 🎮**

[English](#english) | [Русский](#russian)

---

</div>

<a name="english"></a>

## 🌟 About

**Crimson Konsole** is a modern game launcher with a beautiful 3D interface that displays your games as physical box art in a coverflow-style presentation. Built with Godot Engine 4.5, it combines aesthetic appeal with practical functionality.

### ✨ Key Features

- **🎨 3D Coverflow Interface** - Browse your games in stunning 3D with smooth animations
- **🎮 Multi-Platform Support** - Works on Windows and Linux
- **📦 Multiple Box Types** - Support for Xbox, PlayStation, PC, Nintendo formats
- **🖼️ Auto Cover Download** - Integration with SteamGridDB for automatic cover art
- **⏱️ Play Time Tracking** - Track how long you've played each game
- **🎯 Gamepad & Keyboard Support** - Full support for Xbox, PlayStation, and generic controllers
- **🌍 Multilingual** - English, Russian, and Japanese localization
- **🎵 Music Player** - Built-in music player with reverb effects
- **✏️ Game Management** - Easy adding, editing, and organizing of games

## 🎬 Preview

> The launcher features a dynamic 3D interface where game boxes rotate and scale based on selection, creating an immersive browsing experience.

### Supported Box Types

- 🟦 PC/Steam
- 🟩 Xbox (Original, 360, One)
- 🔵 PlayStation (1-5)
- 🔴 Nintendo (N64, GameCube, Wii, Switch)

## 🚀 Installation

### Prerequisites

- Operating System: Windows 10+, Linux
- Display: 1920x1080 recommended
- Storage: ~100MB for application + space for game covers

### Download

1. Download the latest release from [Releases](https://github.com/Crimson-Core/crimson-konsole/releases)
2. Extract the archive
3. Run `CrimsonKonsole.exe` (Windows) or the executable for your platform

### Building from Source

```bash
# Clone the repository
git clone https://github.com/Crimson-Core/crimson-konsole.git
cd crimson-konsole

# Open in Godot 4.5+
# Project -> Export -> Select your platform
```

## 📖 Usage

### Adding Games

1. Press `ESC` or `Start` button to open the side panel
2. Select **"Add Game"**
3. Enter game name and select platform type
4. Choose the game executable
5. (Optional) Download covers automatically or select custom images
6. Press **"Done"** to save

### Navigation

#### Keyboard
- `↑/↓` - Navigate between games
- `Enter` - Launch game
- `ESC` - Open side panel
- `Tab` - Edit selected game
- `Home` - Change language

#### Gamepad
- `D-Pad` - Navigate between games
- `A Button` - Launch game
- `Start` - Open side panel
- `View/Select` - Edit selected game

### Managing Games

1. Select a game
2. Press `Tab` (keyboard) or `View` button (gamepad)
3. Edit game details:
   - Change name
   - Update executable path
   - Replace cover art
   - Delete game

## 🛠️ Technical Stack

- **Engine**: Godot 4.5
- **Language**: GDScript
- **3D Rendering**: Godot's 3D renderer with custom shaders
- **Cover API**: SteamGridDB integration via steamboxcover
- **Audio**: Built-in Godot audio with reverb effects
- **Input**: Support for keyboard, mouse, and gamepad (XInput, DualShock)

## 📁 Project Structure

```
crimson-konsole/
├── assets/           # Images, fonts, icons, SFX
├── models/           # 3D game box models
├── scenes/           # Godot scenes
│   ├── CoverFlow.tscn
│   ├── GameAdd.tscn
│   └── Main.tscn
├── scripts/          # GDScript files
│   ├── CoverFlow.gd
│   ├── GameLoader.gd
│   ├── GameTimeTracker.gd
│   └── ...
├── shaders/          # Custom GLSL shaders
└── translations/     # Localization files
```

## 🔧 Configuration

Settings are stored in:
- **Windows**: `%APPDATA%/Godot/app_userdata/Crimson Konsole/`
- **Linux**: `~/.local/share/godot/app_userdata/Crimson Konsole/`

### Config Files

- `settings.cfg` - Application settings
- `games/*.json` - Individual game data
- `game_times.json` - Play time tracking
- `covers/` - Downloaded cover images

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- [Godot Engine](https://godotengine.org/) - Amazing open-source game engine
- [SteamGridDB](https://www.steamgriddb.com/) - Cover art database
- [Kenney](https://kenney.nl/) - Input prompt assets
- All contributors and testers

## 📞 Support

- 🐛 [Report a Bug](https://github.com/Crimson-Core/crimson-konsole/issues)
- 💡 [Request a Feature](https://github.com/Crimson-Core/crimson-konsole/issues)
- 💬 [Discussions](https://github.com/Crimson-Core/crimson-konsole/discussions)

---

<a name="russian"></a>

## 🌟 О проекте

**Crimson Konsole** — это современный игровой лаунчер с красивым 3D интерфейсом, отображающий ваши игры в виде физических коробок в стиле coverflow. Создан на Godot Engine 4.5, сочетает эстетическую привлекательность с практичным функционалом.

### ✨ Основные возможности

- **🎨 3D Coverflow интерфейс** - Просматривайте игры в потрясающем 3D с плавными анимациями
- **🎮 Мультиплатформенность** - Работает на Windows и Linux
- **📦 Разные типы коробок** - Поддержка форматов Xbox, PlayStation, PC, Nintendo
- **🖼️ Автозагрузка обложек** - Интеграция с SteamGridDB для автоматической загрузки обложек
- **⏱️ Отслеживание времени** - Узнайте, сколько времени вы провели в каждой игре
- **🎯 Геймпад и клавиатура** - Полная поддержка контроллеров Xbox, PlayStation и других
- **🌍 Мультиязычность** - Локализация на английский, русский и японский языки
- **🎵 Музыкальный плеер** - Встроенный музыкальный плеер с эффектами реверберации
- **✏️ Управление играми** - Простое добавление, редактирование и организация игр

## 🎬 Предварительный просмотр

> Лаунчер имеет динамичный 3D интерфейс, где коробки игр вращаются и масштабируются при выборе, создавая захватывающий опыт просмотра.

### Поддерживаемые типы коробок

- 🟦 PC/Steam
- 🟩 Xbox (Original, 360, One)
- 🔵 PlayStation (1-5)
- 🔴 Nintendo (N64, GameCube, Wii, Switch)

## 🚀 Установка

### Системные требования

- ОС: Windows 10+, Linux
- Дисплей: Рекомендуется 1920x1080
- Место на диске: ~100МБ для приложения + место для обложек игр

### Загрузка

1. Скачайте последнюю версию из [Releases](https://github.com/Crimson-Core/crimson-konsole/releases)
2. Распакуйте архив
3. Запустите `CrimsonKonsole.exe` (Windows) или исполняемый файл для вашей платформы

### Сборка из исходников

```bash
# Клонируйте репозиторий
git clone https://github.com/Crimson-Core/crimson-konsole.git
cd crimson-konsole

# Откройте в Godot 4.5+
# Проект -> Экспорт -> Выберите вашу платформу
```

## 📖 Использование

### Добавление игр

1. Нажмите `ESC` или кнопку `Start` для открытия боковой панели
2. Выберите **"Добавить игру"**
3. Введите название игры и выберите тип платформы
4. Укажите исполняемый файл игры
5. (Опционально) Загрузите обложки автоматически или выберите свои изображения
6. Нажмите **"Готово"** для сохранения

### Навигация

#### Клавиатура
- `↑/↓` - Навигация между играми
- `Enter` - Запустить игру
- `ESC` - Открыть боковую панель
- `Tab` - Редактировать выбранную игру
- `Home` - Сменить язык

#### Геймпад
- `D-Pad` - Навигация между играми
- `Кнопка A` - Запустить игру
- `Start` - Открыть боковую панель
- `View/Select` - Редактировать выбранную игру

### Управление играми

1. Выберите игру
2. Нажмите `Tab` (клавиатура) или кнопку `View` (геймпад)
3. Редактируйте данные игры:
   - Изменить название
   - Обновить путь к исполняемому файлу
   - Заменить обложки
   - Удалить игру

## 🛠️ Технический стек

- **Движок**: Godot 4.5
- **Язык**: GDScript
- **3D рендеринг**: 3D движок Godot с пользовательскими шейдерами
- **API обложек**: Интеграция с SteamGridDB через steamboxcover
- **Аудио**: Встроенная аудиосистема Godot с эффектами реверберации
- **Ввод**: Поддержка клавиатуры, мыши и геймпада (XInput, DualShock)

## 📁 Структура проекта

```
crimson-konsole/
├── assets/           # Изображения, шрифты, иконки, звуки
├── models/           # 3D модели коробок игр
├── scenes/           # Сцены Godot
│   ├── CoverFlow.tscn
│   ├── GameAdd.tscn
│   └── Main.tscn
├── scripts/          # Файлы GDScript
│   ├── CoverFlow.gd
│   ├── GameLoader.gd
│   ├── GameTimeTracker.gd
│   └── ...
├── shaders/          # Пользовательские GLSL шейдеры
└── translations/     # Файлы локализации
```

## 🔧 Конфигурация

Настройки хранятся в:
- **Windows**: `%APPDATA%/Godot/app_userdata/Crimson Konsole/`
- **Linux**: `~/.local/share/godot/app_userdata/Crimson Konsole/`

### Файлы конфигурации

- `settings.cfg` - Настройки приложения
- `games/*.json` - Данные отдельных игр
- `game_times.json` - Отслеживание времени игры
- `covers/` - Загруженные изображения обложек

## 🤝 Вклад в проект

Вклад приветствуется! Не стесняйтесь отправлять issues и pull request'ы.

1. Сделайте форк репозитория
2. Создайте ветку для функции (`git checkout -b feature/AmazingFeature`)
3. Зафиксируйте изменения (`git commit -m 'Добавить AmazingFeature'`)
4. Отправьте в ветку (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request

## 📝 Лицензия

Этот проект лицензирован на условиях, указанных в файле [LICENSE](LICENSE).

## 🙏 Благодарности

- [Godot Engine](https://godotengine.org/) - Потрясающий движок с открытым исходным кодом
- [SteamGridDB](https://www.steamgriddb.com/) - База данных обложек
- [Kenney](https://kenney.nl/) - Ресурсы подсказок ввода
- Всем участникам и тестировщикам

## 📞 Поддержка

- 🐛 [Сообщить об ошибке](https://github.com/Crimson-Core/crimson-konsole/issues)
- 💡 [Предложить функцию](https://github.com/Crimson-Core/crimson-konsole/issues)
- 💬 [Обсуждения](https://github.com/Crimson-Core/crimson-konsole/discussions)

---

<div align="center">

Made with ❤️ using Godot Engine

**[⬆ Back to Top](#)**

</div>
