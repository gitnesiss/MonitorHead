#include "tiltcontroller.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QtMath>
#include <QDateTime>
#include <QCoreApplication>

TiltController::TiltController(QObject *parent) : QObject(parent)
{
    m_logTimer.setInterval(16); // ~60 FPS
    connect(&m_logTimer, &QTimer::timeout, this, &TiltController::updateLogPlayback);

    m_autoConnectTimer.setInterval(2000); // Попытка авто-подключения каждые 2 секунды
    connect(&m_autoConnectTimer, &QTimer::timeout, this, &TiltController::autoConnect);

    // Таймер безопасности для проверки состояния порта
    m_safetyTimer.setInterval(1000);
    connect(&m_safetyTimer, &QTimer::timeout, this, [this]() {
        if (m_serialPort && m_serialPort->isOpen()) {
            // Проверяем, жив ли еще порт
            if (m_serialPort->error() == QSerialPort::ResourceError) {
                qDebug() << "Safety timer detected port error, cleaning up...";
                safeDisconnect();
            }
        }
    });

    // Сбрасываем данные при старте
    m_headModel.resetData();

    refreshPorts();

    // Запускаем авто-подключение
    m_autoConnectTimer.start();
    addNotification("Программа запущена. Попытка автоматического подключения к COM-порту...");
}

TiltController::~TiltController()
{
    m_isCleaningUp = true;
    cleanupCOMPort();
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
    cleanupCOMPort();
    m_connected = false;

    // Если не в режиме лога, сбрасываем данные
    if (!m_logMode) {
        m_headModel.resetData();
    }

    addNotification("Отключено от COM-порта");
    emit connectedChanged(m_connected);
    m_isCleaningUp = false;
}

bool TiltController::setupCOMPort()
{
    if (m_serialPort) {
        cleanupCOMPort();
    }

    m_serialPort = new QSerialPort(this);
    m_serialPort->setPortName(m_selectedPort);
    m_serialPort->setBaudRate(QSerialPort::Baud115200);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    // Подключаем сигналы с осторожностью
    connect(m_serialPort, &QSerialPort::readyRead, this, &TiltController::readCOMPortData, Qt::QueuedConnection);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &TiltController::handleCOMPortError, Qt::QueuedConnection);

    try {
        if (m_serialPort->open(QIODevice::ReadOnly)) {
            m_connected = true;
            m_autoConnectTimer.stop();
            m_safetyTimer.start();

            // Переключаемся в режим COM-порта
            if (m_logMode) {
                stopLog();
                m_logMode = false;
                emit logModeChanged(m_logMode);
                emit logControlsEnabledChanged(logControlsEnabled());
            }

            m_incompleteData.clear();

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

    if (m_serialPort) {
        // Отключаем все сигналы в первую очередь
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

    m_incompleteData.clear();
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

        // Обрабатываем данные
        processCOMPortData(data);

    } catch (const std::exception& e) {
        qDebug() << "Exception reading COM port:" << e.what();
        safeDisconnect();
    }
}

void TiltController::processCOMPortData(const QByteArray &data)
{
    // Добавляем новые данные к неполным данным
    m_incompleteData.append(data);

    // Ищем полные строки (разделитель - новая строка)
    while (true) {
        int newlinePos = m_incompleteData.indexOf('\n');
        if (newlinePos == -1) {
            // Нет полных строк, ждем еще данных
            break;
        }

        // Извлекаем полную строку
        QByteArray completeLine = m_incompleteData.left(newlinePos).trimmed();
        m_incompleteData = m_incompleteData.mid(newlinePos + 1);

        if (completeLine.isEmpty()) {
            continue;
        }

        QString dataString = QString::fromUtf8(completeLine);
        qDebug() << "COM Port complete line:" << dataString;

        // Парсим данные - ожидаем формат из лог-файла или простой CSV
        if (dataString.contains(';')) {
            // Формат лог-файла: время;pitch;roll;yaw;speedPitch;speedRoll;speedYaw;dizziness
            QStringList parts = dataString.split(';');
            if (parts.size() >= 4) {
                bool ok1, ok2, ok3;
                float pitch = parts[1].replace(',', '.').toFloat(&ok1);
                float roll = parts[2].replace(',', '.').toFloat(&ok2);
                float yaw = parts[3].replace(',', '.').toFloat(&ok3);

                if (ok1 && ok2 && ok3) {
                    // Для COM-порта скорости и головокружение не вычисляем
                    updateHeadModel(pitch, roll, yaw, 0.0f, 0.0f, 0.0f, false);
                }
            }
        } else if (dataString.contains(',')) {
            // Простой CSV формат: pitch,roll,yaw
            QStringList parts = dataString.split(',');
            if (parts.size() >= 3) {
                bool ok1, ok2, ok3;
                float pitch = parts[0].toFloat(&ok1);
                float roll = parts[1].toFloat(&ok2);
                float yaw = parts[2].toFloat(&ok3);

                if (ok1 && ok2 && ok3) {
                    updateHeadModel(pitch, roll, yaw, 0.0f, 0.0f, 0.0f, false);
                }
            }
        }
    }

    // Защита от переполнения буфера
    if (m_incompleteData.size() > 1024) {
        qDebug() << "Incomplete data buffer too large, clearing";
        m_incompleteData.clear();
    }
}

void TiltController::handleCOMPortError(QSerialPort::SerialPortError error)
{
    if (m_isCleaningUp) return;

    qDebug() << "COM port error occurred:" << error;

    switch (error) {
    case QSerialPort::NoError:
        return;

    case QSerialPort::ResourceError:
        // Физическое отключение устройства - это нормально, не показываем ошибку
        qDebug() << "COM port resource error (device disconnected)";
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
        // Для остальных ошибок показываем сообщение
        if (m_serialPort) {
            addNotification("Ошибка COM-порта: " + m_serialPort->errorString());
        } else {
            addNotification("Ошибка COM-порта");
        }
        safeDisconnect();
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

        // Сбрасываем модель к состоянию "нет данных"
        m_headModel.resetData();

        // Запускаем авто-подключение
        m_autoConnectTimer.start();
        addNotification("Переключено в режим COM-порта");
    }
}

void TiltController::loadLogFile(const QString &filePath)
{
    QString fileName = filePath;

    if (fileName.startsWith("file:///")) {
        fileName = fileName.mid(8);
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

    m_logData.clear();
    m_currentLogIndex = 0;
    m_studyInfo.clear();

    QTextStream in(&file);
    int lineNumber = 0;
    QStringList studyLines;

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        lineNumber++;

        if (lineNumber <= 5 && line.startsWith('#')) {
            studyLines << line.mid(1).trimmed(); // Убираем # и обрезаем пробелы
            continue;
        }

        if (line.isEmpty() || line.startsWith("##########")) {
            continue;
        }

        QStringList parts = line.split(';');
        if (parts.size() >= 8) {
            LogEntry entry;
            bool ok1, ok2, ok3, ok4, ok5, ok6, ok7;

            entry.time = parts[0].toInt(&ok1);
            entry.pitch = parts[1].replace(',', '.').toFloat(&ok2);
            entry.roll = parts[2].replace(',', '.').toFloat(&ok3);
            entry.yaw = parts[3].replace(',', '.').toFloat(&ok4);
            entry.speedPitch = parts[4].replace(',', '.').toFloat(&ok5);
            entry.speedRoll = parts[5].replace(',', '.').toFloat(&ok6);
            entry.speedYaw = parts[6].replace(',', '.').toFloat(&ok7);
            entry.dizziness = (parts[7].toInt() == 1);

            if (ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7) {
                m_logData.append(entry);
            } else {
                qDebug() << "Failed to parse line:" << line;
            }
        } else {
            qDebug() << "Invalid line format:" << line;
        }
    }

    file.close();

    // Формируем информацию об исследовании
    if (!studyLines.isEmpty()) {
        m_studyInfo = studyLines.join(" | ");
    } else {
        m_studyInfo = "Информация об исследовании не найдена";
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

    // Останавливаем COM-порт если был подключен
    if (m_connected) {
        disconnectDevice();
    }
    m_autoConnectTimer.stop();

    // Устанавливаем первую запись
    if (!m_logData.isEmpty()) {
        const LogEntry &firstEntry = m_logData.first();
        updateHeadModel(firstEntry.pitch, firstEntry.roll, firstEntry.yaw,
                        firstEntry.speedPitch, firstEntry.speedRoll, firstEntry.speedYaw,
                        firstEntry.dizziness);
    }

    addNotification("Лог-файл загружен: " + QString::number(m_logData.size()) + " записей");
    emit logLoadedChanged(m_logLoaded);
    emit logModeChanged(m_logMode);
    emit logControlsEnabledChanged(logControlsEnabled());
    emit studyInfoChanged(m_studyInfo);
    emit totalTimeChanged(m_totalTime);
    emit currentTimeChanged(m_currentTime);
}

void TiltController::playLog()
{
    if (!m_logLoaded || m_logData.isEmpty()) return;

    m_logPlaying = true;
    m_logTimer.start();
    emit logPlayingChanged(m_logPlaying);
    addNotification("Воспроизведение лога начато");
}

void TiltController::pauseLog()
{
    m_logPlaying = false;
    m_logTimer.stop();
    emit logPlayingChanged(m_logPlaying);
    addNotification("Воспроизведение лога приостановлено");
}

void TiltController::stopLog()
{
    m_logPlaying = false;
    m_logTimer.stop();
    m_currentTime = 0;
    m_currentLogIndex = 0;

    if (!m_logData.isEmpty()) {
        const LogEntry &firstEntry = m_logData.first();
        updateHeadModel(firstEntry.pitch, firstEntry.roll, firstEntry.yaw,
                        firstEntry.speedPitch, firstEntry.speedRoll, firstEntry.speedYaw,
                        firstEntry.dizziness);
    }

    emit logPlayingChanged(m_logPlaying);
    emit currentTimeChanged(m_currentTime);
    addNotification("Воспроизведение лога остановлено");
}

void TiltController::seekLog(int time)
{
    if (!m_logLoaded || m_logData.isEmpty()) return;

    m_currentTime = qBound(0, time, m_totalTime);

    // Находим ближайшую запись в логе
    for (int i = 0; i < m_logData.size(); ++i) {
        if (m_logData[i].time >= m_currentTime) {
            m_currentLogIndex = i;
            const LogEntry &entry = m_logData[i];
            updateHeadModel(entry.pitch, entry.roll, entry.yaw,
                            entry.speedPitch, entry.speedRoll, entry.speedYaw,
                            entry.dizziness);
            break;
        }
    }

    emit currentTimeChanged(m_currentTime);
}

void TiltController::updateLogPlayback()
{
    if (m_currentLogIndex >= m_logData.size()) {
        stopLog();
        return;
    }

    if (m_currentLogIndex < m_logData.size()) {
        const LogEntry &entry = m_logData[m_currentLogIndex];
        updateHeadModel(entry.pitch, entry.roll, entry.yaw,
                        entry.speedPitch, entry.speedRoll, entry.speedYaw,
                        entry.dizziness);
        m_currentTime = entry.time;
        emit currentTimeChanged(m_currentTime);
        m_currentLogIndex++;
    }
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

    // Получаем реальные COM-порты
    QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        m_availablePorts << port.portName();
    }

    // Если портов нет, добавляем симуляционные для тестирования
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
}

void TiltController::addNotification(const QString &message)
{
    m_notification = QDateTime::currentDateTime().toString("[hh:mm:ss] ") + message;
    emit notificationChanged(m_notification);
    qDebug() << message;
}

void TiltController::setTestData()
{
    // Устанавливаем тестовые данные
    updateHeadModel(15.5f, -8.2f, 3.7f, 2.1f, 1.5f, 0.8f, false);
    addNotification("Тестовые данные установлены");

    qDebug() << "Test data set - Pitch: 15.5, Roll: -8.2, Yaw: 3.7";
}
