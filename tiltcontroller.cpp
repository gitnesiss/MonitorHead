#include "tiltcontroller.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QtMath>
#include <QDateTime>
#include <QCoreApplication>
#include <algorithm>

TiltController::TiltController(QObject *parent) : QObject(parent)
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

    m_headModel.resetData();

    refreshPorts();

    m_autoConnectTimer.start();
    addNotification("Программа запущена. Попытка автоматического подключения к COM-порту...");

    m_graphDuration = 30;

    m_updateFrequency = 10;
    m_dataUpdateTimer.setInterval(1000 / m_updateFrequency);
    connect(&m_dataUpdateTimer, &QTimer::timeout, this, &TiltController::updateDataDisplay);
    m_dataUpdateTimer.start();

    m_lastDizzinessState = false;
    m_currentDizzinessStart = 0;
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

    if (!m_logMode) {
        m_headModel.resetData();
        m_angleHistory.clear();
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
            m_angleHistory.clear();

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
    m_angleHistory.clear();
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
        qDebug() << "Exception reading COM port:" << e.what();
        safeDisconnect();
    }
}

void TiltController::updateSpeedBuffers(float pitch, float roll, float yaw, qint64 timestamp)
{
    AngleData newData;
    newData.timestamp = timestamp;
    newData.pitch = pitch;
    newData.roll = roll;
    newData.yaw = yaw;

    m_angleHistory.push_back(newData);

    while (m_angleHistory.size() > m_maxHistorySize) {
        m_angleHistory.pop_front();
    }
}

void TiltController::computeAverageSpeeds(float &avgSpeedPitch, float &avgSpeedRoll, float &avgSpeedYaw)
{
    if (m_angleHistory.size() < 2) {
        avgSpeedPitch = 0.0f;
        avgSpeedRoll = 0.0f;
        avgSpeedYaw = 0.0f;
        return;
    }

    const AngleData &newest = m_angleHistory.back();
    const AngleData &oldest = m_angleHistory.front();

    qint64 timeDiff = newest.timestamp - oldest.timestamp;

    if (timeDiff > 0) {
        avgSpeedPitch = (newest.pitch - oldest.pitch) * 1000.0f / timeDiff;
        avgSpeedRoll = (newest.roll - oldest.roll) * 1000.0f / timeDiff;
        avgSpeedYaw = (newest.yaw - oldest.yaw) * 1000.0f / timeDiff;

        const float maxSpeed = 180.0f;
        avgSpeedPitch = qBound(-maxSpeed, avgSpeedPitch, maxSpeed);
        avgSpeedRoll = qBound(-maxSpeed, avgSpeedRoll, maxSpeed);
        avgSpeedYaw = qBound(-maxSpeed, avgSpeedYaw, maxSpeed);

        qDebug() << "Computed speeds - Pitch:" << avgSpeedPitch
                 << "Roll:" << avgSpeedRoll << "Yaw:" << avgSpeedYaw
                 << "Time diff:" << timeDiff << "ms";
    } else {
        avgSpeedPitch = 0.0f;
        avgSpeedRoll = 0.0f;
        avgSpeedYaw = 0.0f;
    }
}

void TiltController::calculateSpeeds(float pitch, float roll, float yaw, bool dizziness)
{
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    updateSpeedBuffers(pitch, roll, yaw, currentTime);

    float avgSpeedPitch, avgSpeedRoll, avgSpeedYaw;
    computeAverageSpeeds(avgSpeedPitch, avgSpeedRoll, avgSpeedYaw);

    qDebug() << "Calculated speeds - Pitch:" << avgSpeedPitch
             << "Roll:" << avgSpeedRoll << "Yaw:" << avgSpeedYaw
             << "Dizziness:" << dizziness;

    updateHeadModel(pitch, roll, yaw, avgSpeedPitch, avgSpeedRoll, avgSpeedYaw, dizziness);
}

void TiltController::processCOMPortData(const QByteArray &data)
{
    m_incompleteData.append(data);

    while (true) {
        int newlinePos = m_incompleteData.indexOf('\n');
        if (newlinePos == -1) {
            break;
        }

        QByteArray completeLine = m_incompleteData.left(newlinePos).trimmed();
        m_incompleteData = m_incompleteData.mid(newlinePos + 1);

        if (completeLine.isEmpty()) {
            continue;
        }

        QString dataString = QString::fromUtf8(completeLine);
        qDebug() << "COM Port complete line:" << dataString;

        if (dataString.contains(';')) {
            QStringList parts = dataString.split(';');
            if (parts.size() >= 8) {
                bool ok1, ok2, ok3, ok8;
                float pitch = parts[1].replace(',', '.').toFloat(&ok1);
                float roll = parts[2].replace(',', '.').toFloat(&ok2);
                float yaw = parts[3].replace(',', '.').toFloat(&ok3);
                bool dizziness = (parts[7].toInt(&ok8) == 1);

                if (ok1 && ok2 && ok3 && ok8) {
                    qDebug() << "Parsed COM data - Pitch:" << pitch << "Roll:" << roll << "Yaw:" << yaw << "Dizziness:" << dizziness;
                    calculateSpeeds(pitch, roll, yaw, dizziness);
                } else {
                    qDebug() << "Failed to parse COM data. ok1:" << ok1 << "ok2:" << ok2 << "ok3:" << ok3 << "ok8:" << ok8;
                }
            } else {
                qDebug() << "Invalid COM data format. Expected 8 fields, got:" << parts.size();
            }
        } else if (dataString.contains(',')) {
            QStringList parts = dataString.split(',');
            if (parts.size() >= 3) {
                bool ok1, ok2, ok3;
                float pitch = parts[0].toFloat(&ok1);
                float roll = parts[1].toFloat(&ok2);
                float yaw = parts[2].toFloat(&ok3);

                if (ok1 && ok2 && ok3) {
                    calculateSpeeds(pitch, roll, yaw, false);
                }
            }
        }
    }

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

        m_headModel.resetData();
        m_angleHistory.clear();

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
            studyLines << line.mid(1).trimmed();
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

    if (m_connected) {
        disconnectDevice();
    }
    m_autoConnectTimer.stop();

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

        if (entry.dizziness) {
            qDebug() << "Log playback: Dizziness at time" << entry.time << "seconds";
        }
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
        updateGraphData(pitch, roll, yaw, dizziness);
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
        cleanupOldData();
        emit graphDurationChanged(m_graphDuration);
        emit graphDataChanged();
    }
}

void TiltController::updateGraphData(float pitch, float roll, float yaw, bool dizziness)
{
    static qint64 lastUpdateTime = 0;
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    static int updateCounter = 0;
    updateCounter++;
    if (updateCounter % m_updateThrottle != 0) {
        return;
    }

    if (currentTime - lastUpdateTime < 150) {
        return;
    }
    lastUpdateTime = currentTime;

    if (dizziness != m_lastDizzinessState) {
        if (dizziness) {
            m_currentDizzinessStart = currentTime;
            qDebug() << "Dizziness interval started at:" << currentTime;
        } else if (m_currentDizzinessStart != 0) {
            DizzinessInterval interval;
            interval.startTime = m_currentDizzinessStart;
            interval.endTime = currentTime;
            interval.active = false;
            m_dizzinessIntervals.append(interval);
            m_currentDizzinessStart = 0;
            qDebug() << "Dizziness interval ended at:" << currentTime
                     << "duration:" << (currentTime - interval.startTime) << "ms";
        }
        m_lastDizzinessState = dizziness;
    }

    const int maxHistoryPoints = m_graphDuration * 10;

    if (!std::isfinite(pitch) || !std::isfinite(roll) || !std::isfinite(yaw)) {
        return;
    }

    m_pitchHistory.append({currentTime, pitch});
    m_rollHistory.append({currentTime, roll});
    m_yawHistory.append({currentTime, yaw});

    cleanupOldData();

    while (m_pitchHistory.size() > maxHistoryPoints) {
        m_pitchHistory.removeFirst();
    }
    while (m_rollHistory.size() > maxHistoryPoints) {
        m_rollHistory.removeFirst();
    }
    while (m_yawHistory.size() > maxHistoryPoints) {
        m_yawHistory.removeFirst();
    }

    qint64 minTime = currentTime - m_graphDuration * 1000;
    while (!m_dizzinessIntervals.isEmpty() && m_dizzinessIntervals.first().endTime < minTime) {
        m_dizzinessIntervals.removeFirst();
    }

    QVariantList newPitchData, newRollData, newYawData, newDizzinessData;

    for (const auto& point : m_pitchHistory) {
        if (point.timestamp >= minTime) {
            QVariantMap dataPoint;
            dataPoint["time"] = point.timestamp;
            dataPoint["value"] = point.value;
            newPitchData.append(dataPoint);
        }
    }

    for (const auto& point : m_rollHistory) {
        if (point.timestamp >= minTime) {
            QVariantMap dataPoint;
            dataPoint["time"] = point.timestamp;
            dataPoint["value"] = point.value;
            newRollData.append(dataPoint);
        }
    }

    for (const auto& point : m_yawHistory) {
        if (point.timestamp >= minTime) {
            QVariantMap dataPoint;
            dataPoint["time"] = point.timestamp;
            dataPoint["value"] = point.value;
            newYawData.append(dataPoint);
        }
    }

    for (const auto& interval : m_dizzinessIntervals) {
        if (interval.endTime >= minTime) {
            QVariantMap intervalData;
            intervalData["startTime"] = interval.startTime;
            intervalData["endTime"] = interval.endTime;
            newDizzinessData.append(intervalData);
        }
    }

    if (m_currentDizzinessStart != 0 && m_currentDizzinessStart >= minTime) {
        QVariantMap currentInterval;
        currentInterval["startTime"] = m_currentDizzinessStart;
        currentInterval["endTime"] = currentTime;
        currentInterval["active"] = true;
        newDizzinessData.append(currentInterval);
    }

    if (m_pitchGraphData != newPitchData || m_rollGraphData != newRollData ||
        m_yawGraphData != newYawData || m_dizzinessData != newDizzinessData) {

        m_pitchGraphData = newPitchData;
        m_rollGraphData = newRollData;
        m_yawGraphData = newYawData;
        m_dizzinessData = newDizzinessData;

        qDebug() << "Graph data updated. Dizziness intervals:" << m_dizzinessData.size();
        emit graphDataChanged();
    }
}

void TiltController::cleanupOldData()
{
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    qint64 minTime = currentTime - m_graphDuration * 1000;

    if (m_pitchHistory.size() > m_graphDuration * 15) {
        while (!m_pitchHistory.isEmpty() && m_pitchHistory.first().timestamp < minTime) {
            m_pitchHistory.removeFirst();
        }
    }

    if (m_rollHistory.size() > m_graphDuration * 15) {
        while (!m_rollHistory.isEmpty() && m_rollHistory.first().timestamp < minTime) {
            m_rollHistory.removeFirst();
        }
    }

    if (m_yawHistory.size() > m_graphDuration * 15) {
        while (!m_yawHistory.isEmpty() && m_yawHistory.first().timestamp < minTime) {
            m_yawHistory.removeFirst();
        }
    }
}

void TiltController::updateDataDisplay()
{
    if (m_connected || m_logPlaying) {
        emit graphDataChanged();
    }
}
