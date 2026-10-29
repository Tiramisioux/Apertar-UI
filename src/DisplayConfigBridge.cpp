#include "DisplayConfigBridge.hpp"

#include <QFileInfo>
#include <QSettings>
#include <QStringList>
#include <QVariant>
#include <QtGlobal>

namespace {

constexpr int kDefaultUiWidth = 1920;
constexpr int kDefaultUiHeight = 1080;
constexpr int kDefaultUiRotationDegrees = 0;
constexpr double kDefaultControlsOpacity = 1.0;
constexpr double kDefaultZoomToggleFactor = 4.0;

QString defaultHardwareConfigPath()
{
    return QStringLiteral("/home/pi/apertar-hardware.conf");
}

QStringList hardwareConfigCandidatePaths()
{
    QStringList candidates;

    const QString envPath = qEnvironmentVariable("APERTAR_HARDWARE_CONFIG").trimmed();
    if (!envPath.isEmpty())
        candidates.push_back(envPath);

    candidates.push_back(defaultHardwareConfigPath());
    candidates.push_back(QStringLiteral("/boot/firmware/apertar-hardware.conf"));
    candidates.push_back(QStringLiteral("/boot/apertar-hardware.conf"));

    candidates.removeDuplicates();
    return candidates;
}

QString unquote(QString value)
{
    value = value.trimmed();
    if (value.size() >= 2 &&
        ((value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"'))) ||
         (value.startsWith(QLatin1Char('\'')) && value.endsWith(QLatin1Char('\''))))) {
        return value.mid(1, value.size() - 2).trimmed();
    }
    return value;
}

bool parseConfigInteger(const QVariant &value, int *parsed)
{
    if (!parsed || !value.isValid())
        return false;

    bool ok = false;
    const int direct = value.toInt(&ok);
    if (ok) {
        *parsed = direct;
        return true;
    }

    const int converted = unquote(value.toString()).toInt(&ok, 0);
    if (!ok)
        return false;

    *parsed = converted;
    return true;
}

int readConfigInteger(const QSettings &settings,
                      const QStringList &keys,
                      int fallback,
                      int minimum,
                      int maximum)
{
    for (const QString &key : keys) {
        if (!settings.contains(key))
            continue;

        int parsed = fallback;
        if (!parseConfigInteger(settings.value(key), &parsed))
            continue;

        return qBound(minimum, parsed, maximum);
    }

    return fallback;
}

bool parseConfigDouble(const QVariant &value, double *parsed)
{
    if (!parsed || !value.isValid())
        return false;

    bool ok = false;
    const double direct = value.toDouble(&ok);
    if (ok) {
        *parsed = direct;
        return true;
    }

    const double converted = unquote(value.toString()).toDouble(&ok);
    if (!ok)
        return false;

    *parsed = converted;
    return true;
}

double readConfigDouble(const QSettings &settings,
                        const QStringList &keys,
                        double fallback,
                        double minimum,
                        double maximum)
{
    for (const QString &key : keys) {
        if (!settings.contains(key))
            continue;

        double parsed = fallback;
        if (!parseConfigDouble(settings.value(key), &parsed) || !qIsFinite(parsed))
            continue;

        return qBound(minimum, parsed, maximum);
    }

    return fallback;
}

bool parseConfigBool(QString value, bool *ok)
{
    value = unquote(value).toLower();
    if (value == QStringLiteral("true") || value == QStringLiteral("yes") ||
        value == QStringLiteral("on") || value == QStringLiteral("1")) {
        if (ok)
            *ok = true;
        return true;
    }

    if (value == QStringLiteral("false") || value == QStringLiteral("no") ||
        value == QStringLiteral("off") || value == QStringLiteral("0")) {
        if (ok)
            *ok = true;
        return false;
    }

    if (ok)
        *ok = false;
    return false;
}

bool readConfigBool(const QSettings &settings,
                    const QStringList &keys,
                    bool fallback)
{
    for (const QString &key : keys) {
        if (!settings.contains(key))
            continue;

        bool parsed = false;
        const bool value = parseConfigBool(settings.value(key).toString(), &parsed);
        if (parsed)
            return value;
    }

    return fallback;
}

QString readConfigString(const QSettings &settings,
                         const QStringList &keys,
                         const QString &fallback)
{
    for (const QString &key : keys) {
        if (!settings.contains(key))
            continue;

        const QString value = unquote(settings.value(key).toString());
        if (!value.isEmpty())
            return value;
    }

    return fallback;
}

QString normalizedLayout(QString layout, int width, int height)
{
    layout = unquote(layout).trimmed().toLower();
    layout.replace(QLatin1Char('-'), QLatin1Char('_'));
    layout.replace(QLatin1Char(' '), QLatin1Char('_'));

    if (layout == QStringLiteral("square") ||
        layout == QStringLiteral("landscape_compact") ||
        layout == QStringLiteral("landscape_medium") ||
        layout == QStringLiteral("landscape") ||
        layout == QStringLiteral("landscape_large") ||
        layout == QStringLiteral("portrait_compact") ||
        layout == QStringLiteral("portrait") ||
        layout == QStringLiteral("portrait_large")) {
        return layout;
    }

    if (layout == QStringLiteral("landscape_small") || layout == QStringLiteral("small_landscape"))
        return QStringLiteral("landscape_compact");
    if (layout == QStringLiteral("medium_landscape"))
        return QStringLiteral("landscape_medium");
    if (layout == QStringLiteral("large_landscape"))
        return QStringLiteral("landscape_large");
    if (layout == QStringLiteral("compact") || layout == QStringLiteral("small"))
        return width > height ? QStringLiteral("landscape_compact") : QStringLiteral("portrait_compact");
    if (layout == QStringLiteral("small_portrait"))
        return QStringLiteral("portrait_compact");
    if (layout == QStringLiteral("large_portrait"))
        return QStringLiteral("portrait_large");

    if (width == height)
        return QStringLiteral("square");

    if (height > width) {
        if (width <= 540 || height <= 720)
            return QStringLiteral("portrait_compact");
        if (width >= 1000 || height >= 1800)
            return QStringLiteral("portrait_large");
        return QStringLiteral("portrait");
    }

    if (width > height) {
        if (height <= 540 || width <= 720)
            return QStringLiteral("landscape_compact");
        if (width >= 1800 || height >= 1000)
            return QStringLiteral("landscape_large");
        return QStringLiteral("landscape_medium");
    }

    return QStringLiteral("square");
}

int normalizedUiRotationDegrees(QString rotation)
{
    rotation = unquote(rotation).trimmed().toLower();
    rotation.replace(QLatin1Char('-'), QLatin1Char('_'));
    rotation.replace(QLatin1Char(' '), QLatin1Char('_'));

    if (rotation == QStringLiteral("left") ||
        rotation == QStringLiteral("left_side") ||
        rotation == QStringLiteral("counter_clockwise") ||
        rotation == QStringLiteral("counterclockwise") ||
        rotation == QStringLiteral("ccw") ||
        rotation == QStringLiteral("90") ||
        rotation == QStringLiteral("90deg") ||
        rotation == QStringLiteral("90_degrees")) {
        return 90;
    }

    if (rotation == QStringLiteral("right") ||
        rotation == QStringLiteral("right_side") ||
        rotation == QStringLiteral("clockwise") ||
        rotation == QStringLiteral("cw") ||
        rotation == QStringLiteral("-90") ||
        rotation == QStringLiteral("-90deg") ||
        rotation == QStringLiteral("-90_degrees") ||
        rotation == QStringLiteral("270") ||
        rotation == QStringLiteral("270deg") ||
        rotation == QStringLiteral("270_degrees")) {
        return -90;
    }

    if (rotation == QStringLiteral("upside_down") ||
        rotation == QStringLiteral("inverted") ||
        rotation == QStringLiteral("180") ||
        rotation == QStringLiteral("180deg") ||
        rotation == QStringLiteral("180_degrees")) {
        return 180;
    }

    return 0;
}

} // namespace

DisplayConfigBridge::DisplayConfigBridge(QObject *parent)
    : QObject(parent)
{
    loadConfiguration();
}

void DisplayConfigBridge::loadConfiguration()
{
    m_uiWidth = kDefaultUiWidth;
    m_uiHeight = kDefaultUiHeight;
    m_uiLayout = QStringLiteral("landscape_large");
    m_uiRotationDegrees = kDefaultUiRotationDegrees;
    m_controlsOpacity = kDefaultControlsOpacity;
    m_zoomToggleFactor = kDefaultZoomToggleFactor;
    m_windowed = false;
    m_hdmiExternalOnly = true;
    m_configPath.clear();

    const QStringList candidates = hardwareConfigCandidatePaths();
    for (const QString &path : candidates) {
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile())
            continue;

        QSettings settings(path, QSettings::IniFormat);
        settings.beginGroup(QStringLiteral("display"));

        m_uiWidth = readConfigInteger(settings,
                                      {QStringLiteral("ui_width"),
                                       QStringLiteral("uiWidth"),
                                       QStringLiteral("width")},
                                      kDefaultUiWidth,
                                      320,
                                      3840);
        m_uiHeight = readConfigInteger(settings,
                                       {QStringLiteral("ui_height"),
                                        QStringLiteral("uiHeight"),
                                        QStringLiteral("height")},
                                       kDefaultUiHeight,
                                       320,
                                       3840);
        const QString requestedLayout = readConfigString(settings,
                                                         {QStringLiteral("ui_layout"),
                                                          QStringLiteral("uiLayout"),
                                                          QStringLiteral("layout"),
                                                          QStringLiteral("profile")},
                                                         QStringLiteral("auto"));
        m_uiLayout = normalizedLayout(requestedLayout, m_uiWidth, m_uiHeight);
        const QString requestedRotation = readConfigString(settings,
                                                           {QStringLiteral("ui_rotation"),
                                                            QStringLiteral("uiRotation"),
                                                            QStringLiteral("rotation"),
                                                            QStringLiteral("orientation")},
                                                           QStringLiteral("normal"));
        m_uiRotationDegrees = normalizedUiRotationDegrees(requestedRotation);
        m_controlsOpacity = readConfigDouble(settings,
                                             {QStringLiteral("controls_opacity"),
                                              QStringLiteral("control_opacity"),
                                              QStringLiteral("controlsOpacity"),
                                              QStringLiteral("opacity")},
                                             kDefaultControlsOpacity,
                                             0.15,
                                             1.0);
        m_zoomToggleFactor = readConfigDouble(settings,
                                             {QStringLiteral("zoom_toggle_factor")},
                                             kDefaultZoomToggleFactor,
                                             1.0,
                                             4.0);
        m_windowed = readConfigBool(settings,
                                    {QStringLiteral("windowed"),
                                     QStringLiteral("ui_windowed"),
                                     QStringLiteral("uiWindowed"),
                                     QStringLiteral("debug_windowed"),
                                     QStringLiteral("debugWindowed")},
                                    false);
        m_hdmiExternalOnly = readConfigBool(settings,
                                           {QStringLiteral("hdmi_external_only"),
                                            QStringLiteral("hdmiExternalOnly")},
                                           true);
        settings.endGroup();
        m_configPath = path;
        break;
    }
}
