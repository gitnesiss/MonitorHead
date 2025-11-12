#include "tiltcontroller.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QtMath>
#include <QDateTime>
#include <QCoreApplication>
#include <QRegularExpression>
#include <algorithm>


TiltController::TiltController(QObject *parent) : QObject(parent)
    , m_logReader(this)  // инициализация log reader
    , m_angularSpeedUpdateFrequencyCOM(4.0f)
    , m_angularSpeedUpdateFrequencyLog(1.2f)
{
    m_logTimer.setInterval(16);
    connect(&m_logTimer, &QTimer::timeout, this, &TiltController::updateLogPlayback);

    m_autoConnectTimer.setInterval(5000);
    connect(&m_autoConnectTimer, &QTimer::timeout, this, &TiltController::autoConnect);

    m_safetyTimer.setInterval(2000);
    connect(&m_safetyTimer, &QTimer::timeout, this, [this]() {
        if (m_serialPort && m_serialPort->isOpen()) {
            if (m_serialPort->error() == QSerialPort::ResourceError) {
                qDebug() << "Safety timer detected port error, cleaning up...";
                safeDisconnect();
            }
        }
    });

    // Инициализация переменных для исследования
    m_researchFrameCounter = 1;
    m_headModel.resetData();
    refreshPorts();
    m_autoConnectTimer.start();
    addNotification("Программа запущена. Попытка автоматического подключения к COM-порту...");

    // Количество показываемых секунд на графике
    m_graphDuration = 30;

    // ОПТИМИЗАЦИЯ 5: Уменьшаем частоту обновления данных
    m_updateFrequency = 30;        // Для COM-порта
    m_logUpdateFrequency = 25;     // Для лог-файла (более плавно)
    m_dataUpdateTimer.setInterval(1000 / m_updateFrequency);
    connect(&m_dataUpdateTimer, &QTimer::timeout, this, &TiltController::updateDataDisplay);
    m_dataUpdateTimer.start();

    // ОПТИМИЗАЦИЯ: Инициализация временных меток
    m_startTime = QDateTime::currentMSecsSinceEpoch();
    m_lastDataTime = 0;
    m_useRelativeTime = true; // Используем относительное время для синхронизации
    m_lastDizzinessState = false;
    m_currentDizzinessStart = 0;

    // Инициализация переменных синхронизации
    m_playbackStartRealTime = 0;
    m_playbackStartLogTime = 0;
    m_playbackTimeInitialized = false;

    m_graphDisplayTime = m_graphDuration * 1000; // Начальное значение: показываем первые 30 секунд

    // Инициализация переменных синхронизации
    m_playbackStartRealTime = 0;
    m_playbackStartLogTime = 0;
    m_playbackTimeInitialized = false;

    // Инициализация буферов истории
    m_pitchHistory.reserve(m_speedCalculationPoints + 1);
    m_rollHistory.reserve(m_speedCalculationPoints + 1);
    m_yawHistory.reserve(m_speedCalculationPoints + 1);

    // Инициализация переменных для исследования
    m_researchFrameCounter = 1;
    m_researchRecordingStartTime = 0;  // Добавляем инициализацию

    // Настраиваем LogReader
    setupLogReader();

    m_logReader.setUpdateFrequency(m_angularSpeedUpdateFrequency);

    // Инициализация номера исследования
    initializeResearchNumber();

    emit angularSpeedUpdateFrequencyChanged(m_angularSpeedUpdateFrequency);

    m_comSpeedUpdateTimer.setInterval(1000 / m_angularSpeedUpdateFrequencyCOM);
    connect(&m_comSpeedUpdateTimer, &QTimer::timeout, this, &TiltController::updateCOMAngularSpeeds);
}

TiltController::~TiltController()
{
    m_isCleaningUp = true;
    cleanupCOMPort();
}

// Новый метод для настройки LogReader
void TiltController::setupLogReader()
{
    m_logReader.setUpdateFrequency(m_angularSpeedUpdateFrequency);
}

// Новый метод для обновления угловых скоростей с использованием LogReader
void TiltController::updateAngularSpeeds()
{
    if (!m_logLoaded || m_logData.isEmpty()) return;

    float speedPitch = m_logReader.calculateAngularSpeed(m_currentTime, "pitch", m_logPlaying);
    float speedRoll = m_logReader.calculateAngularSpeed(m_currentTime, "roll", m_logPlaying);
    float speedYaw = m_logReader.calculateAngularSpeed(m_currentTime, "yaw", m_logPlaying);

    // Обновляем модель с новыми скоростями
    if (m_currentLogIndex >= 0 && m_currentLogIndex < m_logData.size()) {
        const LogEntry &entry = m_logData[m_currentLogIndex];
        updateHeadModel(entry.pitch, entry.roll, entry.yaw,
                        speedPitch, speedRoll, speedYaw,
                        entry.dizziness || entry.doctorDizziness);
    }
}

void TiltController::initializeResearchNumber()
{
    QDir researchDir("research");
    int maxNumber = 0;

    // Создаем папку если не существует
    if (!researchDir.exists()) {
        researchDir.mkpath(".");
    }

    // Ищем файлы исследований
    QStringList filters;
    filters << "Research_*.txt";
    researchDir.setNameFilters(filters);
    researchDir.setSorting(QDir::Name);

    QFileInfoList files = researchDir.entryInfoList();

    for (const QFileInfo &file : files) {
        QString fileName = file.fileName();
        // Ищем паттерн Research_000001_2025_11_04_09_51_34.txt
        QRegularExpression re("Research_(\\d{6})_\\d{4}_\\d{2}_\\d{2}_\\d{2}_\\d{2}_\\d{2}\\.txt");
        QRegularExpressionMatch match = re.match(fileName);

        if (match.hasMatch()) {
            int number = match.captured(1).toInt();
            if (number > maxNumber) {
                maxNumber = number;
            }
        }
    }

    m_researchNumber = QString::number(maxNumber + 1).rightJustified(6, '0');
    emit researchNumberChanged(m_researchNumber);
}

void TiltController::toggleResearchRecording()
{
    if (!m_connected) {
        addNotification("Невозможно управлять записью: нет подключения к COM-порту");
        return;
    }

    if (m_recording) {
        stopResearchRecording();
    } else {
        startResearchRecording(m_researchNumber);
    }
}

QString TiltController::generateResearchFileName(const QString &number)
{
    QDateTime now = QDateTime::currentDateTime();
    QString dateStr = now.toString("yyyy_MM_dd");
    QString timeStr = now.toString("hh_mm_ss");

    return QString("research/Research_%1_%2_%3.txt")
        .arg(number)
        .arg(dateStr)
        .arg(timeStr);
}

void TiltController::writeResearchHeader()
{
    if (!m_researchStream) return;

    QString dateTimeStr = m_researchStartTime.toString("yyyy-MM-dd hh:mm:ss");

    *m_researchStream << "##########\n";
    *m_researchStream << "# Исследование № " << m_researchNumber << "\n";
    *m_researchStream << "# " << dateTimeStr << "\n";
    *m_researchStream << "##########\n";
    m_researchStream->flush();
}

void TiltController::connectDevice()
{
    if (m_connected) {
        disconnectDevice();
        return;
    }

    if (m_selectedPort.isEmpty()) {
        addNotification("Ошибка: COM-порт не выбран");
        return;
    }

    setupCOMPort();
}

void TiltController::disconnectDevice()
{
    safeDisconnect();
}

void TiltController::safeDisconnect()
{
    if (m_isCleaningUp) return;

    m_isCleaningUp = true;

    // Останавливаем запись исследования если она активна
    if (m_recording) {
        stopResearchRecording();
    }

    cleanupCOMPort();
    m_connected = false;

    // ПОЛНЫЙ СБРОС ДАННЫХ ПРИ ОТКЛЮЧЕНИИ
    m_dataBuffer.clear();
    m_prevFrame = DataFrame();

    // Сбрасываем буферы для расчета скоростей COM-порта
    clearCOMBuffers();
    m_currentComSpeedPitch = 0.0f;
    m_currentComSpeedRoll = 0.0f;
    m_currentComSpeedYaw = 0.0f;

    // Сбрасываем модель головы
    m_headModel.resetData();

    // Очищаем графики
    m_pitchGraphData.clear();
    m_rollGraphData.clear();
    m_yawGraphData.clear();
    m_dizzinessPatientData.clear();
    m_dizzinessDoctorData.clear();

    // Сбрасываем головокружение
    if (m_patientDizziness) {
        m_patientDizziness = false;
        emit patientDizzinessChanged(m_patientDizziness);
    }

    if (m_doctorDizziness) {
        m_doctorDizziness = false;
        emit doctorDizzinessChanged(m_doctorDizziness);
    }

    // Сбрасываем номер загруженного исследования при отключении (только в режиме COM-порта)
    if (!m_logMode && !m_loadedResearchNumber.isEmpty()) {
        m_loadedResearchNumber.clear();
        emit loadedResearchNumberChanged(m_loadedResearchNumber);
    }

    // Форсируем обновление графиков
    emit graphDataChanged();

    addNotification("Отключено от COM-порта. Данные сброшены.");
    emit connectedChanged(m_connected);
    m_isCleaningUp = false;
}

void TiltController::readCOMPortData()
{
    if (!m_serialPort || !m_serialPort->isOpen() || m_isCleaningUp) {
        return;
    }

    try {
        QByteArray data = m_serialPort->readAll();

        if (data.isEmpty()) {
            return;
        }

        processCOMPortData(data);

    } catch (const std::exception& e) {
        safeDisconnect();
    }
}

// ОПТИМИЗАЦИЯ: Улучшаем обработку временных меток в processCOMPortData
void TiltController::processCOMPortData(const QByteArray &data)
{
    m_incompleteData.append(data);

    // Ограничиваем размер буфера неполных данных
    if (m_incompleteData.size() > 2048) {
        m_incompleteData = m_incompleteData.right(1024); // Оставляем последние данные
    }

    int processedLines = 0;
    const int MAX_LINES_PER_CYCLE = 100; // Защита от зацикливания

    while (processedLines < MAX_LINES_PER_CYCLE) {
        int newlinePos = m_incompleteData.indexOf('\n');
        if (newlinePos == -1) {
            break;
        }

        QByteArray completeLine = m_incompleteData.left(newlinePos).trimmed();
        m_incompleteData = m_incompleteData.mid(newlinePos + 1);
        processedLines++;

        if (completeLine.isEmpty()) {
            continue;
        }

        QString dataString = QString::fromUtf8(completeLine);

        // ОПТИМИЗАЦИЯ: Более эффективная очистка строки
        QString cleanedString = dataString;
        cleanedString.remove(QRegularExpression("[^0-9;.-]"));

        if (!cleanedString.contains(';') || cleanedString.count(';') < 5) {
            continue;
        }

        QStringList parts = cleanedString.split(';');

        if (parts.size() >= 6) {
            bool ok1, ok2, ok3, ok4, ok5, ok6;

            // ОПТИМИЗАЦИЯ: Используем относительное время вместо абсолютного
            qint64 timestamp;
            if (m_useRelativeTime) {
                timestamp = QDateTime::currentMSecsSinceEpoch() - m_startTime;
            } else {
                timestamp = parts[0].toLongLong(&ok1);
                if (!ok1) {
                    timestamp = QDateTime::currentMSecsSinceEpoch() - m_startTime;
                }
            }

            float pitch = parts[1].replace(',', '.').toFloat(&ok2);
            float roll = parts[2].replace(',', '.').toFloat(&ok3);
            float yaw = parts[3].replace(',', '.').toFloat(&ok4);
            bool patientDizziness = (parts[4].toInt(&ok5) == 1);
            bool doctorDizziness = (parts[5].toInt(&ok6) == 1);

            if (ok2 && ok3 && ok4 && ok5 && ok6) {
                // ОПТИМИЗАЦИЯ: Проверяем корректность данных
                if (qIsNaN(pitch) || qIsNaN(roll) || qIsNaN(yaw) ||
                    qIsInf(pitch) || qIsInf(roll) || qIsInf(yaw)) {
                    continue;
                }

                // ОПТИМИЗАЦИЯ: Фильтруем выбросы
                if (pitch < -180 || pitch > 180 || roll < -180 || roll > 180 || yaw < -180 || yaw > 180) {
                    qDebug() << "Data out of range:" << pitch << roll << yaw;
                    continue;
                }

                DataFrame frame;
                frame.timestamp = timestamp;
                frame.pitch = pitch;
                frame.roll = roll;
                frame.yaw = yaw;
                frame.patientDizziness = patientDizziness;
                frame.doctorDizziness = doctorDizziness;

                m_dataBuffer.add(frame);
                processDataFrame(frame);

                m_lastDataTime = QDateTime::currentMSecsSinceEpoch();
            }
        }
    }
}

void TiltController::handleCOMPortError(QSerialPort::SerialPortError error)
{
    if (m_isCleaningUp) return;

    switch (error) {
    case QSerialPort::NoError:
        return;

    case QSerialPort::ResourceError:
        safeDisconnect();
        break;

    case QSerialPort::PermissionError:
        addNotification("Ошибка доступа к COM-порту. Закройте другие программы, использующие этот порт.");
        safeDisconnect();
        break;

    case QSerialPort::DeviceNotFoundError:
        addNotification("COM-порт не найден. Устройство было отключено.");
        safeDisconnect();
        break;

    default:
        // ДЛЯ ЛЮБОЙ ДРУГОЙ ОШИБКИ ТОЖЕ ВЫЗЫВАЕМ safeDisconnect
        if (m_serialPort) {
            addNotification("Ошибка COM-порта: " + m_serialPort->errorString() + ". Соединение разорвано.");
        } else {
            addNotification("Ошибка COM-порта. Соединение разорвано.");
        }
        safeDisconnect();  // ДОБАВЛЯЕМ ВЫЗОВ ДЛЯ ВСЕХ ОСТАЛЬНЫХ ОШИБОК
        break;
    }
}

void TiltController::autoConnect()
{
    if (m_connected || m_logMode) return;

    refreshPorts();

    if (!m_availablePorts.isEmpty()) {
        QString portToTry = m_availablePorts.first();
        setSelectedPort(portToTry);
        setupCOMPort();
    }
}

void TiltController::switchToCOMPortMode()
{
    if (m_logMode) {
        stopLog();
        m_logMode = false;
        emit logModeChanged(m_logMode);
        emit logControlsEnabledChanged(logControlsEnabled());

        // ПОЛНЫЙ СБРОС ДАННЫХ ПРИ ПЕРЕКЛЮЧЕНИИ В РЕЖИМ COM-ПОРТА
        m_headModel.resetData();
        m_dataBuffer.clear();
        m_prevFrame = DataFrame();

        // Очищаем графики
        m_pitchGraphData.clear();
        m_rollGraphData.clear();
        m_yawGraphData.clear();
        m_dizzinessPatientData.clear();
        m_dizzinessDoctorData.clear();

        // Сбрасываем головокружение
        if (m_patientDizziness) {
            m_patientDizziness = false;
            emit patientDizzinessChanged(m_patientDizziness);
        }

        if (m_doctorDizziness) {
            m_doctorDizziness = false;
            emit doctorDizzinessChanged(m_doctorDizziness);
        }

        // СБРАСЫВАЕМ НОМЕР ЗАГРУЖЕННОГО ИССЛЕДОВАНИЯ
        m_loadedResearchNumber.clear();
        emit loadedResearchNumberChanged(m_loadedResearchNumber);

        // Форсируем обновление графиков
        emit graphDataChanged();

        m_autoConnectTimer.start();
        addNotification("Переключено в режим реального времени. Данные сброшены.");
    }
}

void TiltController::playLog()
{
    if (!m_logLoaded || m_logData.isEmpty()) return;

    m_logPlaying = true;
    m_playbackTimeInitialized = false; // Сбрасываем флаг инициализации

    m_logTimer.start();
    emit logPlayingChanged(m_logPlaying);

    // ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ ВРЕМЕНИ ПРИ ЗАПУСКЕ
    emit currentTimeChanged(m_currentTime);

    addNotification("Воспроизведение данных начато");
}

void TiltController::pauseLog()
{
    m_logPlaying = false;
    m_logTimer.stop();

    // ОБНОВЛЯЕМ СКОРОСТИ С НОВОЙ ЛОГИКОЙ (для паузы)
    updateAngularSpeeds();

    // Обновляем графики для отображения текущей позиции
    updateGraphDataFromBuffer();

    // ВАЖНО: ФОРСИРУЕМ ОБНОВЛЕНИЕ ВРЕМЕНИ ПРИ ПАУЗЕ
    emit currentTimeChanged(m_currentTime);

    emit logPlayingChanged(m_logPlaying);
    addNotification("Воспроизведение данных приостановлено");
}

void TiltController::setSelectedPort(const QString &port)
{
    if (m_selectedPort != port) {
        m_selectedPort = port;
        emit selectedPortChanged();
    }
}

void TiltController::refreshPorts()
{
    m_availablePorts.clear();

    QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        m_availablePorts << port.portName();
    }

    if (m_availablePorts.isEmpty()) {
        m_availablePorts << "COM1" << "COM2" << "COM3";
        qDebug() << "No real COM ports found, using simulation ports";
    }

    emit availablePortsChanged();

    if (!m_availablePorts.isEmpty() && m_selectedPort.isEmpty()) {
        setSelectedPort(m_availablePorts.first());
    }
}

void TiltController::updateHeadModel(float pitch, float roll, float yaw,
                                     float speedPitch, float speedRoll, float speedYaw,
                                     bool dizziness)
{
    m_headModel.setMotionData(pitch, roll, yaw, speedPitch, speedRoll, speedYaw, dizziness);

    static qint64 lastGraphUpdate = 0;
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    if (currentTime - lastGraphUpdate >= (1000 / m_updateFrequency)) {
        updateGraphDataFromBuffer();
        lastGraphUpdate = currentTime;
    }
}

void TiltController::addNotification(const QString &message)
{
    m_notification = QDateTime::currentDateTime().toString("[hh:mm:ss] ") + message;
    emit notificationChanged(m_notification);
    qDebug() << message;
}

void TiltController::setGraphDuration(int duration)
{
    if (duration < 5) duration = 5;
    if (duration > 120) duration = 120;

    if (m_graphDuration != duration) {
        m_graphDuration = duration;
        emit graphDurationChanged(m_graphDuration);
        emit graphDataChanged();
    }
}

void TiltController::updateDataDisplay()
{
    static int updateCounter = 0;
    updateCounter++;

    bool shouldUpdate = false;

    if (m_connected && !m_logMode) {
        // COM-порт: обновляем чаще
        shouldUpdate = (updateCounter % 1 == 0);
    } else if (m_logPlaying) {
        // Лог-режим: обновляем реже (уже делается в updateLogPlayback)
        shouldUpdate = false;
    } else if (m_logLoaded && !m_logPlaying) {
        // Пауза в логе: обновляем редко
        shouldUpdate = (updateCounter % 30 == 0); // ~2 раза в секунду
    }

    if (shouldUpdate) {
        updateGraphDataFromBuffer();
    }

    if (updateCounter >= 1000) updateCounter = 0;
}

void TiltController::testAngularSpeedFrequency()
{
    qDebug() << "Current angular speed frequency:" << m_angularSpeedUpdateFrequency;
    qDebug() << "LogReader frequency:" << m_logReader.getUpdateFrequency(); // если нужно добавить геттер
}

void TiltController::loadLogFile(const QString &filePath)
{
    QString fileName = filePath;

    // Обрабатываем разные форматы путей
    if (fileName.startsWith("file:///")) {
#ifdef Q_OS_WIN
        fileName = fileName.mid(8);
#else
        fileName = fileName.mid(7);
#endif
    }

    if (fileName.isEmpty()) {
        addNotification("Файл не выбран");
        return;
    }

    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        addNotification("Ошибка открытия файла: " + fileName);
        return;
    }

    // СОЗДАЕМ fileInfo ДО его использования
    QFileInfo fileInfo(fileName);

    m_logData.clear();
    m_currentLogIndex = 0;
    m_studyInfo.clear();
    m_dataBuffer.clear(); // Очищаем буфер
    m_loadedResearchNumber.clear(); // Сбрасываем номер загруженного исследования

    QTextStream in(&file);
    int lineNumber = 0;
    QStringList studyLines;

    // Создаем временный вектор для LogReader
    QVector<LogDataEntry> logReaderData;

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        lineNumber++;

        if (lineNumber <= 5 && line.startsWith('#')) {
            studyLines << line.mid(1).trimmed();
            continue;
        }

        if (line.isEmpty() || line.startsWith("##########")) {
            continue;
        }

        QStringList parts = line.split(';');
        if (parts.size() >= 6) {
            LogEntry entry;  // TiltController::LogEntry
            LogDataEntry readerEntry;  // LogReader::LogDataEntry
            bool ok1, ok2, ok3, ok4, ok5, ok6;

            entry.time = parts[0].toLongLong(&ok1);
            entry.pitch = parts[1].replace(',', '.').toFloat(&ok2);
            entry.roll = parts[2].replace(',', '.').toFloat(&ok3);
            entry.yaw = parts[3].replace(',', '.').toFloat(&ok4);

            // Заполняем данные для LogReader
            readerEntry.time = entry.time;
            readerEntry.pitch = entry.pitch;
            readerEntry.roll = entry.roll;
            readerEntry.yaw = entry.yaw;

            // Парсим головокружение пациента и врача
            if (parts.size() >= 6) {
                entry.dizziness = (parts[4].toInt(&ok5) == 1);
                entry.doctorDizziness = (parts[5].toInt(&ok6) == 1);

                readerEntry.dizziness = entry.dizziness;
                readerEntry.doctorDizziness = entry.doctorDizziness;
            }

            if (ok1 && ok2 && ok3 && ok4 && ok5) {
                // Вычисляем скорости (для совместимости)
                entry.speedPitch = 0.0f;
                entry.speedRoll = 0.0f;
                entry.speedYaw = 0.0f;

                m_logData.append(entry);
                logReaderData.append(readerEntry);
            } else {
                qDebug() << "Failed to parse line:" << line;
            }
        } else {
            qDebug() << "Invalid line format:" << line;
        }
    }

    file.close();

    if (!studyLines.isEmpty()) {
        m_studyInfo = studyLines.join(" | ");

        // ИЗВЛЕКАЕМ НОМЕР ИССЛЕДОВАНИЯ ИЗ ЗАГОЛОВКА
        m_loadedResearchNumber = extractResearchNumber(studyLines);
    } else {
        // ИСПОЛЬЗУЕМ fileInfo КОТОРЫЙ УЖЕ ОБЪЯВЛЕН ВЫШЕ
        m_studyInfo = "Исследование: " + fileInfo.fileName();
        m_loadedResearchNumber = "000000"; // значение по умолчанию
    }

    if (m_logData.isEmpty()) {
        addNotification("В файле нет корректных данных лога");
        m_logLoaded = false;
        emit logLoadedChanged(m_logLoaded);
        return;
    }

    m_logLoaded = true;
    m_logMode = true;
    m_totalTime = m_logData.last().time;
    m_currentTime = 0;
    m_currentLogIndex = 0;

    // Передаем данные в LogReader
    m_logReader.setData(logReaderData);

    if (m_connected) {
        disconnectDevice();
    }
    m_autoConnectTimer.stop();

    // После загрузки данных проверим временные метки
    if (!m_logData.isEmpty()) {
        qint64 minTime = m_logData.first().time;
        qint64 maxTime = m_logData.last().time;
        qint64 duration = maxTime - minTime;

        // Если длительность слишком мала или велика, скорректируем
        if (duration < 1000) {
            qDebug() << "Warning: Log file duration is very short";
        }
    }

    // УВЕДОМЛЯЕМ ОБ ИЗМЕНЕНИИ НОМЕРА ЗАГРУЖЕННОГО ИССЛЕДОВАНИЯ
    emit loadedResearchNumberChanged(m_loadedResearchNumber);

    addNotification("Лог-файл загружен: " + QString::number(m_logData.size()) + " записей");
    emit logLoadedChanged(m_logLoaded);
    emit logModeChanged(m_logMode);
    emit logControlsEnabledChanged(logControlsEnabled());
    emit studyInfoChanged(m_studyInfo);
    emit totalTimeChanged(m_totalTime);
    emit currentTimeChanged(m_currentTime);

    // ОБНОВЛЯЕМ ГРАФИКИ ПОСЛЕ ЗАГРУЗКИ
    updateGraphDataFromBuffer();

    // Обновляем угловые скорости с новой логикой
    updateAngularSpeeds();
}

void TiltController::seekLog(int time)
{
    if (!m_logLoaded || m_logData.isEmpty()) return;

    // Устанавливаем позицию ВО ВРЕМЕНИ ЛОГ-ФАЙЛА
    m_currentTime = qBound(0, time, m_totalTime);

    // Сбрасываем синхронизацию времени
    m_playbackTimeInitialized = false;

    // СБРАСЫВАЕМ ИСТОРИЮ ДЛЯ ПЕРЕСЧЕТА СКОРОСТЕЙ
    m_pitchHistory.clear();
    m_rollHistory.clear();
    m_yawHistory.clear();

    // ОБНОВЛЯЕМ ПОЗИЦИЮ ГРАФИКА
    m_graphDisplayTime = m_currentTime + 30000;

    // Находим соответствующий индекс
    for (int i = 0; i < m_logData.size(); ++i) {
        if (m_logData[i].time >= m_currentTime) {
            m_currentLogIndex = i;
            const LogEntry &entry = m_logData[i];

            // ОБНОВЛЯЕМ МОДЕЛЬ С НОВЫМИ СКОРОСТЯМИ
            updateAngularSpeeds();

            // ОБНОВЛЯЕМ СВОЙСТВА ГОЛОВОКРУЖЕНИЯ ДЛЯ 3D ВИДА
            if (m_patientDizziness != entry.dizziness) {
                m_patientDizziness = entry.dizziness;
                emit patientDizzinessChanged(m_patientDizziness);
            }

            if (m_doctorDizziness != entry.doctorDizziness) {
                m_doctorDizziness = entry.doctorDizziness;
                emit doctorDizzinessChanged(m_doctorDizziness);
            }
            break;
        }
    }

    // ОБНОВЛЯЕМ ГРАФИКИ НЕМЕДЛЕННО
    updateGraphDataFromBuffer();

    // ВАЖНО: ОБНОВЛЯЕМ ВРЕМЯ ДАЖЕ ПРИ ПАУЗЕ
    emit currentTimeChanged(m_currentTime);

    // Если воспроизведение активно, продолжаем с новой позиции
    if (m_logPlaying) {
        m_playbackTimeInitialized = false; // Переинициализируем синхронизацию
    }
}

void TiltController::stopLog()
{
    m_logPlaying = false;
    m_logTimer.stop();
    m_playbackTimeInitialized = false;

    // Сбрасываем позицию воспроизведения на начало
    m_currentTime = 0;
    m_currentLogIndex = 0;

    // СБРАСЫВАЕМ ИСТОРИЮ ДЛЯ ПЕРЕСЧЕТА СКОРОСТЕЙ
    m_pitchHistory.clear();
    m_rollHistory.clear();
    m_yawHistory.clear();

    // Сбрасываем график на начальную позицию (первые 30 секунд)
    m_graphDisplayTime = 30000;

    // СБРАСЫВАЕМ ГОЛОВОКРУЖЕНИЕ
    if (m_patientDizziness) {
        m_patientDizziness = false;
        emit patientDizzinessChanged(m_patientDizziness);
    }

    if (m_doctorDizziness) {
        m_doctorDizziness = false;
        emit doctorDizzinessChanged(m_doctorDizziness);
    }

    // Обновляем модель с новыми скоростями
    updateAngularSpeeds();

    // Обновляем графики для отображения начальной позиции
    updateGraphDataFromBuffer();

    // ВАЖНО: ФОРСИРУЕМ ОБНОВЛЕНИЕ ВРЕМЕНИ ПРИ ОСТАНОВКЕ
    emit currentTimeChanged(m_currentTime);

    emit logPlayingChanged(m_logPlaying);
    addNotification("Воспроизведение лога остановлено и сброшено в начало");
}

void TiltController::startResearchRecording(const QString &researchNumber)
{
    if (m_recording || !m_connected) {
        addNotification("Невозможно начать запись: нет подключения к COM-порту");
        return;
    }

    // Проверяем номер исследования
    if (researchNumber.length() != 6) {
        addNotification("Ошибка: номер исследования должен состоять из 6 цифр");
        return;
    }

    m_researchNumber = researchNumber;
    m_researchStartTime = QDateTime::currentDateTime();
    m_researchFrameCounter = 1;

    // ЗАПОМИНАЕМ ТЕКУЩЕЕ ВРЕМЯ ОТНОСИТЕЛЬНО НАЧАЛА ПОДКЛЮЧЕНИЯ КАК НАЧАЛО ЗАПИСИ
    if (m_dataBuffer.size() > 0) {
        // Берем время последнего кадра как точку отсчета
        m_researchRecordingStartTime = m_dataBuffer.last().timestamp;
    } else {
        // Если буфер пуст, используем текущее относительное время
        m_researchRecordingStartTime = QDateTime::currentMSecsSinceEpoch() - m_startTime;
    }

    QString fileName = generateResearchFileName(researchNumber);
    m_researchFile = new QFile(fileName);

    if (!m_researchFile->open(QIODevice::WriteOnly | QIODevice::Text)) {
        addNotification("Ошибка создания файла исследования: " + fileName);
        delete m_researchFile;
        m_researchFile = nullptr;
        return;
    }

    m_researchStream = new QTextStream(m_researchFile);

    writeResearchHeader();

    m_recording = true;
    emit recordingChanged(m_recording);

    addNotification("Начата запись исследования: " + researchNumber);
}

void TiltController::stopResearchRecording()
{
    if (!m_recording) {
        return;
    }

    if (m_researchStream) {
        m_researchStream->flush();
        delete m_researchStream;
        m_researchStream = nullptr;
    }

    if (m_researchFile) {
        m_researchFile->close();
        delete m_researchFile;
        m_researchFile = nullptr;
    }

    m_recording = false;
    m_researchRecordingStartTime = 0;  // Сбрасываем время начала записи
    emit recordingChanged(m_recording);

    // Обновляем номер исследования
    int nextNumber = m_researchNumber.toInt() + 1;
    m_researchNumber = QString::number(nextNumber).rightJustified(6, '0');
    emit researchNumberChanged(m_researchNumber);

    addNotification("Запись исследования остановлена. Следующий номер: " + m_researchNumber);
}

float TiltController::calculateAngularSpeed(QVector<AngleHistory>& history, float currentAngle, qint64 currentTime)
{
    // Добавляем текущее значение в историю
    history.append(AngleHistory(currentTime, currentAngle));

    // Ограничиваем размер истории
    while (history.size() > m_speedCalculationPoints) {
        history.removeFirst();
    }

    // Если недостаточно точек для расчета, возвращаем 0
    if (history.size() < 2) {
        return 0.0f;
    }

    // Берем первую и последнюю точку в истории
    const AngleHistory& firstPoint = history.first();
    const AngleHistory& lastPoint = history.last();

    // Вычисляем общее изменение угла с учетом переходов через 180/-180
    float totalAngleChange = lastPoint.angle - firstPoint.angle;

    // Корректируем переходы через 180/-180
    if (totalAngleChange > 180.0f) {
        totalAngleChange -= 360.0f;
    } else if (totalAngleChange < -180.0f) {
        totalAngleChange += 360.0f;
    }

    // Вычисляем временное окно в миллисекундах
    qint64 timeWindow = lastPoint.timestamp - firstPoint.timestamp;

    // Если временное окно слишком мало, возвращаем 0 (избегаем деления на 0)
    if (timeWindow < 10) { // Минимум 10 мс для расчета
        return 0.0f;
    }

    // Вычисляем угловую скорость в градусах/секунду
    // Формула: (изменение угла в градусах) * (1000 мс / время в мс)
    float angularSpeed = (totalAngleChange * 1000.0f) / timeWindow;

    // Ограничиваем максимальную скорость (для устранения выбросов)
    const float maxSpeed = 720.0f; // градусов/секунду
    if (angularSpeed > maxSpeed) angularSpeed = maxSpeed;
    if (angularSpeed < -maxSpeed) angularSpeed = -maxSpeed;

    return angularSpeed;
}

// Модифицируем updateLogPlayback:
void TiltController::updateLogPlayback()
{
    if (m_currentLogIndex >= m_logData.size()) {
        stopLog();
        return;
    }

    // Инициализация времени при первом вызове
    if (!m_playbackTimeInitialized) {
        m_playbackStartRealTime = QDateTime::currentMSecsSinceEpoch();
        m_playbackStartLogTime = m_currentTime;
        m_playbackTimeInitialized = true;
    }

    // Вычисляем, сколько реального времени прошло с начала воспроизведения
    qint64 currentRealTime = QDateTime::currentMSecsSinceEpoch();
    qint64 realTimeElapsed = currentRealTime - m_playbackStartRealTime;

    // Целевое время в логе = начальное время + прошедшее реальное время
    qint64 targetLogTime = m_playbackStartLogTime + realTimeElapsed;

    // Находим индекс, соответствующий целевому времени
    int targetIndex = m_currentLogIndex;
    while (targetIndex < m_logData.size() && m_logData[targetIndex].time <= targetLogTime) {
        targetIndex++;
    }

    // Если нашли кадры для воспроизведения
    if (targetIndex > m_currentLogIndex) {
        // Воспроизводим последний найденный кадр
        const LogEntry &entry = m_logData[targetIndex - 1];

        // ВЫЧИСЛЯЕМ УГЛОВЫЕ СКОРОСТИ С НОВОЙ ЛОГИКОЙ
        float speedPitch = m_logReader.calculateAngularSpeed(entry.time, "pitch", true);
        float speedRoll = m_logReader.calculateAngularSpeed(entry.time, "roll", true);
        float speedYaw = m_logReader.calculateAngularSpeed(entry.time, "yaw", true);

        updateHeadModel(entry.pitch, entry.roll, entry.yaw,
                        speedPitch, speedRoll, speedYaw,
                        entry.dizziness || entry.doctorDizziness);

        m_currentTime = entry.time;
        m_currentLogIndex = targetIndex;

        // ОБНОВЛЯЕМ СВОЙСТВА ГОЛОВОКРУЖЕНИЯ ДЛЯ 3D ВИДА
        if (m_patientDizziness != entry.dizziness) {
            m_patientDizziness = entry.dizziness;
            emit patientDizzinessChanged(m_patientDizziness);
        }

        if (m_doctorDizziness != entry.doctorDizziness) {
            m_doctorDizziness = entry.doctorDizziness;
            emit doctorDizzinessChanged(m_doctorDizziness);
        }

        // ОБНОВЛЯЕМ ПОЗИЦИЮ ГРАФИКА для отображения текущего момента
        m_graphDisplayTime = m_currentTime + 30000;

        emit currentTimeChanged(m_currentTime);
    }

    // Обновляем графики с фиксированной частотой
    static qint64 lastGraphUpdate = 0;
    if (currentRealTime - lastGraphUpdate >= 33) { // ~30 FPS для графиков
        updateGraphDataFromBuffer();
        lastGraphUpdate = currentRealTime;
    }

    // Если достигли конца лога, останавливаем воспроизведение
    if (m_currentLogIndex >= m_logData.size()) {
        stopLog();
    }
}

void TiltController::updateGraphDataFromBuffer()
{
    if (m_logMode) {
        // РЕЖИМ ЛОГ-ФАЙЛА: используем отдельную логику
        updateGraphDataFromLogFile();
    } else {
        // РЕЖИМ COM-ПОРТА: используем восстановленную рабочую логику
        updateGraphDataFromCOMPort();
    }

    // Всегда эмитируем сигнал после обновления данных
    emit graphDataChanged();
}

void TiltController::updateGraphDataFromCOMPort()
{
    if (m_dataBuffer.isEmpty()) {
        return;
    }

    const qint64 DISPLAY_DURATION_MS = m_graphDuration * 1000;
    QVariantList newPitchData, newRollData, newYawData, newDizzinessPatientData, newDizzinessDoctorData;

    qint64 currentAbsoluteTime = QDateTime::currentMSecsSinceEpoch();
    qint64 displayStartTime = currentAbsoluteTime - DISPLAY_DURATION_MS;

    // Собираем данные для отображения
    QVector<DataFrame> displayData;
    for (int i = 0; i < m_dataBuffer.size(); i++) {
        DataFrame frame = m_dataBuffer.at(i);
        qint64 frameAbsoluteTime = m_startTime + frame.timestamp;
        if (frameAbsoluteTime >= displayStartTime) {
            displayData.append(frame);
        }
    }

    if (!displayData.isEmpty()) {
        // Прореживание данных для оптимизации
        QVector<DataFrame> filteredData = displayData;
        if (displayData.size() > 250) {
            filteredData.clear();
            int step = displayData.size() / 200;
            for (int i = 0; i < displayData.size(); i += step) {
                filteredData.append(displayData[i]);
                if (filteredData.size() >= 250) break;
            }

            if (!displayData.isEmpty() &&
                (filteredData.isEmpty() || filteredData.last().timestamp != displayData.last().timestamp)) {
                filteredData.append(displayData.last());
            }
        }

        // Формируем данные для графиков
        for (const DataFrame& frame : filteredData) {
            qint64 frameAbsoluteTime = m_startTime + frame.timestamp;
            qint64 relativeTime = frameAbsoluteTime - displayStartTime;
            relativeTime = qBound(0LL, relativeTime, DISPLAY_DURATION_MS);

            QVariantMap pitchPoint, rollPoint, yawPoint;
            pitchPoint["time"] = relativeTime;
            pitchPoint["value"] = frame.pitch;
            newPitchData.append(pitchPoint);

            rollPoint["time"] = relativeTime;
            rollPoint["value"] = frame.roll;
            newRollData.append(rollPoint);

            yawPoint["time"] = relativeTime;
            yawPoint["value"] = frame.yaw;
            newYawData.append(yawPoint);
        }

        // Формируем интервалы головокружения для COM-порта
        bool inPatientDizziness = false;
        bool inDoctorDizziness = false;
        qint64 patientStart = 0;
        qint64 doctorStart = 0;

        for (const DataFrame& frame : displayData) {
            qint64 frameAbsoluteTime = m_startTime + frame.timestamp;
            qint64 relativeTime = frameAbsoluteTime - displayStartTime;
            if (relativeTime < 0) continue;

            // Обработка головокружения пациента
            if (frame.patientDizziness && !inPatientDizziness) {
                inPatientDizziness = true;
                patientStart = relativeTime;
            } else if (!frame.patientDizziness && inPatientDizziness) {
                inPatientDizziness = false;
                if (patientStart < relativeTime) {
                    QVariantMap interval;
                    interval["startTime"] = patientStart;
                    interval["endTime"] = relativeTime;
                    newDizzinessPatientData.append(interval);
                }
            }

            // Обработка головокружения врача
            if (frame.doctorDizziness && !inDoctorDizziness) {
                inDoctorDizziness = true;
                doctorStart = relativeTime;
            } else if (!frame.doctorDizziness && inDoctorDizziness) {
                inDoctorDizziness = false;
                if (doctorStart < relativeTime) {
                    QVariantMap interval;
                    interval["startTime"] = doctorStart;
                    interval["endTime"] = relativeTime;
                    newDizzinessDoctorData.append(interval);
                }
            }
        }

        // Завершаем активные интервалы
        if (inPatientDizziness && patientStart < DISPLAY_DURATION_MS) {
            QVariantMap interval;
            interval["startTime"] = patientStart;
            interval["endTime"] = DISPLAY_DURATION_MS;
            newDizzinessPatientData.append(interval);
        }

        if (inDoctorDizziness && doctorStart < DISPLAY_DURATION_MS) {
            QVariantMap interval;
            interval["startTime"] = doctorStart;
            interval["endTime"] = DISPLAY_DURATION_MS;
            newDizzinessDoctorData.append(interval);
        }
    }

    // ОБНОВЛЯЕМ ДАННЫЕ В КЛАССЕ - ЭТО ОБЯЗАТЕЛЬНО!
    m_pitchGraphData = newPitchData;
    m_rollGraphData = newRollData;
    m_yawGraphData = newYawData;
    m_dizzinessPatientData = newDizzinessPatientData;
    m_dizzinessDoctorData = newDizzinessDoctorData;

    if (!m_headModel.hasData() && (!newPitchData.isEmpty() || !newRollData.isEmpty() || !newYawData.isEmpty())) {
        m_headModel.setHasData(true);
    }
}

void TiltController::updateGraphDataFromLogFile()
{
    if (!m_logLoaded || m_logData.isEmpty()) {
        return;
    }

    const qint64 DISPLAY_DURATION_MS = m_graphDuration * 1000;
    const qint64 TIME_OFFSET = 30000;
    QVariantList newPitchData, newRollData, newYawData, newDizzinessPatientData, newDizzinessDoctorData;

    // Всегда используем m_graphDisplayTime для определения позиции графика
    qint64 displayEndTime = m_graphDisplayTime;
    qint64 displayStartTime = displayEndTime - DISPLAY_DURATION_MS;

    // Находим диапазон данных для отображения (в оригинальном времени файла)
    int startIndex = findLogIndexByTime(qMax(0LL, displayStartTime - TIME_OFFSET));
    int endIndex = findLogIndexByTime(displayEndTime - TIME_OFFSET);

    if (startIndex == -1) startIndex = 0;
    if (endIndex == -1) endIndex = m_logData.size() - 1;

    startIndex = qMax(0, startIndex);
    endIndex = qMin(m_logData.size() - 1, endIndex);

    // СОБИРАЕМ ДАННЫЕ С РАВНОМЕРНЫМ ПРОРЕЖИВАНИЕМ ПО ВРЕМЕНИ
    QVector<DataFrame> displayData;

    if (endIndex >= startIndex) {
        int totalPoints = endIndex - startIndex + 1;

        if (totalPoints <= 250) {
            // Если точек мало, берем все
            for (int i = startIndex; i <= endIndex; i++) {
                const LogEntry &entry = m_logData[i];
                DataFrame frame;
                frame.timestamp = entry.time + TIME_OFFSET;
                frame.pitch = entry.pitch;
                frame.roll = entry.roll;
                frame.yaw = entry.yaw;
                frame.patientDizziness = entry.dizziness;
                frame.doctorDizziness = entry.doctorDizziness;
                displayData.append(frame);
            }
        } else {
            // Равномерное прореживание по времени
            qint64 startTime = m_logData[startIndex].time + TIME_OFFSET;
            qint64 endTime = m_logData[endIndex].time + TIME_OFFSET;
            qint64 timeRange = endTime - startTime;

            // Целевое количество точек после прореживания
            const int targetPointCount = 200;
            qint64 timeStep = timeRange / (targetPointCount - 1);

            // Добавляем первую точку
            const LogEntry &firstEntry = m_logData[startIndex];
            DataFrame firstFrame;
            firstFrame.timestamp = firstEntry.time + TIME_OFFSET;
            firstFrame.pitch = firstEntry.pitch;
            firstFrame.roll = firstEntry.roll;
            firstFrame.yaw = firstEntry.yaw;
            firstFrame.patientDizziness = firstEntry.dizziness;
            firstFrame.doctorDizziness = firstEntry.doctorDizziness;
            displayData.append(firstFrame);

            // Для каждого целевого времени находим ближайшую точку
            for (int i = 1; i < targetPointCount - 1; i++) {
                qint64 targetTime = startTime + i * timeStep;

                // Ищем ближайшую точку к целевому времени
                int bestIndex = startIndex;
                qint64 minTimeDiff = std::abs((m_logData[startIndex].time + TIME_OFFSET) - targetTime);

                for (int j = startIndex + 1; j <= endIndex; j++) {
                    qint64 currentTime = m_logData[j].time + TIME_OFFSET;
                    qint64 timeDiff = std::abs(currentTime - targetTime);

                    if (timeDiff < minTimeDiff) {
                        minTimeDiff = timeDiff;
                        bestIndex = j;
                    }

                    // Если начали удаляться от целевого времени, выходим
                    if (currentTime > targetTime + timeStep / 2) {
                        break;
                    }
                }

                // Добавляем точку, если она отличается от предыдущей
                const LogEntry &entry = m_logData[bestIndex];
                DataFrame frame;
                frame.timestamp = entry.time + TIME_OFFSET;
                frame.pitch = entry.pitch;
                frame.roll = entry.roll;
                frame.yaw = entry.yaw;
                frame.patientDizziness = entry.dizziness;
                frame.doctorDizziness = entry.doctorDizziness;

                if (displayData.isEmpty() ||
                    displayData.last().timestamp != frame.timestamp) {
                    displayData.append(frame);
                }
            }

            // Добавляем последнюю точку
            const LogEntry &lastEntry = m_logData[endIndex];
            DataFrame lastFrame;
            lastFrame.timestamp = lastEntry.time + TIME_OFFSET;
            lastFrame.pitch = lastEntry.pitch;
            lastFrame.roll = lastEntry.roll;
            lastFrame.yaw = lastEntry.yaw;
            lastFrame.patientDizziness = lastEntry.dizziness;
            lastFrame.doctorDizziness = lastEntry.doctorDizziness;

            if (displayData.isEmpty() ||
                displayData.last().timestamp != lastFrame.timestamp) {
                displayData.append(lastFrame);
            }
        }
    }

    // Формируем данные для графиков
    if (!displayData.isEmpty()) {
        // СОРТИРУЕМ данные по времени (от старых к новым)
        std::sort(displayData.begin(), displayData.end(),
                  [](const DataFrame& a, const DataFrame& b) {
                      return a.timestamp < b.timestamp;
                  });

        // Формируем данные для графиков
        for (const DataFrame& frame : displayData) {
            // Вычитаем displayStartTime, чтобы время начиналось с 0
            qint64 relativeTime = frame.timestamp - displayStartTime;
            relativeTime = qBound(0LL, relativeTime, DISPLAY_DURATION_MS);

            QVariantMap pitchPoint, rollPoint, yawPoint;
            pitchPoint["time"] = relativeTime;
            pitchPoint["value"] = frame.pitch;
            newPitchData.append(pitchPoint);

            rollPoint["time"] = relativeTime;
            rollPoint["value"] = frame.roll;
            newRollData.append(rollPoint);

            yawPoint["time"] = relativeTime;
            yawPoint["value"] = frame.yaw;
            newYawData.append(yawPoint);
        }

        // Формируем интервалы головокружения на основе ВСЕХ данных в диапазоне, а не прореженных
        bool inPatientDizziness = false;
        bool inDoctorDizziness = false;
        qint64 patientStartTime = 0;
        qint64 doctorStartTime = 0;

        // Используем все данные из диапазона для точного определения интервалов
        for (int i = startIndex; i <= endIndex; i++) {
            const LogEntry &entry = m_logData[i];

            // Рассчитываем время относительно начала отображаемого окна
            qint64 frameTime = entry.time + TIME_OFFSET;
            qint64 relativeTime = frameTime - displayStartTime;
            relativeTime = qBound(0LL, relativeTime, DISPLAY_DURATION_MS);

            // Обработка головокружения пациента
            if (entry.dizziness && !inPatientDizziness) {
                inPatientDizziness = true;
                patientStartTime = relativeTime;
            } else if (!entry.dizziness && inPatientDizziness) {
                inPatientDizziness = false;
                qint64 patientEndTime = relativeTime;

                // Добавляем интервал только если он имеет положительную длительность
                if (patientStartTime < patientEndTime) {
                    QVariantMap interval;
                    interval["startTime"] = patientStartTime;
                    interval["endTime"] = patientEndTime;
                    newDizzinessPatientData.append(interval);
                }
            }

            // Обработка головокружения врача
            if (entry.doctorDizziness && !inDoctorDizziness) {
                inDoctorDizziness = true;
                doctorStartTime = relativeTime;
            } else if (!entry.doctorDizziness && inDoctorDizziness) {
                inDoctorDizziness = false;
                qint64 doctorEndTime = relativeTime;

                // Добавляем интервал только если он имеет положительную длительность
                if (doctorStartTime < doctorEndTime) {
                    QVariantMap interval;
                    interval["startTime"] = doctorStartTime;
                    interval["endTime"] = doctorEndTime;
                    newDizzinessDoctorData.append(interval);
                }
            }
        }

        // Завершаем активные интервалы на границе окна отображения
        if (inPatientDizziness && patientStartTime < DISPLAY_DURATION_MS) {
            QVariantMap interval;
            interval["startTime"] = patientStartTime;
            interval["endTime"] = DISPLAY_DURATION_MS;
            newDizzinessPatientData.append(interval);
        }

        if (inDoctorDizziness && doctorStartTime < DISPLAY_DURATION_MS) {
            QVariantMap interval;
            interval["startTime"] = doctorStartTime;
            interval["endTime"] = DISPLAY_DURATION_MS;
            newDizzinessDoctorData.append(interval);
        }
    }

    // Обновляем данные
    m_pitchGraphData = newPitchData;
    m_rollGraphData = newRollData;
    m_yawGraphData = newYawData;
    m_dizzinessPatientData = newDizzinessPatientData;
    m_dizzinessDoctorData = newDizzinessDoctorData;
}

// Вспомогательная функция для бинарного поиска индекса по времени
int TiltController::findLogIndexByTime(qint64 targetTime)
{
    if (m_logData.isEmpty()) return -1;

    // Используем бинарный поиск для эффективности
    int left = 0;
    int right = m_logData.size() - 1;
    int result = -1;

    while (left <= right) {
        int mid = left + (right - left) / 2;
        qint64 midTime = m_logData[mid].time;

        if (midTime == targetTime) {
            return mid;
        } else if (midTime < targetTime) {
            result = mid; // Запоминаем последний подходящий индекс
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    // Возвращаем ближайший индекс, не превышающий targetTime
    return result;
}

void TiltController::updateCOMAngularSpeeds()
{
    if (!m_connected || m_logMode) return;

    // Проверяем, что у нас достаточно данных для расчета
    // Теперь достаточно хотя бы 2 точек в каждом буфере
    bool hasEnoughData = (m_comPitchBuffer.size() >= 2) &&
                         (m_comRollBuffer.size() >= 2) &&
                         (m_comYawBuffer.size() >= 2);  // ИСПРАВЛЕНО: было m_yawBuffer

    if (!hasEnoughData) {
        // Если данных недостаточно, используем простой расчет по последним 2 точкам
        // или устанавливаем нулевые скорости
        if (m_dataBuffer.size() >= 2) {
            // Берем последние 2 кадра из основного буфера
            DataFrame currentFrame = m_dataBuffer.last();
            DataFrame prevFrame = m_dataBuffer.at(m_dataBuffer.size() - 2);

            qint64 timeDiff = currentFrame.timestamp - prevFrame.timestamp;

            if (timeDiff > 0) {
                m_currentComSpeedPitch = (currentFrame.pitch - prevFrame.pitch) * 1000.0f / timeDiff;
                m_currentComSpeedRoll = (currentFrame.roll - prevFrame.roll) * 1000.0f / timeDiff;
                m_currentComSpeedYaw = (currentFrame.yaw - prevFrame.yaw) * 1000.0f / timeDiff;

                // Ограничиваем скорости
                const float maxSpeed = 360.0f;
                m_currentComSpeedPitch = qBound(-maxSpeed, m_currentComSpeedPitch, maxSpeed);
                m_currentComSpeedRoll = qBound(-maxSpeed, m_currentComSpeedRoll, maxSpeed);
                m_currentComSpeedYaw = qBound(-maxSpeed, m_currentComSpeedYaw, maxSpeed);
            }
        } else {
            // Если вообще нет данных, устанавливаем нули
            m_currentComSpeedPitch = 0.0f;
            m_currentComSpeedRoll = 0.0f;
            m_currentComSpeedYaw = 0.0f;
        }
    } else {
        // Нормальный расчет с использованием буферов
        m_currentComSpeedPitch = calculateCOMAngularSpeed(m_comPitchBuffer);
        m_currentComSpeedRoll = calculateCOMAngularSpeed(m_comRollBuffer);
        m_currentComSpeedYaw = calculateCOMAngularSpeed(m_comYawBuffer);
    }

    // Обновляем модель с вычисленными скоростями
    if (m_dataBuffer.size() > 0) {
        const DataFrame& lastFrame = m_dataBuffer.last();
        updateHeadModel(lastFrame.pitch, lastFrame.roll, lastFrame.yaw,
                        m_currentComSpeedPitch, m_currentComSpeedRoll, m_currentComSpeedYaw,
                        lastFrame.patientDizziness || lastFrame.doctorDizziness);
    }

    // Очищаем буферы только если они стали слишком большими
    const int maxBufferSize = 100;
    if (m_comPitchBuffer.size() > maxBufferSize) {
        m_comPitchBuffer.remove(0, m_comPitchBuffer.size() - maxBufferSize / 2);
    }
    if (m_comRollBuffer.size() > maxBufferSize) {
        m_comRollBuffer.remove(0, m_comRollBuffer.size() - maxBufferSize / 2);
    }
    if (m_comYawBuffer.size() > maxBufferSize) {
        m_comYawBuffer.remove(0, m_comYawBuffer.size() - maxBufferSize / 2);
    }
}

float TiltController::calculateCOMAngularSpeed(QVector<AngleDataPoint>& dataBuffer)
{
    if (dataBuffer.size() < 2) {
        return 0.0f;
    }

    // Берем первое и последнее значение в буфере
    const AngleDataPoint& firstPoint = dataBuffer.first();
    const AngleDataPoint& lastPoint = dataBuffer.last();

    // Вычисляем изменение угла
    float angleChange = lastPoint.angle - firstPoint.angle;

    // Корректируем переход через ±180 градусов
    if (angleChange > 180.0f) {
        angleChange -= 360.0f;
    } else if (angleChange < -180.0f) {
        angleChange += 360.0f;
    }

    // Вычисляем временной интервал в секундах
    float timeDiff = (lastPoint.timestamp - firstPoint.timestamp) / 1000.0f;

    if (timeDiff <= 0) {
        return 0.0f;
    }

    // Вычисляем угловую скорость (градусы/секунду)
    float angularSpeed = angleChange / timeDiff;

    // Ограничиваем разумными пределами
    const float maxSpeed = 360.0f;
    return qBound(-maxSpeed, angularSpeed, maxSpeed);
}

void TiltController::clearCOMBuffers()
{
    m_comPitchBuffer.clear();
    m_comRollBuffer.clear();
    m_comYawBuffer.clear();
}

void TiltController::setAngularSpeedUpdateFrequency(float frequency)
{
    frequency = qBound(0.1f, frequency, 10.0f);

    if (!qFuzzyCompare(m_angularSpeedUpdateFrequency, frequency)) {

        m_angularSpeedUpdateFrequency = frequency;
        m_logReader.setUpdateFrequency(frequency);

        // Обновляем интервал таймера для COM-порта
        m_comSpeedUpdateTimer.setInterval(1000 / frequency);

        // Пересчитываем скорости в зависимости от режима
        if (m_logMode && m_logLoaded) {
            updateAngularSpeeds();
        } else if (m_connected) {
            if (m_comSpeedUpdateTimer.isActive()) {
                m_comSpeedUpdateTimer.stop();
            }
            m_comSpeedUpdateTimer.start();
            clearCOMBuffers();
        }

        emit angularSpeedUpdateFrequencyChanged(frequency);
    }
}

void TiltController::processDataFrame(const DataFrame& frame)
{
    // Добавляем данные в буферы для расчета скоростей COM-порта
    if (m_connected && !m_logMode) {
        m_comPitchBuffer.append(AngleDataPoint(frame.timestamp, frame.pitch));
        m_comRollBuffer.append(AngleDataPoint(frame.timestamp, frame.roll));
        m_comYawBuffer.append(AngleDataPoint(frame.timestamp, frame.yaw));

        // Запускаем таймер, если он еще не запущен (дополнительная защита)
        if (!m_comSpeedUpdateTimer.isActive()) {
            m_comSpeedUpdateTimer.start();
        }

        // Если буферы пусты, инициируем немедленный расчет скоростей
        if (m_comPitchBuffer.size() == 1 && m_comRollBuffer.size() == 1 && m_comYawBuffer.size() == 1) {
            // Запускаем однократное обновление через короткий интервал
            QTimer::singleShot(100, this, &TiltController::updateCOMAngularSpeeds);
        }
    }

    if (m_prevFrame.timestamp > 0) {
        qint64 timeDiff = frame.timestamp - m_prevFrame.timestamp;
        if (timeDiff > 0) {
            // Старый расчет скоростей (оставляем для обратной совместимости)
            float speedPitch = (frame.pitch - m_prevFrame.pitch) * 1000.0f / timeDiff;
            float speedRoll = (frame.roll - m_prevFrame.roll) * 1000.0f / timeDiff;
            float speedYaw = (frame.yaw - m_prevFrame.yaw) * 1000.0f / timeDiff;

            // Ограничиваем максимальную скорость
            const float maxSpeed = 180.0f;
            speedPitch = qBound(-maxSpeed, speedPitch, maxSpeed);
            speedRoll = qBound(-maxSpeed, speedRoll, maxSpeed);
            speedYaw = qBound(-maxSpeed, speedYaw, maxSpeed);

            // В режиме COM-порта используем усредненные скорости
            if (m_connected && !m_logMode) {
                speedPitch = m_currentComSpeedPitch;
                speedRoll = m_currentComSpeedRoll;
                speedYaw = m_currentComSpeedYaw;
            }

            m_prevFrame = frame;

            // Обновляем свойства головокружения
            if (m_patientDizziness != frame.patientDizziness) {
                m_patientDizziness = frame.patientDizziness;
                emit patientDizzinessChanged(m_patientDizziness);
            }

            if (m_doctorDizziness != frame.doctorDizziness) {
                m_doctorDizziness = frame.doctorDizziness;
                emit doctorDizzinessChanged(m_doctorDizziness);
            }

            // Обновляем модель
            bool combinedDizziness = frame.patientDizziness || frame.doctorDizziness;
            updateHeadModel(frame.pitch, frame.roll, frame.yaw, speedPitch, speedRoll, speedYaw, combinedDizziness);

            // Устанавливаем флаг hasData
            if (!m_headModel.hasData()) {
                m_headModel.setHasData(true);
            }

            // Запись в файл исследования
            if (m_recording && m_researchStream) {
                qint64 researchTime = frame.timestamp - m_researchRecordingStartTime;
                if (researchTime < 0) {
                    researchTime = 0;
                }

                QString timestamp = QString::number(researchTime).rightJustified(10, '0');
                QString formattedLine = QString("%1;%2;%3;%4;%5;%6")
                                            .arg(timestamp)
                                            .arg(frame.pitch, 0, 'f', 2)
                                            .arg(frame.roll, 0, 'f', 2)
                                            .arg(frame.yaw, 0, 'f', 2)
                                            .arg(frame.patientDizziness ? 1 : 0)
                                            .arg(frame.doctorDizziness ? 1 : 0);

                *m_researchStream << formattedLine << "\n";
                m_researchStream->flush();
                m_researchFrameCounter++;
            }
        }
    } else {
        m_prevFrame = frame;
    }
}

bool TiltController::setupCOMPort()
{
    if (m_serialPort) {
        cleanupCOMPort();
    }

    // Очищаем буферы COM-порта
    clearCOMBuffers();
    m_currentComSpeedPitch = 0.0f;
    m_currentComSpeedRoll = 0.0f;
    m_currentComSpeedYaw = 0.0f;

    // ОПТИМИЗАЦИЯ: Полная очистка при новом подключении
    m_dataBuffer.clear();
    m_prevFrame = DataFrame();
    m_incompleteData.clear();

    // ОПТИМИЗАЦИЯ: Сбрасываем временные метки
    m_startTime = QDateTime::currentMSecsSinceEpoch();
    m_lastDataTime = 0;

    // ОПТИМИЗАЦИЯ: Сбрасываем кэши графиков
    m_lastPitchData.clear();
    m_lastRollData.clear();
    m_lastYawData.clear();
    m_updateCounter = 0;

    m_serialPort = new QSerialPort(this);
    m_serialPort->setPortName(m_selectedPort);
    m_serialPort->setBaudRate(QSerialPort::Baud115200);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    // ОПТИМИЗАЦИЯ: Настраиваем размеры буферов
    m_serialPort->setReadBufferSize(2048);

    connect(m_serialPort, &QSerialPort::readyRead, this, &TiltController::readCOMPortData, Qt::QueuedConnection);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &TiltController::handleCOMPortError, Qt::QueuedConnection);

    try {
        if (m_serialPort->open(QIODevice::ReadOnly)) {
            m_connected = true;
            m_autoConnectTimer.stop();
            m_safetyTimer.start();

            if (m_logMode) {
                stopLog();
                m_logMode = false;
                emit logModeChanged(m_logMode);
                emit logControlsEnabledChanged(logControlsEnabled());
            }

            m_incompleteData.clear();
            m_dataBuffer.clear();
            m_prevFrame = DataFrame();

            // ДОБАВЛЯЕМ ЗАПУСК ТАЙМЕРА ДЛЯ COM-СКОРОСТЕЙ
            if (!m_comSpeedUpdateTimer.isActive()) {
                m_comSpeedUpdateTimer.start();
            }

            addNotification("Успешное подключение к " + m_selectedPort);
            emit connectedChanged(m_connected);
            return true;
        } else {
            addNotification("Ошибка подключения к " + m_selectedPort + ": " + m_serialPort->errorString());
            cleanupCOMPort();
            return false;
        }
    } catch (const std::exception& e) {
        addNotification("Исключение при подключении к COM-порту: " + QString(e.what()));
        cleanupCOMPort();
        return false;
    }
}

void TiltController::cleanupCOMPort()
{
    m_safetyTimer.stop();

    // Останавливаем таймер COM-порта
    if (m_comSpeedUpdateTimer.isActive()) {
        m_comSpeedUpdateTimer.stop();
    }

    if (m_serialPort) {
        disconnect(m_serialPort, nullptr, this, nullptr);

        if (m_serialPort->isOpen()) {
            try {
                m_serialPort->close();
            } catch (const std::exception& e) {
                qDebug() << "Exception while closing port:" << e.what();
            }
        }

        m_serialPort->deleteLater();
        m_serialPort = nullptr;
    }

    // ДОПОЛНИТЕЛЬНАЯ ОЧИСТКА ДАННЫХ
    m_incompleteData.clear();
}

void TiltController::setAngularSpeedUpdateFrequencyCOM(float frequency)
{
    // Обновляем диапазон для COM-порта: 1-15 Гц
    frequency = qBound(1.0f, frequency, 15.0f);

    if (!qFuzzyCompare(m_angularSpeedUpdateFrequencyCOM, frequency)) {

        m_angularSpeedUpdateFrequencyCOM = frequency;

        // Обновляем интервал таймера для COM-порта
        m_comSpeedUpdateTimer.setInterval(1000 / frequency);

        // Пересчитываем скорости для COM-порта
        if (m_connected && !m_logMode) {
            if (m_comSpeedUpdateTimer.isActive()) {
                m_comSpeedUpdateTimer.stop();
            }
            m_comSpeedUpdateTimer.start();

            // Немедленно обновляем скорости при изменении частоты
            QTimer::singleShot(50, this, &TiltController::updateCOMAngularSpeeds);
        }

        emit angularSpeedUpdateFrequencyCOMChanged(frequency);
    }
}

void TiltController::setAngularSpeedUpdateFrequencyLog(float frequency)
{
    // Обновляем диапазон для лог-файла: 0.8-1.5 Гц
    frequency = qBound(0.8f, frequency, 1.5f);

    if (!qFuzzyCompare(m_angularSpeedUpdateFrequencyLog, frequency)) {

        m_angularSpeedUpdateFrequencyLog = frequency;
        m_logReader.setUpdateFrequency(frequency);

        // Пересчитываем скорости для лог-файла
        if (m_logMode && m_logLoaded) {
            updateAngularSpeeds();
        }

        emit angularSpeedUpdateFrequencyLogChanged(frequency);
    }
}

QString TiltController::extractResearchNumber(const QStringList &studyLines)
{
    for (const QString &line : studyLines) {
        // Ищем паттерн "Исследование № XXXXXX"
        QRegularExpression re("Исследование №\\s*(\\d{6})");
        QRegularExpressionMatch match = re.match(line);

        if (match.hasMatch()) {
            return match.captured(1);
        }

        // Альтернативный поиск по другим паттернам
        QRegularExpression re2("Research_(\\d{6})_");
        QRegularExpressionMatch match2 = re2.match(line);

        if (match2.hasMatch()) {
            return match2.captured(1);
        }
    }

    return "000000"; // значение по умолчанию, если не нашли
}
