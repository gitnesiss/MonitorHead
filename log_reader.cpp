#include "log_reader.h"
#include <QtMath>
#include <algorithm>
#include <QDebug>

LogReader::LogReader(QObject *parent) : QObject(parent)
    , m_updateFrequency(4.0f) // default 4 Hz
    , m_windowDuration(0.5f)  // default 0.5 seconds
{
}

void LogReader::setData(const QVector<LogDataEntry> &data)
{
    m_logData = data;
}

void LogReader::setUpdateFrequency(float frequencyHz)
{
    float oldFrequency = m_updateFrequency;
    m_updateFrequency = qBound(0.1f, frequencyHz, 10.0f);  // Расширяем диапазон
    m_windowDuration = 1.0f / m_updateFrequency;
}

float LogReader::calculateAngularSpeed(qint64 currentTime, const QString &angleType, bool isPlaying)
{
    if (m_logData.isEmpty()) {
        qDebug() << "LogReader: No data available";
        return 0.0f;
    }

    // Заменяем m_windowDuration на m_smoothingWindow
    qint64 windowMs = static_cast<qint64>(m_smoothingWindow * 1000);
    // qint64 windowMs = static_cast<qint64>(m_windowDuration * 1000);
    qint64 halfWindowMs = windowMs / 2;

    qDebug() << "LogReader: Calculating" << angleType << "speed at time" << currentTime << "ms, window:" << windowMs << "ms";

    qint64 startTime, endTime;

    // Determine time range based on conditions
    if (currentTime < halfWindowMs) {
        // Beginning of file - asymmetric window [0, windowDuration]
        startTime = 0;
        endTime = windowMs;
    } else {
        // Playing or paused - symmetric window centered on current time
        startTime = currentTime - halfWindowMs;
        endTime = currentTime + halfWindowMs;
    }

    // Ensure we don't go beyond file boundaries
    qint64 fileDuration = m_logData.last().time;
    startTime = qMax(0LL, startTime);
    endTime = qMin(fileDuration, endTime);

    // Get angle data in the calculated range
    QVector<LogDataEntry> entries = getAngleDataInRange(startTime, endTime, angleType);

    if (entries.size() < 2) return 0.0f;

    // Use simple speed calculation (more reliable)
    return calculateSimpleSpeed(entries, angleType);
}

QVector<LogDataEntry> LogReader::getAngleDataInRange(qint64 startTime, qint64 endTime, const QString &angleType)
{
    QVector<LogDataEntry> entries;

    int startIndex = findIndexByTime(startTime);
    int endIndex = findIndexByTime(endTime);

    if (startIndex == -1 || endIndex == -1) return entries;

    // Get all entries in the time range
    for (int i = startIndex; i <= endIndex; ++i) {
        if (i < 0 || i >= m_logData.size()) continue;
        entries.append(m_logData[i]);
    }

    return entries;
}

int LogReader::findIndexByTime(qint64 time)
{
    if (m_logData.isEmpty()) return -1;

    // Binary search for efficiency
    int left = 0;
    int right = m_logData.size() - 1;
    int result = -1;

    while (left <= right) {
        int mid = left + (right - left) / 2;
        qint64 midTime = m_logData[mid].time;

        if (midTime == time) {
            return mid;
        } else if (midTime < time) {
            result = mid;
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    return result;
}

float LogReader::calculateSimpleSpeed(const QVector<LogDataEntry> &entries, const QString &angleType)
{
    if (entries.size() < 2) return 0.0f;

    // Use first and last entries for speed calculation
    const LogDataEntry &firstEntry = entries.first();
    const LogDataEntry &lastEntry = entries.last();

    // Get the appropriate angle value
    float firstAngle, lastAngle;
    if (angleType == "pitch") {
        firstAngle = firstEntry.pitch;
        lastAngle = lastEntry.pitch;
    } else if (angleType == "roll") {
        firstAngle = firstEntry.roll;
        lastAngle = lastEntry.roll;
    } else if (angleType == "yaw") {
        firstAngle = firstEntry.yaw;
        lastAngle = lastEntry.yaw;
    } else {
        return 0.0f;
    }

    // Calculate angular change with proper wrapping
    float angularChange = lastAngle - firstAngle;

    // Handle angle wrapping (transition through ±180 degrees)
    if (angularChange > 180.0f) {
        angularChange -= 360.0f;
    } else if (angularChange < -180.0f) {
        angularChange += 360.0f;
    }

    // Calculate time difference in seconds
    qint64 timeDiff = lastEntry.time - firstEntry.time;
    float timeDiffSec = static_cast<float>(timeDiff) / 1000.0f;

    if (timeDiffSec <= 0) return 0.0f;

    // Calculate angular speed in degrees per second
    float speedDegPerSec = angularChange / timeDiffSec;

    // Apply reasonable limits
    const float maxSpeed = 180.0f;
    speedDegPerSec = qBound(-maxSpeed, speedDegPerSec, maxSpeed);

    return speedDegPerSec;
}

void LogReader::setSmoothingWindow(float windowSeconds)
{
    windowSeconds = qBound(0.1f, windowSeconds, 3.0f);
    if (!qFuzzyCompare(m_smoothingWindow, windowSeconds)) {
        m_smoothingWindow = windowSeconds;
        emit smoothingWindowChanged(m_smoothingWindow);
    }
}
