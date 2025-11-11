#ifndef LOG_READER_H
#define LOG_READER_H

#include <QtCore/QObject>
#include <QtCore/QVector>
#include <QtCore/QDateTime>

// Общая структура данных для лог-файла
struct LogDataEntry {
    qint64 time;
    float pitch;
    float roll;
    float yaw;
    bool dizziness;
    bool doctorDizziness;

    LogDataEntry() : time(0), pitch(0), roll(0), yaw(0),
        dizziness(false), doctorDizziness(false) {}
};

class LogReader : public QObject
{
    Q_OBJECT

public:
    explicit LogReader(QObject *parent = nullptr);

    void setData(const QVector<LogDataEntry> &data);
    void setUpdateFrequency(float frequencyHz);

    float calculateAngularSpeed(qint64 currentTime, const QString &angleType, bool isPlaying);

    float getUpdateFrequency() const { return m_updateFrequency; }

private:
    QVector<LogDataEntry> m_logData;
    float m_updateFrequency; // Hz (1-10 Hz)
    float m_windowDuration; // seconds (0.1 - 1.0 seconds)

    int findIndexByTime(qint64 time);
    QVector<LogDataEntry> getAngleDataInRange(qint64 startTime, qint64 endTime, const QString &angleType);
    float calculateSimpleSpeed(const QVector<LogDataEntry> &entries, const QString &angleType);
};

#endif // LOG_READER_H
