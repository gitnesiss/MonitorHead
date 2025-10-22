#ifndef HEADMODEL_H
#define HEADMODEL_H

#include <QObject>
#include <QVector3D>
#include <QMatrix4x4>

class HeadModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(float pitch READ pitch WRITE setPitch NOTIFY pitchChanged)
    Q_PROPERTY(float roll READ roll WRITE setRoll NOTIFY rollChanged)
    Q_PROPERTY(float yaw READ yaw WRITE setYaw NOTIFY yawChanged)
    Q_PROPERTY(float speedPitch READ speedPitch WRITE setSpeedPitch NOTIFY speedPitchChanged)
    Q_PROPERTY(float speedRoll READ speedRoll WRITE setSpeedRoll NOTIFY speedRollChanged)
    Q_PROPERTY(float speedYaw READ speedYaw WRITE setSpeedYaw NOTIFY speedYawChanged)
    Q_PROPERTY(bool dizziness READ dizziness WRITE setDizziness NOTIFY dizzinessChanged)
    Q_PROPERTY(bool hasData READ hasData WRITE setHasData NOTIFY hasDataChanged)

public:
    explicit HeadModel(QObject *parent = nullptr);

    float pitch() const { return m_pitch; }
    float roll() const { return m_roll; }
    float yaw() const { return m_yaw; }
    float speedPitch() const { return m_speedPitch; }
    float speedRoll() const { return m_speedRoll; }
    float speedYaw() const { return m_speedYaw; }
    bool dizziness() const { return m_dizziness; }
    bool hasData() const { return m_hasData; }

    QMatrix4x4 transformationMatrix() const;

public slots:
    void setPitch(float pitch);
    void setRoll(float roll);
    void setYaw(float yaw);
    void setSpeedPitch(float speedPitch);
    void setSpeedRoll(float speedRoll);
    void setSpeedYaw(float speedYaw);
    void setDizziness(bool dizziness);
    void setHasData(bool hasData);
    void setRotation(float pitch, float roll, float yaw);
    void setMotionData(float pitch, float roll, float yaw, float speedPitch, float speedRoll, float speedYaw, bool dizziness);
    void resetData();

signals:
    void pitchChanged(float pitch);
    void rollChanged(float roll);
    void yawChanged(float yaw);
    void speedPitchChanged(float speedPitch);
    void speedRollChanged(float speedRoll);
    void speedYawChanged(float speedYaw);
    void dizzinessChanged(bool dizziness);
    void hasDataChanged(bool hasData);

private:
    float m_pitch = 0.0f;
    float m_roll = 0.0f;
    float m_yaw = 0.0f;
    float m_speedPitch = 0.0f;
    float m_speedRoll = 0.0f;
    float m_speedYaw = 0.0f;
    bool m_dizziness = false;
    bool m_hasData = false;
};

#endif // HEADMODEL_H
