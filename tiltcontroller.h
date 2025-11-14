#ifndef TILTCONTROLLER_H
#define TILTCONTROLLER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QVector>
#include <QtCore/QUrl>
#include <QtCore/QDateTime>
#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>
#include <QtCore/QByteArray>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTextStream>
#include "headmodel.h"
#include "log_reader.h"

// Структура для хранения одного кадра данных
struct DataFrame {
    qint64 timestamp;        // Время в мс
    float pitch;             // Угол по pitch
    float roll;              // Угол по roll
    float yaw;               // Угол по yaw
    bool patientDizziness;   // Головокружение пациента (0 или 1)
    bool doctorDizziness;    // Головокружение врача (0 или 1)

    DataFrame() : timestamp(0), pitch(0), roll(0), yaw(0),
        patientDizziness(false), doctorDizziness(false) {}
};

struct AngleDataPoint {
    qint64 timestamp;
    float angle;
    AngleDataPoint(qint64 t, float a) : timestamp(t), angle(a) {}
};

// Кольцевой буфер на 1800 кадров
class CircularBuffer {
public:
    CircularBuffer(int capacity = 2000) :
        m_capacity(capacity), m_buffer(capacity), m_size(0), m_head(0) {}

    void add(const DataFrame& frame) {
        if (m_size < m_capacity) {
            m_buffer[m_head] = frame;
            m_head = (m_head + 1) % m_capacity;
            m_size++;
        } else {
            m_buffer[m_head] = frame;
            m_head = (m_head + 1) % m_capacity;
        }
    }

    DataFrame at(int index) const {
        if (index < 0 || index >= m_size) return DataFrame();
        int actualIndex = (m_head - m_size + index + m_capacity) % m_capacity;
        return m_buffer[actualIndex];
    }

    DataFrame last() const {
        if (m_size == 0) return DataFrame();
        return at(m_size - 1);
    }

    DataFrame first() const {
        if (m_size == 0) return DataFrame();
        return at(0);
    }

    int size() const { return m_size; }
    int capacity() const { return m_capacity; }
    bool isEmpty() const { return m_size == 0; }
    bool isFull() const { return m_size == m_capacity; }

    void clear() {
        m_size = 0;
        m_head = 0;
    }

    // Получить диапазон данных за последние N миллисекунд
    QVector<DataFrame> getRange(qint64 durationMs) const {
        QVector<DataFrame> result;
        if (m_size == 0) return result;

        qint64 currentTime = last().timestamp;
        qint64 minTime = currentTime - durationMs;

        for (int i = 0; i < m_size; ++i) {
            const DataFrame& frame = at(i);
            if (frame.timestamp >= minTime) {
                result.append(frame);
            }
        }

        return result;
    }

private:
    int m_capacity;
    QVector<DataFrame> m_buffer;
    int m_size;
    int m_head;
};

class TiltController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(HeadModel* headModel READ headModel CONSTANT)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int currentTime READ currentTime NOTIFY currentTimeChanged)
    Q_PROPERTY(int totalTime READ totalTime NOTIFY totalTimeChanged)
    Q_PROPERTY(bool logPlaying READ logPlaying NOTIFY logPlayingChanged)
    Q_PROPERTY(QString notification READ notification NOTIFY notificationChanged)
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(QString selectedPort READ selectedPort WRITE setSelectedPort NOTIFY selectedPortChanged)
    Q_PROPERTY(bool logLoaded READ logLoaded NOTIFY logLoadedChanged)
    Q_PROPERTY(bool logMode READ logMode NOTIFY logModeChanged)
    Q_PROPERTY(bool logControlsEnabled READ logControlsEnabled NOTIFY logControlsEnabledChanged)
    Q_PROPERTY(QString studyInfo READ studyInfo NOTIFY studyInfoChanged)
    Q_PROPERTY(int graphDuration READ graphDuration WRITE setGraphDuration NOTIFY graphDurationChanged)
    Q_PROPERTY(QVariantList pitchGraphData READ pitchGraphData NOTIFY graphDataChanged)
    Q_PROPERTY(QVariantList rollGraphData READ rollGraphData NOTIFY graphDataChanged)
    Q_PROPERTY(QVariantList yawGraphData READ yawGraphData NOTIFY graphDataChanged)
    Q_PROPERTY(QVariantList dizzinessData READ dizzinessData NOTIFY graphDataChanged)
    Q_PROPERTY(int updateFrequency READ updateFrequency NOTIFY updateFrequencyChanged)
    Q_PROPERTY(QString researchNumber READ researchNumber NOTIFY researchNumberChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QVariantList dizzinessPatientData READ dizzinessPatientData NOTIFY graphDataChanged)
    Q_PROPERTY(QVariantList dizzinessDoctorData READ dizzinessDoctorData NOTIFY graphDataChanged)
    Q_PROPERTY(bool patientDizziness READ patientDizziness NOTIFY patientDizzinessChanged)
    Q_PROPERTY(bool doctorDizziness READ doctorDizziness NOTIFY doctorDizzinessChanged)
    Q_PROPERTY(float angularSpeedUpdateFrequencyCOM READ angularSpeedUpdateFrequencyCOM WRITE setAngularSpeedUpdateFrequencyCOM NOTIFY angularSpeedUpdateFrequencyCOMChanged)
    Q_PROPERTY(float angularSpeedUpdateFrequencyLog READ angularSpeedUpdateFrequencyLog WRITE setAngularSpeedUpdateFrequencyLog NOTIFY angularSpeedUpdateFrequencyLogChanged)
    Q_PROPERTY(QString loadedResearchNumber READ loadedResearchNumber NOTIFY loadedResearchNumberChanged)  // Обновление надписи в поле номера исследования в режиме воспроизведения
    Q_PROPERTY(float angularSpeedSmoothingLog READ angularSpeedSmoothingLog WRITE setAngularSpeedSmoothingLog NOTIFY angularSpeedSmoothingLogChanged)
    Q_PROPERTY(float angularSpeedUpdateRateLog READ angularSpeedUpdateRateLog WRITE setAngularSpeedUpdateRateLog NOTIFY angularSpeedUpdateRateLogChanged)
    Q_PROPERTY(float angularSpeedDisplayRateLog READ angularSpeedDisplayRateLog WRITE setAngularSpeedDisplayRateLog NOTIFY angularSpeedDisplayRateLogChanged)

public:
    explicit TiltController(QObject *parent = nullptr);
    ~TiltController();

    HeadModel* headModel() { return &m_headModel; }
    bool connected() const { return m_connected; }
    int currentTime() const { return m_currentTime; }
    int totalTime() const { return m_totalTime; }
    bool logPlaying() const { return m_logPlaying; }
    QString notification() const { return m_notification; }
    QStringList availablePorts() const { return m_availablePorts; }
    QString selectedPort() const { return m_selectedPort; }
    bool logLoaded() const { return m_logLoaded; }
    bool logMode() const { return m_logMode; }
    bool logControlsEnabled() const { return m_logMode && m_logLoaded; }
    QString studyInfo() const { return m_studyInfo; }
    int graphDuration() const { return m_graphDuration; }
    void setGraphDuration(int duration);

    QVariantList pitchGraphData() const { return m_pitchGraphData; }
    QVariantList rollGraphData() const { return m_rollGraphData; }
    QVariantList yawGraphData() const { return m_yawGraphData; }
    QVariantList dizzinessData() const { return m_dizzinessData; }
    int updateFrequency() const { return m_updateFrequency; }
    QString researchNumber() const { return m_researchNumber; }
    bool recording() const { return m_recording; }

    QVariantList dizzinessPatientData() const { return m_dizzinessPatientData; }
    QVariantList dizzinessDoctorData() const { return m_dizzinessDoctorData; }

    bool patientDizziness() const { return m_patientDizziness; }
    bool doctorDizziness() const { return m_doctorDizziness; }

    // Новые методы для управления частотой обновления угловой скорости
    float angularSpeedUpdateFrequency() const { return m_angularSpeedUpdateFrequency; }
    void setAngularSpeedUpdateFrequency(float frequency);

    float angularSpeedUpdateFrequencyCOM() const { return m_angularSpeedUpdateFrequencyCOM; }
    float angularSpeedUpdateFrequencyLog() const { return m_angularSpeedUpdateFrequencyLog; }

    QString loadedResearchNumber() const { return m_loadedResearchNumber; }  // Обновление надписи в поле номера исследования в режиме воспроизведения

    float angularSpeedSmoothingLog() const { return m_angularSpeedSmoothingLog; }
    float angularSpeedUpdateRateLog() const { return m_angularSpeedUpdateRateLog; }
    void setAngularSpeedSmoothingLog(float smoothing);
    void setAngularSpeedUpdateRateLog(float rate);

    float angularSpeedDisplayRateLog() const { return m_angularSpeedDisplayRateLog; }
    void setAngularSpeedDisplayRateLog(float rate);

public slots:
    void connectDevice();
    void disconnectDevice();
    void loadLogFile(const QString &filePath);
    void playLog();
    void pauseLog();
    void stopLog();
    void seekLog(int time);
    void setSelectedPort(const QString &port);
    void refreshPorts();
    void autoConnect();
    void switchToCOMPortMode();
    void startResearchRecording(const QString &researchNumber);
    void stopResearchRecording();
    void toggleResearchRecording();
    void initializeResearchNumber();

private slots:
    void updateLogPlayback();
    void readCOMPortData();
    void handleCOMPortError(QSerialPort::SerialPortError error);
    void updateDataDisplay();
    void setAngularSpeedUpdateFrequencyCOM(float frequency);
    void setAngularSpeedUpdateFrequencyLog(float frequency);

private:
    void updateHeadModel(float pitch, float roll, float yaw, float speedPitch, float speedRoll, float speedYaw, bool dizziness);
    void addNotification(const QString &message);
    bool setupCOMPort();
    void cleanupCOMPort();
    void safeDisconnect();
    void processCOMPortData(const QByteArray &data);
    void calculateSpeeds(float pitch, float roll, float yaw, bool dizziness);

    // Новые методы для работы с кольцевым буфером
    void updateGraphDataFromBuffer();
    void processDataFrame(const DataFrame& frame);
    QString generateResearchFileName(const QString &number);
    void writeResearchHeader();

    // Новые методы для работы с LogReader
    void updateAngularSpeeds();
    void setupLogReader();

    HeadModel m_headModel;
    QTimer m_logTimer;
    QTimer m_autoConnectTimer;
    QTimer m_safetyTimer;
    QSerialPort *m_serialPort = nullptr;

    bool m_connected = false;
    bool m_logPlaying = false;
    bool m_logLoaded = false;
    bool m_logMode = false;
    int m_currentTime = 0;
    int m_totalTime = 0;
    QString m_notification;
    QStringList m_availablePorts;
    QString m_selectedPort;
    QString m_studyInfo;

    // Кольцевой буфер для хранения данных
    CircularBuffer m_dataBuffer;

    struct LogEntry {
        int time;
        float pitch;
        float roll;
        float yaw;
        float speedPitch;
        float speedRoll;
        float speedYaw;
        bool dizziness;
        bool doctorDizziness;  // Добавляем поле для головокружения врача

        LogEntry() : time(0), pitch(0), roll(0), yaw(0),
            speedPitch(0), speedRoll(0), speedYaw(0),
            dizziness(false), doctorDizziness(false) {}
    };

    QVector<LogEntry> m_logData;
    int m_currentLogIndex = 0;

    QByteArray m_incompleteData;
    bool m_isCleaningUp = false;

    // Данные для графиков
    int m_graphDuration = 30;
    QVariantList m_pitchGraphData;
    QVariantList m_rollGraphData;
    QVariantList m_yawGraphData;
    QVariantList m_dizzinessData;

    struct DizzinessInterval {
        qint64 startTime;
        qint64 endTime;
        bool active;
    };
    QList<DizzinessInterval> m_dizzinessIntervals;

    qint64 m_currentDizzinessStart = 0;
    bool m_lastDizzinessState = false;

    int m_updateFrequency = 10;
    QTimer m_dataUpdateTimer;

    // Исследование
    bool m_recording = false;
    QString m_researchNumber = "000001";
    QFile *m_researchFile = nullptr;
    QTextStream *m_researchStream = nullptr;
    QDateTime m_researchStartTime;
    int m_researchFrameCounter = 1;

    // Для вычисления угловых скоростей
    DataFrame m_prevFrame;

    // Оптимизация: кэшируем последние отправленные данные
    QVariantList m_lastPitchData;
    QVariantList m_lastRollData;
    QVariantList m_lastYawData;

    // Оптимизация: счетчик для регулирования частоты обновлений
    int m_updateCounter = 0;
    const int UPDATE_THROTTLE = 2; // Обновляем каждый 2-й вызов

    QVariantList m_dizzinessPatientData;
    QVariantList m_dizzinessDoctorData;

    qint64 m_startTime; // Время начала работы для относительных временных меток
    qint64 m_lastDataTime; // Время последних полученных данных
    bool m_useRelativeTime; // Флаг использования относительного времени

    bool m_patientDizziness = false;
    bool m_doctorDizziness = false;

    qint64 m_researchRecordingStartTime;  // Время начала записи исследования (в мс от начала подключения)

    void updateGraphDataFromLogFile();
    void updateGraphDataFromCOMPort();

    // Оптимизация для лог-файла: работаем напрямую с данными, без кольцевого буфера
    bool m_useDirectLogAccess = true;

    int findLogIndexByTime(qint64 targetTime);

    int m_logUpdateFrequency;  // Частота обновления для лог-режима

    // Для синхронизации времени воспроизведения
    qint64 m_playbackStartRealTime;  // Реальное время начала воспроизведения
    qint64 m_playbackStartLogTime;   // Время в логе на момент начала воспроизведения
    bool m_playbackTimeInitialized;  // Флаг инициализации времени

    qint64 m_graphDisplayTime;  // Время для отображения графика (независимо от воспроизведения)

    // Структура для хранения данных об угле и времени
    struct AngleHistory {
        qint64 timestamp;
        float angle;
        AngleHistory(qint64 t, float a) : timestamp(t), angle(a) {}
    };

    // Буферы для хранения истории углов
    QVector<AngleHistory> m_pitchHistory;
    QVector<AngleHistory> m_rollHistory;
    QVector<AngleHistory> m_yawHistory;

    // Настройки расчета скорости
    const int m_speedCalculationPoints = 6; // Количество точек для расчета
    const qint64 m_minTimeWindow = 300;     // Минимальное окно времени в мс
    const qint64 m_maxTimeWindow = 2000;    // Максимальное окно времени в мс

    // Функция для расчета угловой скорости
    float calculateAngularSpeed(QVector<AngleHistory>& history, float currentAngle, qint64 currentTime);

    // LogReader для расчета угловых скоростей в режиме лог-файла
    LogReader m_logReader;
    float m_angularSpeedUpdateFrequency = 4.0f; // default 4 Hz

    Q_PROPERTY(float angularSpeedUpdateFrequency READ angularSpeedUpdateFrequency WRITE setAngularSpeedUpdateFrequency NOTIFY angularSpeedUpdateFrequencyChanged)

    // Для усреднения данных COM-порта
    QVector<AngleDataPoint> m_comPitchBuffer;
    QVector<AngleDataPoint> m_comRollBuffer;
    QVector<AngleDataPoint> m_comYawBuffer;
    QTimer m_comSpeedUpdateTimer;
    float m_currentComSpeedPitch = 0.0f;
    float m_currentComSpeedRoll = 0.0f;
    float m_currentComSpeedYaw = 0.0f;

    void updateCOMAngularSpeeds();
    float calculateCOMAngularSpeed(QVector<AngleDataPoint>& dataBuffer);
    void clearCOMBuffers();

    float m_angularSpeedUpdateFrequencyCOM = 4.0f;  // для COM-порта
    float m_angularSpeedUpdateFrequencyLog = 4.0f;  // для лог-файла

    QString m_loadedResearchNumber;  // Обновление надписи в поле номера исследования в режиме воспроизведения

    QString extractResearchNumber(const QStringList &studyLines);

    float m_angularSpeedSmoothingLog = 0.5f;  // Окно сглаживания в секундах (0.5-2.0)
    float m_angularSpeedUpdateRateLog = 10.0f; // Частота обновления в Гц (1-30)

    float m_angularSpeedDisplayRateLog = 10.0f; // Частота отображения в Гц (1-30)
    qint64 m_lastAngularSpeedUpdate = 0; // Время последнего обновления скоростей

signals:
    void connectedChanged(bool connected);
    void currentTimeChanged(int time);
    void totalTimeChanged(int time);
    void logPlayingChanged(bool playing);
    void notificationChanged(const QString &message);
    void availablePortsChanged();
    void selectedPortChanged();
    void logLoadedChanged(bool loaded);
    void logModeChanged(bool logMode);
    void logControlsEnabledChanged(bool enabled);
    void studyInfoChanged(const QString &studyInfo);
    void graphDurationChanged(int duration);
    void graphDataChanged();
    void updateFrequencyChanged(int frequency);
    void researchNumberChanged(const QString &researchNumber);
    void recordingChanged(bool recording);
    void patientDizzinessChanged(bool patientDizziness);
    void doctorDizzinessChanged(bool doctorDizziness);
    void angularSpeedUpdateFrequencyChanged(float frequency);
    void angularSpeedUpdateFrequencyCOMChanged(float frequency);
    void angularSpeedUpdateFrequencyLogChanged(float frequency);
    void loadedResearchNumberChanged(const QString &loadedResearchNumber);  // Обновление надписи в поле номера исследования в режиме воспроизведения

    void angularSpeedSmoothingLogChanged(float smoothing);
    void angularSpeedUpdateRateLogChanged(float rate);
    void angularSpeedDisplayRateLogChanged(float rate);
};

#endif // TILTCONTROLLER_H
