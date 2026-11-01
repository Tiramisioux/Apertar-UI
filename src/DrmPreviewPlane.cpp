#include "DrmPreviewPlane.hpp"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>

#if APERTAR_HAS_DISPLAY_POWER
#include <qpa/qplatformnativeinterface.h>
#endif

#include <fcntl.h>
#include <unistd.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <libdrm/drm_fourcc.h>
#include <libdrm/drm_mode.h>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstring>

namespace {

bool s_qtConfigured = false;
bool s_created = false;

enum WarnBit
{
    WarnPrimeHandle = 1,
    WarnAddFb = 2,
    WarnSetPlane = 4,
};

struct PropertyRef
{
    uint32_t id = 0;
    uint64_t value = 0;
    drmModePropertyRes *res = nullptr;      // null unless asked for
};

PropertyRef findProperty(int fd, uint32_t objectId, uint32_t objectType, const char *name, bool keepResource = false)
{
    PropertyRef found;
    drmModeObjectProperties *props = drmModeObjectGetProperties(fd, objectId, objectType);
    if (!props)
        return found;
    for (uint32_t i = 0; i < props->count_props && !found.id; ++i) {
        drmModePropertyRes *prop = drmModeGetProperty(fd, props->props[i]);
        if (!prop)
            continue;
        if (std::strcmp(prop->name, name) == 0) {
            found.id = prop->prop_id;
            found.value = props->prop_values[i];
            if (keepResource)
                found.res = prop;
            else
                drmModeFreeProperty(prop);
        } else {
            drmModeFreeProperty(prop);
        }
    }
    drmModeFreeObjectProperties(props);
    return found;
}

bool planeHasFormat(const drmModePlane *plane, uint32_t format)
{
    for (uint32_t i = 0; i < plane->count_formats; ++i) {
        if (plane->formats[i] == format)
            return true;
    }
    return false;
}

QString connectorName(const drmModeConnector *connector)
{
    const char *type = "Unknown";
    switch (connector->connector_type) {
    case DRM_MODE_CONNECTOR_VGA: type = "VGA"; break;
    case DRM_MODE_CONNECTOR_DVII: type = "DVI-I"; break;
    case DRM_MODE_CONNECTOR_DVID: type = "DVI-D"; break;
    case DRM_MODE_CONNECTOR_DVIA: type = "DVI-A"; break;
    case DRM_MODE_CONNECTOR_Composite: type = "Composite"; break;
    case DRM_MODE_CONNECTOR_LVDS: type = "LVDS"; break;
    case DRM_MODE_CONNECTOR_DisplayPort: type = "DP"; break;
    case DRM_MODE_CONNECTOR_HDMIA: type = "HDMI-A"; break;
    case DRM_MODE_CONNECTOR_HDMIB: type = "HDMI-B"; break;
    case DRM_MODE_CONNECTOR_eDP: type = "eDP"; break;
    case DRM_MODE_CONNECTOR_VIRTUAL: type = "Virtual"; break;
    case DRM_MODE_CONNECTOR_DSI: type = "DSI"; break;
    case DRM_MODE_CONNECTOR_DPI: type = "DPI"; break;
    default: break;
    }
    return QStringLiteral("%1-%2").arg(QLatin1String(type)).arg(connector->connector_type_id);
}

// Whole, even pixels keep the 4:2:0 chroma planes aligned; the rectangle stays inside the buffer.
void alignSource(DrmPreviewPlane::Placement &p, unsigned int width, unsigned int height)
{
    auto even = [](double v) { return std::round(v / 2.0) * 2.0; };
    p.srcW = std::clamp(even(p.srcW), 2.0, double(width & ~1u));
    p.srcH = std::clamp(even(p.srcH), 2.0, double(height & ~1u));
    p.srcX = std::clamp(even(p.srcX), 0.0, double(width & ~1u) - p.srcW);
    p.srcY = std::clamp(even(p.srcY), 0.0, double(height & ~1u) - p.srcH);
}

} // namespace

DrmPreviewPlane::DrmPreviewPlane() = default;

DrmPreviewPlane::~DrmPreviewPlane()
{
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_stop = true;
    }
    m_cv.notify_all();
    if (m_thread.joinable())
        m_thread.join();
    releaseBuffers();
}

bool DrmPreviewPlane::qtConfigured()
{
    return s_qtConfigured;
}

std::unique_ptr<DrmPreviewPlane> DrmPreviewPlane::create()
{
    if (!s_qtConfigured || s_created)
        return nullptr;
    s_created = true;
    return std::make_unique<DrmPreviewPlane>();
}

QJsonObject DrmPreviewPlane::kmsConfigWithOutput(QJsonObject config, const QString &connector)
{
    QJsonArray outputs = config.value(QStringLiteral("outputs")).toArray();
    bool found = false;
    for (int i = 0; i < outputs.size(); ++i) {
        QJsonObject output = outputs.at(i).toObject();
        if (output.value(QStringLiteral("name")).toString() == connector) {
            output.insert(QStringLiteral("format"), QStringLiteral("argb8888"));
            outputs.replace(i, output);
            found = true;
        }
    }
    if (!found) {
        QJsonObject output;
        output.insert(QStringLiteral("name"), connector);
        output.insert(QStringLiteral("format"), QStringLiteral("argb8888"));
        outputs.append(output);
    }
    config.insert(QStringLiteral("outputs"), outputs);
    return config;
}

std::optional<DrmPreviewPlane::Topology> DrmPreviewPlane::probe(int fd, bool wantOverlay, QString *why)
{
    auto fail = [&](const QString &text) -> std::optional<Topology> {
        if (why)
            *why = text;
        return std::nullopt;
    };

    if (drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1) != 0)
        return fail(QStringLiteral("no universal planes"));
    if (drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1) != 0)
        return fail(QStringLiteral("no atomic mode"));

    drmModeRes *res = drmModeGetResources(fd);
    if (!res)
        return fail(QStringLiteral("drmModeGetResources failed"));

    Topology topology;
    std::optional<Topology> result;
    drmModeConnector *connector = nullptr;
    for (int i = 0; i < res->count_connectors && !connector; ++i) {
        drmModeConnector *candidate = drmModeGetConnector(fd, res->connectors[i]);
        if (candidate && candidate->connection == DRM_MODE_CONNECTED)
            connector = candidate;
        else if (candidate)
            drmModeFreeConnector(candidate);
    }

    if (!connector) {
        drmModeFreeResources(res);
        return fail(QStringLiteral("no connected connector"));
    }
    topology.connector = connectorName(connector);

    // The CRTC the connector is driven by now; failing that, the first one its encoder can use.
    if (connector->encoder_id) {
        if (drmModeEncoder *encoder = drmModeGetEncoder(fd, connector->encoder_id)) {
            topology.crtcId = encoder->crtc_id;
            drmModeFreeEncoder(encoder);
        }
    }
    for (int i = 0; i < connector->count_encoders && !topology.crtcId; ++i) {
        drmModeEncoder *encoder = drmModeGetEncoder(fd, connector->encoders[i]);
        if (!encoder)
            continue;
        for (int c = 0; c < res->count_crtcs; ++c) {
            if (encoder->possible_crtcs & (1u << c)) {
                topology.crtcId = res->crtcs[c];
                break;
            }
        }
        drmModeFreeEncoder(encoder);
    }
    for (int c = 0; c < res->count_crtcs; ++c) {
        if (res->crtcs[c] == topology.crtcId)
            topology.crtcIndex = c;
    }
    drmModeFreeConnector(connector);
    drmModeFreeResources(res);
    if (!topology.crtcId || topology.crtcIndex < 0)
        return fail(QStringLiteral("no CRTC for %1").arg(topology.connector));

    drmModePlaneRes *planes = drmModeGetPlaneResources(fd);
    if (!planes)
        return fail(QStringLiteral("drmModeGetPlaneResources failed"));
    for (uint32_t i = 0; i < planes->count_planes; ++i) {
        drmModePlane *plane = drmModeGetPlane(fd, planes->planes[i]);
        if (!plane)
            continue;
        if (plane->possible_crtcs & (1u << topology.crtcIndex)) {
            const PropertyRef type = findProperty(fd, plane->plane_id, DRM_MODE_OBJECT_PLANE, "type");
            if (type.id && type.value == DRM_PLANE_TYPE_PRIMARY && !topology.primaryPlaneId
                && planeHasFormat(plane, DRM_FORMAT_YUV420)) {
                topology.primaryPlaneId = plane->plane_id;
            } else if (type.id && type.value == DRM_PLANE_TYPE_OVERLAY && !topology.overlayPlaneId
                       && plane->fb_id == 0 && planeHasFormat(plane, DRM_FORMAT_ARGB8888)) {
                topology.overlayPlaneId = plane->plane_id;
            }
        }
        drmModeFreePlane(plane);
    }
    drmModeFreePlaneResources(planes);

    if (!topology.primaryPlaneId)
        return fail(QStringLiteral("no YUV420 primary plane for CRTC %1").arg(topology.crtcId));
    if (wantOverlay && !topology.overlayPlaneId)
        return fail(QStringLiteral("no free ARGB8888 overlay plane for CRTC %1").arg(topology.crtcId));
    return topology;
}

bool DrmPreviewPlane::configureQt()
{
#if !APERTAR_HAS_DISPLAY_POWER
    qWarning() << "Apertar preview plane: unavailable, built without the Qt private headers (qt6-base-private-dev).";
    return false;
#else
    const QString configPath = QString::fromLocal8Bit(qgetenv("QT_QPA_EGLFS_KMS_CONFIG"));
    QJsonObject config;
    if (!configPath.isEmpty()) {
        QFile file(configPath);
        QJsonParseError parseError;
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning().noquote() << "Apertar preview plane: cannot read" << configPath << "- leaving the display as it is.";
            return false;
        }
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            qWarning().noquote() << "Apertar preview plane: cannot parse" << configPath << "- leaving the display as it is.";
            return false;
        }
        config = document.object();
    }
    QString device = config.value(QStringLiteral("device")).toString();
    if (device.isEmpty()) {
        device = QStringLiteral("/dev/dri/card1");
        config.insert(QStringLiteral("device"), device);
    }

    const int fd = ::open(device.toLocal8Bit().constData(), O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        qWarning().noquote() << "Apertar preview plane: cannot open" << device << ":" << std::strerror(errno)
                             << "- leaving the display as it is.";
        return false;
    }
    QString why;
    const std::optional<Topology> topology = probe(fd, true, &why);
    ::close(fd);
    if (!topology) {
        qWarning().noquote() << "Apertar preview plane:" << why << "- leaving the display as it is.";
        return false;
    }

    // Qt reads the output format from the KMS config; write a copy next to the original with it added.
    const QString planeConfigPath = configPath.isEmpty()
        ? QDir::temp().filePath(QStringLiteral("apertar-kms-plane.json"))
        : QFileInfo(configPath).absolutePath() + QLatin1Char('/') + QFileInfo(configPath).completeBaseName()
              + QStringLiteral("-plane.json");
    QFile planeConfig(planeConfigPath);
    const QByteArray json = QJsonDocument(kmsConfigWithOutput(config, topology->connector)).toJson();
    if (!planeConfig.open(QIODevice::WriteOnly | QIODevice::Truncate) || planeConfig.write(json) != json.size()) {
        qWarning().noquote() << "Apertar preview plane: cannot write" << planeConfigPath << "- leaving the display as it is.";
        return false;
    }
    planeConfig.close();

    qputenv("QT_QPA_EGLFS_KMS_CONFIG", planeConfigPath.toLocal8Bit());
    qputenv("QT_QPA_EGLFS_KMS_ATOMIC", QByteArrayLiteral("1"));
    qputenv("QT_QPA_EGLFS_KMS_PLANES_FOR_CRTCS",
            QStringLiteral("%1,%2").arg(topology->crtcId).arg(topology->overlayPlaneId).toLocal8Bit());
    qputenv("QT_QPA_EGLFS_KMS_ZPOS", QByteArrayLiteral("2"));
    s_qtConfigured = true;
    qInfo().noquote()
        << QStringLiteral("Apertar preview plane: UI on ARGB overlay plane %1, picture on primary plane %2 (YUV420), connector=%3 crtc=%4 config=%5")
               .arg(topology->overlayPlaneId)
               .arg(topology->primaryPlaneId)
               .arg(topology->connector)
               .arg(topology->crtcId)
               .arg(planeConfigPath);
    return true;
#endif
}

void DrmPreviewPlane::warnOnce(int bit, const QString &text)
{
    if (m_warned.fetch_or(bit) & bit)
        return;
    qWarning().noquote() << "Apertar preview plane:" << text << "- falling back to the GPU preview.";
}

bool DrmPreviewPlane::setEnumProperty(uint32_t objectId, uint32_t objectType, const char *name, const char *value)
{
    PropertyRef prop = findProperty(m_fd, objectId, objectType, name, true);
    bool ok = false;
    if (prop.id && prop.res) {
        for (int i = 0; i < prop.res->count_enums && !ok; ++i) {
            if (std::strcmp(prop.res->enums[i].name, value) == 0)
                ok = drmModeObjectSetProperty(m_fd, objectId, objectType, prop.id, prop.res->enums[i].value) == 0;
        }
    }
    if (prop.res)
        drmModeFreeProperty(prop.res);
    if (!ok)
        qWarning().noquote() << "Apertar preview plane: could not set" << name << "to" << value;
    return ok;
}

bool DrmPreviewPlane::attach()
{
    if (m_attached)
        return true;
#if APERTAR_HAS_DISPLAY_POWER
    QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
    const int fd = native ? int(qintptr(native->nativeResourceForIntegration("dri_fd"))) : -1;
    if (fd <= 0) {
        qWarning() << "Apertar preview plane: Qt gave no DRM fd - using the GPU preview.";
        return false;
    }
    QString why;
    const std::optional<Topology> topology = probe(fd, false, &why);
    if (!topology) {
        qWarning().noquote() << "Apertar preview plane:" << why << "- using the GPU preview.";
        return false;
    }
    m_fd = fd;
    m_crtcId = topology->crtcId;
    m_primaryPlaneId = topology->primaryPlaneId;

    // The camera is BT.709 limited range, the same as the EGL import hints.
    setEnumProperty(m_primaryPlaneId, DRM_MODE_OBJECT_PLANE, "COLOR_ENCODING", "ITU-R BT.709 YCbCr");
    setEnumProperty(m_primaryPlaneId, DRM_MODE_OBJECT_PLANE, "COLOR_RANGE", "YCbCr limited range");

    // "rotation" is a bitmask: the property value is 1 << the enum value.
    PropertyRef rotation = findProperty(m_fd, m_primaryPlaneId, DRM_MODE_OBJECT_PLANE, "rotation", true);
    m_rotationProp = rotation.id;
    if (rotation.res) {
        for (int i = 0; i < rotation.res->count_enums; ++i) {
            if (std::strcmp(rotation.res->enums[i].name, "rotate-0") == 0)
                m_rotate0 = 1ull << rotation.res->enums[i].value;
            else if (std::strcmp(rotation.res->enums[i].name, "rotate-180") == 0)
                m_rotate180 = 1ull << rotation.res->enums[i].value;
        }
        drmModeFreeProperty(rotation.res);
    }

    m_attached = true;
    m_thread = std::thread(&DrmPreviewPlane::displayLoop, this);
    qInfo().noquote()
        << QStringLiteral("Apertar preview plane: started, primary plane %1 on crtc %2 (%3), fb format YU12 (YUV420), rotation=%4")
               .arg(m_primaryPlaneId)
               .arg(m_crtcId)
               .arg(topology->connector)
               .arg(m_rotationProp ? QStringLiteral("yes") : QStringLiteral("no"));
    return true;
#else
    return false;
#endif
}

bool DrmPreviewPlane::failed() const
{
    return m_failed.load();
}

bool DrmPreviewPlane::show(int dmabufFd, uint64_t bufferKey, uint64_t frameSerial, unsigned int width,
                           unsigned int height, unsigned int stride, const Placement &placement)
{
    if (!m_attached || m_failed || dmabufFd < 0 || width == 0 || height == 0 || stride == 0
        || placement.dstW <= 0 || placement.dstH <= 0)
        return false;

    if (m_showing && bufferKey == m_lastKey && frameSerial == m_lastSerial && placement == m_lastPlacement)
        return true;

    uint32_t fb = 0;
    bool staleLayout = false;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto it = m_buffers.find(bufferKey);
        if (it != m_buffers.end()) {
            if (it->second.width == width && it->second.height == height && it->second.stride == stride)
                fb = it->second.fb;
            else
                staleLayout = true;
        }
    }

    if (!fb) {
        // A buffer key seen with another layout: start over, disabling the plane before any fb goes.
        if (staleLayout)
            releaseBuffers();

        CachedBuffer buffer;
        buffer.width = width;
        buffer.height = height;
        buffer.stride = stride;
        if (drmPrimeFDToHandle(m_fd, dmabufFd, &buffer.handle) != 0) {
            warnOnce(WarnPrimeHandle, QStringLiteral("drmPrimeFDToHandle failed: %1").arg(QString::fromLocal8Bit(std::strerror(errno))));
            m_failed = true;
            return false;
        }
        // The same layout as the EGL import: one dma-buf holding Y, U, V.
        const uint32_t handles[4] = { buffer.handle, buffer.handle, buffer.handle, 0 };
        const uint32_t pitches[4] = { stride, stride / 2, stride / 2, 0 };
        const uint32_t offsets[4] = { 0, stride * height, stride * height + (stride / 2) * (height / 2), 0 };
        if (drmModeAddFB2(m_fd, width, height, DRM_FORMAT_YUV420, handles, pitches, offsets, &buffer.fb, 0) != 0) {
            warnOnce(WarnAddFb, QStringLiteral("drmModeAddFB2 failed (%1x%2 stride %3): %4")
                                    .arg(width).arg(height).arg(stride).arg(QString::fromLocal8Bit(std::strerror(errno))));
            struct drm_gem_close gem = {};
            gem.handle = buffer.handle;
            drmIoctl(m_fd, DRM_IOCTL_GEM_CLOSE, &gem);
            m_failed = true;
            return false;
        }
        fb = buffer.fb;
        std::lock_guard<std::mutex> lock(m_mutex);
        m_buffers[bufferKey] = buffer;
    }

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        Job job;
        job.fb = fb;
        job.placement = placement;
        alignSource(job.placement, width, height);
        m_pending = job;     // an older pending frame is dropped here
    }
    m_cv.notify_all();
    m_showing = true;
    m_lastKey = bufferKey;
    m_lastSerial = frameSerial;
    m_lastPlacement = placement;
    return true;
}

void DrmPreviewPlane::hide()
{
    if (!m_attached || !m_showing)
        return;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_pending = Job{};
    }
    m_cv.notify_all();
    m_showing = false;
}

bool DrmPreviewPlane::applyJob(const Job &job)
{
    if (!job.fb) {
        return drmModeSetPlane(m_fd, m_primaryPlaneId, m_crtcId, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) == 0
               || errno == ENOENT;
    }

    const Placement &p = job.placement;
    const bool want180 = p.rotate180;
    if (m_rotationProp && want180 != m_rotationApplied180) {
        drmModeObjectSetProperty(m_fd, m_primaryPlaneId, DRM_MODE_OBJECT_PLANE, m_rotationProp,
                                 want180 ? m_rotate180 : m_rotate0);
        m_rotationApplied180 = want180;
    }

    return drmModeSetPlane(m_fd, m_primaryPlaneId, m_crtcId, job.fb, 0,
                           p.dstX, p.dstY, uint32_t(p.dstW), uint32_t(p.dstH),
                           uint32_t(p.srcX) << 16, uint32_t(p.srcY) << 16,
                           uint32_t(p.srcW) << 16, uint32_t(p.srcH) << 16) == 0;
}

// SetPlane blocks for about one vblank, so it runs here and never on the GUI or render thread. Only the
// newest queued frame is kept; no page-flip events are requested (Qt's fd reader would receive them).
void DrmPreviewPlane::displayLoop()
{
    std::unique_lock<std::mutex> lock(m_mutex);
    for (;;) {
        m_cv.wait(lock, [this] { return m_stop || m_pending.has_value(); });
        if (m_stop)
            return;
        const Job job = *m_pending;
        m_pending.reset();
        m_busy = true;
        lock.unlock();

        errno = 0;
        const bool ok = applyJob(job);
        const int error = errno;

        lock.lock();
        m_busy = false;
        if (!ok) {
            m_failed = true;
            warnOnce(WarnSetPlane, QStringLiteral("drmModeSetPlane failed: %1").arg(QString::fromLocal8Bit(std::strerror(error))));
        }
        m_cv.notify_all();
    }
}

void DrmPreviewPlane::dropBuffersLocked()
{
    for (auto &entry : m_buffers) {
        drmModeRmFB(m_fd, entry.second.fb);
        struct drm_gem_close gem = {};
        gem.handle = entry.second.handle;
        drmIoctl(m_fd, DRM_IOCTL_GEM_CLOSE, &gem);
    }
    m_buffers.clear();
}

void DrmPreviewPlane::releaseBuffers()
{
    if (!m_attached)
        return;
    std::unique_lock<std::mutex> lock(m_mutex);
    m_pending.reset();
    m_cv.wait(lock, [this] { return !m_busy; });
    // Nothing is scanning out of these when they go: the plane is switched off first.
    drmModeSetPlane(m_fd, m_primaryPlaneId, m_crtcId, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    dropBuffersLocked();
    m_showing = false;
}
