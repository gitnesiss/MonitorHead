#ifndef TILTCONTROLLER_H
#define TILTCONTROLLER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QElapsedTimer>
#include <QtCore/QVector>
#include <QtCore/QUrl>
#include <QtCore/QDateTime>
#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>
#include <QtCore/QByteArray>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTextStream>
#include <deque>
#include "headmodel.h"

// Структура для хранения данных углов с временной меткой
struct AngleData {
    qint64 timestamp;
    float pitch;
    float roll;
    float yaw;
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
    void initializeResearchNumber();

private slots:
    void updateLogPlayback();
    void readCOMPortData();
    void handleCOMPortError(QSerialPort::SerialPortError error);
    void updateDataDisplay();

private:
    void updateHeadModel(float pitch, float roll, float yaw, float speedPitch, float speedRoll, float speedYaw, bool dizziness);
    void addNotification(const QString &message);
    bool setupCOMPort();
    void cleanupCOMPort();
    void safeDisconnect();
    void processCOMPortData(const QByteArray &data);
    void calculateSpeeds(float pitch, float roll, float yaw, bool dizziness);
    void updateSpeedBuffers(float pitch, float roll, float yaw, qint64 timestamp);
    void computeAverageSpeeds(float &avgSpeedPitch, float &avgSpeedRoll, float &avgSpeedYaw);
    QString generateResearchFileName(const QString &number);
    void writeResearchHeader();

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

    struct LogEntry {
        int time;
        float pitch;
        float roll;
        float yaw;
        float speedPitch;
        float speedRoll;
        float speedYaw;
        bool dizziness;
    };
    QVector<LogEntry> m_logData;
    int m_currentLogIndex = 0;

    QByteArray m_incompleteData;
    bool m_isCleaningUp = false;

    // Буферы для хранения последних значений углов (для вычисления скоростей)
    std::deque<AngleData> m_angleHistory;
    const int m_maxHistorySize = 6;

    // Данные для графиков
    void updateGraphData(float pitch, float roll, float yaw, bool dizziness);
    void cleanupOldData();

    int m_graphDuration = 30;
    QVariantList m_pitchGraphData;
    QVariantList m_rollGraphData;
    QVariantList m_yawGraphData;
    QVariantList m_dizzinessData;

    struct GraphPoint {
        qint64 timestamp;
        float value;
    };
    QList<GraphPoint> m_pitchHistory;
    QList<GraphPoint> m_rollHistory;
    QList<GraphPoint> m_yawHistory;
    struct DizzinessInterval {
        qint64 startTime;
        qint64 endTime;
        bool active;
    };
    QList<DizzinessInterval> m_dizzinessIntervals;

    qint64 m_currentDizzinessStart = 0;
    bool m_lastDizzinessState = false;

    int m_updateCounter = 0;
    int m_updateThrottle = 1;

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
    float m_prevPitch = 0.0f;
    float m_prevRoll = 0.0f;
    float m_prevYaw = 0.0f;
    qint64 m_prevTime = 0;

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
};

#endif // TILTCONTROLLER_H
