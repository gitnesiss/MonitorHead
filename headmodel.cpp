#include "headmodel.h"
#include <QtMath>

HeadModel::HeadModel(QObject *parent) : QObject(parent)
{
}

void HeadModel::setPitch(float pitch)
{
    if (!qFuzzyCompare(m_pitch, pitch)) {
        m_pitch = pitch;
        emit pitchChanged(m_pitch);
    }
}

void HeadModel::setRoll(float roll)
{
    if (!qFuzzyCompare(m_roll, roll)) {
        m_roll = roll;
        emit rollChanged(m_roll);
    }
}

void HeadModel::setYaw(float yaw)
{
    if (!qFuzzyCompare(m_yaw, yaw)) {
        m_yaw = yaw;
        emit yawChanged(m_yaw);
    }
}

void HeadModel::setSpeedPitch(float speedPitch)
{
    if (!qFuzzyCompare(m_speedPitch, speedPitch)) {
        m_speedPitch = speedPitch;
        emit speedPitchChanged(m_speedPitch);
    }
}

void HeadModel::setSpeedRoll(float speedRoll)
{
    if (!qFuzzyCompare(m_speedRoll, speedRoll)) {
        m_speedRoll = speedRoll;
        emit speedRollChanged(m_speedRoll);
    }
}

void HeadModel::setSpeedYaw(float speedYaw)
{
    if (!qFuzzyCompare(m_speedYaw, speedYaw)) {
        m_speedYaw = speedYaw;
        emit speedYawChanged(m_speedYaw);
    }
}

void HeadModel::setDizziness(bool dizziness)
{
    if (m_dizziness != dizziness) {
        m_dizziness = dizziness;
        emit dizzinessChanged(m_dizziness);
    }
}

void HeadModel::setHasData(bool hasData)
{
    if (m_hasData != hasData) {
        m_hasData = hasData;
        emit hasDataChanged(m_hasData);
    }
}

void HeadModel::setRotation(float pitch, float roll, float yaw)
{
    setPitch(pitch);
    setRoll(roll);
    setYaw(yaw);
    setHasData(true);
}

void HeadModel::setMotionData(float pitch, float roll, float yaw, float speedPitch, float speedRoll, float speedYaw, bool dizziness)
{
    setPitch(pitch);
    setRoll(roll);
    setYaw(yaw);
    setSpeedPitch(speedPitch);
    setSpeedRoll(speedRoll);
    setSpeedYaw(speedYaw);
    setDizziness(dizziness);
    setHasData(true);
}

void HeadModel::resetData()
{
    setPitch(0.0f);
    setRoll(0.0f);
    setYaw(0.0f);
    setSpeedPitch(0.0f);
    setSpeedRoll(0.0f);
    setSpeedYaw(0.0f);
    setDizziness(false);
    setHasData(false);  // Важно: устанавливаем флаг отсутствия данных
}

QMatrix4x4 HeadModel::transformationMatrix() const
{
    QMatrix4x4 matrix;
    matrix.rotate(m_yaw, 0.0f, 1.0f, 0.0f);
    matrix.rotate(m_pitch, 1.0f, 0.0f, 0.0f);
    matrix.rotate(m_roll, 0.0f, 0.0f, 1.0f);
    return matrix;
}
