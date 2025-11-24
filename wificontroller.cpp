#include "wificontroller.h"
#include <QDebug>

WifiController::WifiController(QObject *parent)
    : QObject(parent)
    , m_socket(nullptr)
    , m_connected(false)
    , m_ip("192.168.4.1")
    , m_port(8080)
    , m_status("Не подключено")
    , m_autoReconnect(true)
{
    m_socket = new QTcpSocket(this);
    setupSocket();

    m_reconnectTimer.setInterval(5000);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &WifiController::attemptReconnect);
}

WifiController::~WifiController()
{
    cleanupSocket();
}

void WifiController::setupSocket()
{
    connect(m_socket, &QTcpSocket::connected, this, &WifiController::onConnected);
    connect(m_socket, &QTcpSocket::disconnected, this, &WifiController::onDisconnected);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &WifiController::onErrorOccurred);
    connect(m_socket, &QTcpSocket::readyRead, this, &WifiController::onReadyRead);
    connect(m_socket, &QTcpSocket::stateChanged, this, &WifiController::onStateChanged);
}

void WifiController::cleanupSocket()
{
    m_reconnectTimer.stop();

    if (m_socket) {
        disconnect(m_socket, nullptr, this, nullptr);
        if (m_socket->state() != QAbstractSocket::UnconnectedState) {
            m_socket->disconnectFromHost();
            if (m_socket->state() != QAbstractSocket::UnconnectedState) {
                m_socket->waitForDisconnected(1000);
            }
        }
    }
}

void WifiController::setIp(const QString &ip)
{
    if (m_ip != ip) {
        m_ip = ip;
        emit ipChanged(m_ip);

        // Переподключаемся если уже подключены
        if (m_connected) {
            disconnectFromDevice();
            QTimer::singleShot(1000, this, &WifiController::connectToDevice);
        }
    }
}

void WifiController::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged(m_port);

        // Переподключаемся если уже подключены
        if (m_connected) {
            disconnectFromDevice();
            QTimer::singleShot(1000, this, &WifiController::connectToDevice);
        }
    }
}

void WifiController::connectToDevice()
{
    if (m_connected || m_socket->state() == QAbstractSocket::ConnectingState) {
        return;
    }

    if (m_ip.isEmpty()) {
        updateStatus("Ошибка: IP-адрес не указан");
        emit errorOccurred("IP-адрес не указан");
        return;
    }

    if (m_port <= 0 || m_port > 65535) {
        updateStatus("Ошибка: неверный порт");
        emit errorOccurred("Неверный порт");
        return;
    }

    updateStatus("Подключение к " + m_ip + ":" + QString::number(m_port));
    m_socket->connectToHost(m_ip, m_port);

    // Таймаут подключения
    QTimer::singleShot(10000, this, [this]() {
        if (m_socket->state() == QAbstractSocket::ConnectingState) {
            updateStatus("Таймаут подключения");
            m_socket->abort();
        }
    });
}

void WifiController::disconnectFromDevice()
{
    m_autoReconnect = false;
    m_reconnectTimer.stop();

    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->disconnectFromHost();
    }

    m_connected = false;
    m_buffer.clear();
    updateStatus("Отключено");
    emit connectedChanged(m_connected);
}

void WifiController::onConnected()
{
    m_connected = true;
    m_autoReconnect = true;
    m_reconnectTimer.stop();
    updateStatus("Подключено к " + m_ip + ":" + QString::number(m_port));
    emit connectedChanged(m_connected);
}

void WifiController::onDisconnected()
{
    m_connected = false;
    updateStatus("Отключено от устройства");
    emit connectedChanged(m_connected);

    if (m_autoReconnect) {
        m_reconnectTimer.start();
        updateStatus("Переподключение через 5 секунд...");
    }
}

void WifiController::onErrorOccurred(QAbstractSocket::SocketError error)
{
    QString errorString;
    switch (error) {
    case QAbstractSocket::ConnectionRefusedError:
        errorString = "Соединение отклонено устройством";
        break;
    case QAbstractSocket::RemoteHostClosedError:
        errorString = "Устройство закрыло соединение";
        break;
    case QAbstractSocket::HostNotFoundError:
        errorString = "Устройство не найдено: " + m_ip;
        break;
    case QAbstractSocket::SocketTimeoutError:
        errorString = "Таймаут подключения";
        break;
    case QAbstractSocket::NetworkError:
        errorString = "Ошибка сети";
        break;
    default:
        errorString = "Ошибка Wi-Fi: " + m_socket->errorString();
        break;
    }

    updateStatus("Ошибка: " + errorString);
    emit errorOccurred(errorString);
}

void WifiController::onReadyRead()
{
    QByteArray data = m_socket->readAll();
    if (!data.isEmpty()) {
        m_buffer.append(data);

        // Ограничиваем размер буфера
        if (m_buffer.size() > 2048) {
            m_buffer = m_buffer.right(1024);
        }

        emit dataReceived(data);
    }
}

void WifiController::onStateChanged(QAbstractSocket::SocketState state)
{
    switch (state) {
    case QAbstractSocket::UnconnectedState:
        updateStatus("Не подключено");
        break;
    case QAbstractSocket::HostLookupState:
        updateStatus("Поиск устройства...");
        break;
    case QAbstractSocket::ConnectingState:
        updateStatus("Подключение...");
        break;
    case QAbstractSocket::ConnectedState:
        updateStatus("Подключено");
        break;
    case QAbstractSocket::ClosingState:
        updateStatus("Закрытие соединения...");
        break;
    default:
        break;
    }
}

void WifiController::attemptReconnect()
{
    if (!m_connected && m_autoReconnect) {
        updateStatus("Попытка переподключения...");
        connectToDevice();
    }
}

void WifiController::updateStatus(const QString &status)
{
    if (m_status != status) {
        m_status = status;
        emit statusChanged(m_status);
        qDebug() << "Wi-Fi Status:" << status;
    }
}

QByteArray WifiController::readData()
{
    QByteArray data = m_buffer;
    m_buffer.clear();
    return data;
}
