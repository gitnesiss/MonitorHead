#ifndef TILTCONTROLLER_H
#define TILTCONTROLLER_H

#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <QVector>
#include <QUrl>
#include <QDateTime>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QByteArray>
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
    void setTestData();

private slots:
    void updateLogPlayback();
    void readCOMPortData();
    void handleCOMPortError(QSerialPort::SerialPortError error);

private:
    void parseLogData(const QString &data);
    void updateHeadModel(float pitch, float roll, float yaw, float speedPitch, float speedRoll, float speedYaw, bool dizziness);
    void addNotification(const QString &message);
    bool setupCOMPort();
    void cleanupCOMPort();
    void safeDisconnect();
    void processCOMPortData(const QByteArray &data);
    void calculateSpeeds(float pitch, float roll, float yaw);
    void updateSpeedBuffers(float pitch, float roll, float yaw, qint64 timestamp);
    void computeAverageSpeeds(float &avgSpeedPitch, float &avgSpeedRoll, float &avgSpeedYaw);

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

    QByteArray m_incompleteData; // Для сборки неполных данных
    bool m_isCleaningUp = false; // Флаг для предотвращения рекурсивной очистки

    // Буферы для хранения последних значений углов (для вычисления скоростей)
    std::deque<AngleData> m_angleHistory;
    const int m_maxHistorySize = 6; // Для частоты 60 Гц

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
};

#endif // TILTCONTROLLER_H
