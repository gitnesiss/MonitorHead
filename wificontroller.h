#ifndef WIFICONTROLLER_H
#define WIFICONTROLLER_H

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtNetwork/QTcpSocket>
#include <QtCore/QByteArray>

class WifiController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString ip READ ip WRITE setIp NOTIFY ipChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit WifiController(QObject *parent = nullptr);
    ~WifiController();

    bool connected() const { return m_connected; }
    QString ip() const { return m_ip; }
    int port() const { return m_port; }
    QString status() const { return m_status; }

    QByteArray readData();
    bool hasData() const { return !m_buffer.isEmpty(); }

public slots:
    void connectToDevice();
    void disconnectFromDevice();
    void setIp(const QString &ip);
    void setPort(int port);

signals:
    void connectedChanged(bool connected);
    void ipChanged(const QString &ip);
    void portChanged(int port);
    void statusChanged(const QString &status);
    void dataReceived(const QByteArray &data);
    void errorOccurred(const QString &error);

private slots:
    void onConnected();
    void onDisconnected();
    void onErrorOccurred(QAbstractSocket::SocketError error);
    void onReadyRead();
    void onStateChanged(QAbstractSocket::SocketState state);
    void attemptReconnect();

private:
    QTcpSocket *m_socket;
    bool m_connected;
    QString m_ip;
    int m_port;
    QString m_status;
    QByteArray m_buffer;
    QTimer m_reconnectTimer;
    bool m_autoReconnect;

    void setupSocket();
    void cleanupSocket();
    void updateStatus(const QString &status);
};

#endif // WIFICONTROLLER_H
