#!/bin/bash
# prepare_release.sh - подготовка релиза для Inno Setup
# Запускать ИЗ КОРНЕВОЙ ПАПКИ ПРОЕКТА или из любой папки
# Вычищает проект от ненужных папок и библиотек

# ================================
# НАСТРОЙКА ПУТЕЙ - ПОДСТАВЬТЕ СВОИ!
# ================================

# Вариант 1: Абсолютные пути (рекомендуется)
PROJECT_ROOT="/c/Users/pomai/programming/code/projects/qt_qml/MonitorHead"
BUILD_DIR="$PROJECT_ROOT/build/Desktop_Qt_6_10_0_MinGW_64_bit-Release"
RELEASE_DIR="$PROJECT_ROOT/Release_For_Installer"
QT_PATH="/c/Qt/6.10.0/mingw_64/bin"

# Вариант 2: Относительные пути (если запускать из корня проекта)
# PROJECT_ROOT="."  # Текущая папка
# BUILD_DIR="./build/Desktop_Qt_6_10_0_MinGW_64_bit-Reliase"
# RELEASE_DIR="./Release_For_Installer"
# QT_PATH="/c/Qt/6.10.0/mingw_64/bin"

# ================================
# ФУНКЦИИ
# ================================

# Цветной вывод
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Показать структуру папок без tree
show_structure() {
    local dir="$1"
    local depth="${2:-0}"
    local indent=""
    
    # Создаем отступ
    for ((i=0; i<depth; i++)); do
        indent+="  "
    done
    
    # Показываем файлы в текущей папке
    for item in "$dir"/*; do
        local name=$(basename "$item")
        
        if [ -d "$item" ]; then
            echo "${indent}📁 $name/"
            # Рекурсивно показываем содержимое (максимум 2 уровня)
            if [ $depth -lt 1 ]; then
                show_structure "$item" $((depth + 1))
            fi
        elif [ -f "$item" ]; then
            # Показываем только некоторые файлы на первом уровне
            if [ $depth -eq 0 ] || [ $depth -eq 1 ]; then
                echo "${indent}📄 $name"
            fi
        fi
    done
}

# Проверить и создать папку
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_info "Создана папка: $1"
    fi
}

# Проверить наличие файла
check_file() {
    if [ ! -f "$1" ]; then
        print_error "Файл не найден: $1"
        return 1
    fi
    return 0
}

# Проверить наличие папки
check_dir() {
    if [ ! -d "$1" ]; then
        print_error "Папка не найдена: $1"
        return 1
    fi
    return 0
}

# ================================
# ОСНОВНАЯ ЛОГИКА
# ================================

# Шаг 0: Проверка путей
print_info "Проверка путей..."
check_dir "$BUILD_DIR" || exit 1
check_file "$BUILD_DIR/MonitorHead.exe" || exit 1

# Шаг 1: Очистка старой папки релиза
print_info "Очистка старой папки релиза..."
if [ -d "$RELEASE_DIR" ]; then
    rm -rf "$RELEASE_DIR"
    print_info "Удалена старая папка: $RELEASE_DIR"
fi

# Создаем новую структуру
ensure_dir "$RELEASE_DIR"
ensure_dir "$RELEASE_DIR/platforms"
ensure_dir "$RELEASE_DIR/imageformats"
ensure_dir "$RELEASE_DIR/iconengines"

# Шаг 2: Копирование исполняемого файла
print_info "Копирование MonitorHead.exe..."
cp "$BUILD_DIR/MonitorHead.exe" "$RELEASE_DIR/"
print_info "✓ MonitorHead.exe скопирован"

# Шаг 2.1: Копирование README.txt файла
print_info "Копирование README.txt..."
cp "$BUILD_DIR/README.txt" "$RELEASE_DIR/"
print_info "✓ README.txt скопирован"

# Шаг 3: Копирование DLL файлов
print_info "Копирование DLL файлов..."
dll_count=0
for dll in "$BUILD_DIR"/*.dll; do
    if [ -f "$dll" ]; then
        filename=$(basename "$dll")
        # Пропускаем отладочные библиотеки
        if [[ ! "$filename" =~ d\.dll$ ]] && [[ ! "$filename" =~ _debug\.dll$ ]]; then
            cp "$dll" "$RELEASE_DIR/"
            dll_count=$((dll_count + 1))
        fi
    fi
done
print_info "✓ Скопировано $dll_count DLL файлов"

# Шаг 4: Копирование обязательных папок Qt
print_info "Копирование плагинов Qt..."

# Платформенные плагины
if [ -f "$BUILD_DIR/platforms/qwindows.dll" ]; then
    cp "$BUILD_DIR/platforms/qwindows.dll" "$RELEASE_DIR/platforms/"
    print_info "  ✓ qwindows.dll"
fi

# Форматы изображений
declare -a image_formats=("qjpeg.dll" "qpng.dll" "qgif.dll" "qsvg.dll")
for format in "${image_formats[@]}"; do
    if [ -f "$BUILD_DIR/imageformats/$format" ]; then
        cp "$BUILD_DIR/imageformats/$format" "$RELEASE_DIR/imageformats/"
        print_info "  ✓ $format"
    fi
done

# Шаг 5: Копирование пользовательских данных
print_info "Копирование пользовательских данных..."

declare -a user_folders=("models" "research" "info" "qml" "licenses")
for folder in "${user_folders[@]}"; do
    if [ -d "$BUILD_DIR/$folder" ]; then
        cp -r "$BUILD_DIR/$folder" "$RELEASE_DIR/"
        print_info "  ✓ Папка $folder"
    fi
done

# Шаг 6: Запуск windeployqt (опционально)
print_info "Проверка зависимостей windeployqt..."
if [ -f "$QT_PATH/windeployqt.exe" ]; then
    # Конвертируем пути для Windows
    if command -v cygpath &> /dev/null; then
        WIN_RELEASE_DIR=$(cygpath -w "$RELEASE_DIR")
        WIN_PROJECT_DIR=$(cygpath -w "$PROJECT_ROOT")
    else
        # Простая конвертация для Git Bash
        WIN_RELEASE_DIR=$(echo "$RELEASE_DIR" | sed 's/^\///' | sed 's/\//\\/g')
        WIN_RELEASE_DIR="C:\\${WIN_RELEASE_DIR}"
        WIN_PROJECT_DIR=$(echo "$PROJECT_ROOT" | sed 's/^\///' | sed 's/\//\\/g')
        WIN_PROJECT_DIR="C:\\${WIN_PROJECT_DIR}"
    fi
    
    print_info "Запуск: windeployqt.exe --release --qmldir \"$WIN_PROJECT_DIR\" \"$WIN_RELEASE_DIR\\MonitorHead.exe\""
    "$QT_PATH/windeployqt.exe" --release --qmldir "$WIN_PROJECT_DIR" "$WIN_RELEASE_DIR\\MonitorHead.exe"
    
    if [ $? -eq 0 ]; then
        print_info "✓ windeployqt выполнен успешно"
    else
        print_warning "windeployqt завершился с ошибками"
    fi
else
    print_warning "windeployqt не найден по пути: $QT_PATH/windeployqt.exe"
    print_warning "Пропускаем проверку зависимостей"
fi

# Шаг 7: Итоговая информация
print_info "========================================"
print_info "ПОДГОТОВКА РЕЛИЗА ЗАВЕРШЕНА!"
print_info "========================================"

# Показываем размер
if command -v du &> /dev/null; then
    total_size=$(du -sh "$RELEASE_DIR" | cut -f1)
    print_info "Итоговый размер: $total_size"
fi

# Считаем файлы
file_count=$(find "$RELEASE_DIR" -type f | wc -l)
print_info "Количество файлов: $file_count"

# Показываем структуру
print_info "Структура папок релиза:"
echo "========================================"
show_structure "$RELEASE_DIR"
echo "========================================"

# Шаг 8: Создание ISS файла для Inno Setup (опционально)
print_info "Создание скрипта Inno Setup..."
ISS_FILE="$PROJECT_ROOT/script/MonitorHead.iss"

cat > "$ISS_FILE" << EOF
; ========================================
; MonitorHead Setup Script
; Inno Setup Script для MonitorHead
; Сгенерировано автоматически
; ========================================

#define MyAppName "MonitorHead"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Trofimov RV"
#define MyAppExeName "MonitorHead.exe"
#define MyIconPath "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\images\logo.ico"

[Setup]
AppId={{90DBD8C4-7E9F-44C1-8DFF-28ED15470F1B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\executable_files
OutputBaseFilename=MonitorHead_Setup
SetupIconFile={#MyIconPath}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright=Copyright © {#MyAppPublisher}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\Release_For_Installer\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\Release_For_Installer\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyIconPath}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
  // Инициализация мастера установки
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResearchPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    ResearchPath := ExpandConstant('{userdocs}') + '\MonitorHead\research';
    if not DirExists(ResearchPath) then
      ForceDirectories(ResearchPath);
      
    SaveStringToFile(
      ResearchPath + '\README.txt',
      'Папка для сохранения исследований MonitorHead' + #13#10 +
      'Файлы: Research_номер_дата_время.txt',
      False
    );
  end;
end;
EOF

print_info "✓ Файл Inno Setup создан: $ISS_FILE"

# Финальное сообщение
print_info "========================================"
print_info "ЧТО ДЕЛАТЬ ДАЛЬШЕ:"
print_info "1. Папка с релизом: $RELEASE_DIR"
print_info "2. Файл Inno Setup: $ISS_FILE"
print_info "3. Откройте Inno Setup Compiler"
print_info "4. Загрузите файл $ISS_FILE"
print_info "5. Нажмите Build → Compile (F9)"
print_info "========================================"

# Открываем папку в проводнике Windows
if command -v explorer &> /dev/null; then
    print_info "Открываю папку в проводнике..."
    explorer "$(echo "$RELEASE_DIR" | sed 's/\//\\/g')"
fi