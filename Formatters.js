// Formatters.js
.pragma library

// Форматирование значения угла
function formatValue(value, hasData) {
    return hasData ? value.toFixed(1) + "°" : "нет данных"
}

// Форматирование угловой скорости
function formatSpeed(value, hasData) {
    return hasData ? value.toFixed(1) + "°/с" : "нет данных"
}

// Форматирование времени исследования с миллисекундами
function formatResearchTime(milliseconds, totalMilliseconds) {
    if (milliseconds === undefined || totalMilliseconds === undefined) {
        return "00:00:00:000";
    }

    var roundedMs = Math.round(milliseconds);

    var hours = Math.floor(roundedMs / 3600000);
    var minutes = Math.floor((roundedMs % 3600000) / 60000);
    var seconds = Math.floor((roundedMs % 60000) / 1000);
    var ms = roundedMs % 1000;

    var hoursStr = hours.toString().padStart(2, '0');
    var minutesStr = minutes.toString().padStart(2, '0');
    var secondsStr = seconds.toString().padStart(2, '0');
    var msStr = ms.toString().padStart(3, '0');

    return hoursStr + ":" + minutesStr + ":" + secondsStr + ":" + msStr;
}

// Форматирование времени для графиков
function formatGraphTime(milliseconds) {
    var seconds = milliseconds / 1000;
    return seconds.toFixed(0) + "с";
}

// Форматирование информации об исследовании
function formatStudyInfo(studyInfo) {
    if (!studyInfo) return "Исследование не загружено";

    var cleaned = studyInfo.replace(/#+/g, '').trim();

    var parts = cleaned.split('|').map(function(part) {
        return part.trim();
    }).filter(function(part) {
        return part.length > 0;
    });

    var researchNumber = "";
    var researchDate = "";

    for (var i = 0; i < parts.length; i++) {
        var part = parts[i];
        if (part.includes("Исследование №")) {
            researchNumber = part;
        } else if (part.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)) {
            researchDate = part;
        }
    }

    if (researchNumber && researchDate) {
        return researchNumber + " [" + researchDate + "]";
    } else if (researchNumber) {
        return researchNumber;
    } else if (researchDate) {
        return "Исследование [" + researchDate + "]";
    } else {
        return cleaned || "Исследование не загружено";
    }
}

// Форматирование времени без миллисекунд
function formatTimeWithoutMs(milliseconds, totalMilliseconds) {
    if (milliseconds === undefined || totalMilliseconds === undefined) {
        return "00:00:00";
    }

    var roundedMs = Math.round(milliseconds);

    var hours = Math.floor(roundedMs / 3600000);
    var minutes = Math.floor((roundedMs % 3600000) / 60000);
    var seconds = Math.floor((roundedMs % 60000) / 1000);

    var hoursStr = hours.toString().padStart(2, '0');
    var minutesStr = minutes.toString().padStart(2, '0');
    var secondsStr = seconds.toString().padStart(2, '0');

    return hoursStr + ":" + minutesStr + ":" + secondsStr;
}

// Форматирование текущего и общего времени
function formatCurrentAndTotalTime(currentMs, totalMs) {
    return formatTimeWithoutMs(currentMs, totalMs) + " / " + formatTimeWithoutMs(totalMs, totalMs);
}

// Проверка возможности отображения угловой скорости
function canDisplayAngularSpeed(connected, logMode, logLoaded, hasData) {
    return hasData && ((connected && !logMode) || (logMode && logLoaded));
}

// Получение форматированной угловой скорости
function getFormattedSpeed(speedValue, connected, logMode, logLoaded, hasData) {
    if (canDisplayAngularSpeed(connected, logMode, logLoaded, hasData)) {
        return formatSpeed(speedValue, true);
    }
    return "нет данных";
}