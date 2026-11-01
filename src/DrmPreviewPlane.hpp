#pragma once

#include <QJsonObject>
#include <QString>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>
#include <unordered_map>

// APERTAR_PREVIEW_PLANE=1: the live picture goes to the DRM primary plane straight from the camera
// dma-buf (scanned out by the display controller, no GPU), and the Qt UI moves to an ARGB overlay plane
// above it. configureQt() sets that up before QGuiApplication exists; the instance then owns the primary
// plane, which Qt never writes in that mode.
class DrmPreviewPlane
{
public:
    struct Topology
    {
        QString connector;               // e.g. HDMI-A-1
        uint32_t crtcId = 0;
        int crtcIndex = -1;              // bit in the planes' possible_crtcs
        uint32_t primaryPlaneId = 0;
        uint32_t overlayPlaneId = 0;     // 0 when none was looked for or found
    };

    struct Placement
    {
        int dstX = 0, dstY = 0, dstW = 0, dstH = 0;     // window pixels
        double srcX = 0.0, srcY = 0.0, srcW = 0.0, srcH = 0.0;   // buffer pixels
        bool rotate180 = false;

        bool operator==(const Placement &o) const
        {
            return dstX == o.dstX && dstY == o.dstY && dstW == o.dstW && dstH == o.dstH
                && srcX == o.srcX && srcY == o.srcY && srcW == o.srcW && srcH == o.srcH
                && rotate180 == o.rotate180;
        }
    };

    // Before QGuiApplication: probe, then set the QT_QPA_EGLFS_KMS_* environment for an atomic ARGB overlay.
    // Returns false (and changes nothing) if anything fails. The caller also sets the alpha buffer size.
    static bool configureQt();
    static bool qtConfigured();
    // The one instance for the main window: null unless configureQt() succeeded, and null for any later caller.
    static std::unique_ptr<DrmPreviewPlane> create();

    // The KMS config with outputs[connector].format = "argb8888" added; every other key is kept.
    static QJsonObject kmsConfigWithOutput(QJsonObject config, const QString &connector);

    DrmPreviewPlane();
    ~DrmPreviewPlane();
    DrmPreviewPlane(const DrmPreviewPlane &) = delete;
    DrmPreviewPlane &operator=(const DrmPreviewPlane &) = delete;

    // After the window exists: Qt's DRM fd, the primary plane and its colour properties.
    bool attach();

    // Queue this buffer for the primary plane (newest wins). False means the plane cannot be used; fall back to the GPU.
    // frameSerial changes with every new preview frame; the same serial and placement again is not queued twice.
    bool show(int dmabufFd, uint64_t bufferKey, uint64_t frameSerial, unsigned int width, unsigned int height,
              unsigned int stride, const Placement &placement);
    // Queue disabling the plane (fb 0) so the GPU picture is visible.
    void hide();
    // Disable the plane, then drop every cached framebuffer and GEM handle.
    void releaseBuffers();
    bool failed() const;

private:
    struct CachedBuffer
    {
        uint32_t handle = 0;
        uint32_t fb = 0;
        unsigned int width = 0;
        unsigned int height = 0;
        unsigned int stride = 0;
    };

    struct Job
    {
        uint32_t fb = 0;                 // 0 disables the plane
        Placement placement;
    };

    static std::optional<Topology> probe(int fd, bool wantOverlay, QString *why);

    void displayLoop();
    bool applyJob(const Job &job);
    void warnOnce(int bit, const QString &text);
    bool setEnumProperty(uint32_t objectId, uint32_t objectType, const char *name, const char *value);
    void dropBuffersLocked();

    int m_fd = -1;                       // Qt's DRM fd, not ours to close
    uint32_t m_crtcId = 0;
    uint32_t m_primaryPlaneId = 0;
    uint32_t m_rotationProp = 0;
    uint64_t m_rotate0 = 1;
    uint64_t m_rotate180 = 4;
    bool m_rotationApplied180 = false;
    bool m_attached = false;
    bool m_showing = false;              // last thing queued from the render thread was a picture
    uint64_t m_lastKey = 0;
    uint64_t m_lastSerial = 0;
    Placement m_lastPlacement;

    std::mutex m_mutex;
    std::condition_variable m_cv;
    std::optional<Job> m_pending;
    bool m_busy = false;                 // the display thread is inside SetPlane
    bool m_stop = false;
    std::atomic<bool> m_failed{false};
    std::atomic<int> m_warned{0};
    std::unordered_map<uint64_t, CachedBuffer> m_buffers;
    std::thread m_thread;
};
