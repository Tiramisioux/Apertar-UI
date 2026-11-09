#pragma once

#include <QObject>
#include <QJsonObject>
#include <QLocalSocket>
#include <QSettings>
#include <QString>
#include <QTimer>
#include <QElapsedTimer>
#include <QVariantList>

class ApertarControlBridge : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(QString iso READ iso NOTIFY isoChanged)
    // Values the camera sets rather than the operator (shown green), from Core's state.
    Q_PROPERTY(int isoMax READ isoMax NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(double fpsMax READ fpsMax NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(QString fileTimecodeMode READ fileTimecodeMode NOTIFY fileTimecodeModeChanged)   // Core's timecode for the clips and the audio ("Free Run" / "Rec Run")
    Q_PROPERTY(bool ladderActive READ ladderActive NOTIFY cameraSetValuesChanged)   // the mode ladder picks the mode and the compression
    Q_PROPERTY(QString isoInUse READ isoInUse NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(QString whiteBalanceInUse READ whiteBalanceInUse NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(bool isoSetByCamera READ isoSetByCamera NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(bool whiteBalanceSetByCamera READ whiteBalanceSetByCamera NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(bool shutterSetByCamera READ shutterSetByCamera NOTIFY cameraSetValuesChanged)
    Q_PROPERTY(QString shutterAngle READ shutterAngle NOTIFY shutterAngleChanged)
    Q_PROPERTY(QString shutterSpeed READ shutterSpeed NOTIFY shutterSpeedChanged)
    Q_PROPERTY(QString whiteBalance READ whiteBalance NOTIFY whiteBalanceChanged)
    Q_PROPERTY(bool whiteBalanceAvailable READ whiteBalanceAvailable NOTIFY whiteBalanceAvailableChanged)
    Q_PROPERTY(double exposureCompensation READ exposureCompensation NOTIFY exposureCompensationChanged)
    Q_PROPERTY(bool exposureCompensationAvailable READ exposureCompensationAvailable NOTIFY exposureCompensationChanged)
    Q_PROPERTY(bool autoExposureEnabled READ autoExposureEnabled NOTIFY exposureCompensationChanged)
    Q_PROPERTY(QString exposureMetering READ exposureMetering NOTIFY exposureMeteringChanged)
    Q_PROPERTY(QVariantList exposureMeteringOptions READ exposureMeteringOptions NOTIFY exposureMeteringChanged)
    Q_PROPERTY(QString resolution READ resolution NOTIFY resolutionChanged)
    Q_PROPERTY(QString recordingFormat READ recordingFormat NOTIFY recordingFormatChanged)
    Q_PROPERTY(QString proresProfile READ proresProfile NOTIFY proresProfileChanged)
    Q_PROPERTY(QString proresColorProfile READ proresColorProfile NOTIFY proresColorProfileChanged)
    Q_PROPERTY(QString cdngPreviewColorProfile READ cdngPreviewColorProfile NOTIFY cdngPreviewColorProfileChanged)
    Q_PROPERTY(QVariantMap previewExposureReference READ previewExposureReference NOTIFY previewExposureReferenceChanged)
    Q_PROPERTY(QString cdngCompression READ cdngCompression NOTIFY cdngCompressionChanged)
    Q_PROPERTY(bool rawCompressionSupported READ rawCompressionSupported NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(bool rawRecordingSupported READ rawRecordingSupported NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(bool proresSupported READ proresSupported NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(bool h264HardwareEncoding READ h264HardwareEncoding NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(int h264MaxWidth READ h264MaxWidth NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(double h264MaxFps READ h264MaxFps NOTIFY recordingCapabilitiesChanged)
    Q_PROPERTY(QString tuningFile READ tuningFile NOTIFY tuningFileChanged)
    Q_PROPERTY(QString rawBitDepth READ rawBitDepth NOTIFY rawBitDepthChanged)
    Q_PROPERTY(bool clearHdr READ clearHdr NOTIFY clearHdrChanged)
    Q_PROPERTY(QString h264Resolution READ h264Resolution NOTIFY h264ResolutionChanged)
    Q_PROPERTY(QString sensorName READ sensorName NOTIFY sensorNameChanged)
    Q_PROPERTY(QString autofocusMode READ autofocusMode NOTIFY autofocusModeChanged)
    Q_PROPERTY(QString autofocusRange READ autofocusRange NOTIFY autofocusRangeChanged)
    Q_PROPERTY(QString autofocusSpeed READ autofocusSpeed NOTIFY autofocusSpeedChanged)
    Q_PROPERTY(QString autofocusWindow READ autofocusWindow NOTIFY autofocusWindowChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool recordingHasDroppedFrames READ recordingHasDroppedFrames NOTIFY recordingHealthChanged)
    Q_PROPERTY(int recordingDroppedFrames READ recordingDroppedFrames NOTIFY recordingHealthChanged)
    Q_PROPERTY(double bufferFill READ bufferFill NOTIFY bufferFillChanged)
    Q_PROPERTY(QString bufferMode READ bufferMode NOTIFY bufferModeChanged)
    Q_PROPERTY(bool bufferSafetyStop READ bufferSafetyStop NOTIFY bufferSafetyStopChanged)
    Q_PROPERTY(bool storagePrerollActive READ storagePrerollActive NOTIFY storagePrerollActiveChanged)
    Q_PROPERTY(bool storagePrerollAuto READ storagePrerollAuto NOTIFY storagePrerollAutoChanged)
    Q_PROPERTY(bool storagePrerollAutoKnown READ storagePrerollAutoKnown NOTIFY storagePrerollAutoKnownChanged)
    Q_PROPERTY(double storagePrerollFps READ storagePrerollFps NOTIFY storagePrerollFpsChanged)
    Q_PROPERTY(QString storagePrerollLast READ storagePrerollLast NOTIFY storagePrerollLastChanged)
    Q_PROPERTY(int bufferStopPercent READ bufferStopPercent NOTIFY bufferStopPercentChanged)
    Q_PROPERTY(QString bufferSetting READ bufferSetting NOTIFY bufferSettingChanged)
    Q_PROPERTY(int framesPerFolder READ framesPerFolder NOTIFY clipSplitChanged)
    Q_PROPERTY(bool framesPerFolderEnv READ framesPerFolderEnv NOTIFY clipSplitChanged)
    Q_PROPERTY(bool clipMergeKnown READ clipMergeKnown NOTIFY clipSplitChanged)
    Q_PROPERTY(bool clipMergeEnabled READ clipMergeEnabled NOTIFY clipSplitChanged)
    Q_PROPERTY(bool clipMergeEnvOff READ clipMergeEnvOff NOTIFY clipSplitChanged)
    Q_PROPERTY(QString clipMergeActiveClip READ clipMergeActiveClip NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(QString clipMergePaused READ clipMergePaused NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergePending READ clipMergePending NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeClipDone READ clipMergeClipDone NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeClipTotal READ clipMergeClipTotal NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeAllDone READ clipMergeAllDone NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeAllTotal READ clipMergeAllTotal NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeAllClips READ clipMergeAllClips NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(int clipMergeEtaS READ clipMergeEtaS NOTIFY clipMergeProgressChanged)
    Q_PROPERTY(QString bufferNote READ bufferNote NOTIFY bufferNoteChanged)
    Q_PROPERTY(QString clipNameTemplate READ clipNameTemplate NOTIFY clipNameChanged)
    Q_PROPERTY(QString clipNameExample READ clipNameExample NOTIFY clipNameChanged)
    Q_PROPERTY(QString clipNamePreview READ clipNamePreview NOTIFY clipNamePreviewChanged)
    Q_PROPERTY(bool clipNameKnown READ clipNameKnown NOTIFY clipNameChanged)
    Q_PROPERTY(bool cdngLogActive READ cdngLogActive NOTIFY cdngLogChanged)
    Q_PROPERTY(int cdngLogBits READ cdngLogBits NOTIFY cdngLogChanged)
    Q_PROPERTY(bool cdngLogOn READ cdngLogOn NOTIFY cdngLogChanged)
    Q_PROPERTY(bool cdngLogAvailable READ cdngLogAvailable NOTIFY cdngLogChanged)
    Q_PROPERTY(bool cdngLogApplied READ cdngLogApplied NOTIFY cdngLogChanged)
    // T45: what Core's validator finds in ~/apertar-hardware.conf (get_state, and the "controls" event after a save).
    Q_PROPERTY(int controlsErrors READ controlsErrors NOTIFY controlsStatusChanged)
    Q_PROPERTY(int controlsWarnings READ controlsWarnings NOTIFY controlsStatusChanged)
    Q_PROPERTY(bool standby READ standby NOTIFY standbyChanged)
    Q_PROPERTY(bool timelapseActive READ timelapseActive NOTIFY timelapseActiveChanged)
    Q_PROPERTY(qulonglong timelapseShotCount READ timelapseShotCount NOTIFY timelapseShotCountChanged)
    Q_PROPERTY(bool stillExposureActive READ stillExposureActive NOTIFY stillExposureChanged)
    Q_PROPERTY(bool mediaWritesPending READ mediaWritesPending NOTIFY mediaWritesPendingChanged)
    Q_PROPERTY(double stillExposureRemainingSeconds READ stillExposureRemainingSeconds NOTIFY stillExposureChanged)
    Q_PROPERTY(int audioInputLevel READ audioInputLevel NOTIFY audioInputLevelChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit ApertarControlBridge(QObject *parent = nullptr);

    QString fps() const;
    QString iso() const;
    QString shutterAngle() const;
    QString shutterSpeed() const;
    QString whiteBalance() const;
    bool whiteBalanceAvailable() const { return m_whiteBalanceAvailable; }
    int isoMax() const { return m_isoMax; }
    double fpsMax() const { return m_fpsMax; }
    bool ladderActive() const { return m_ladderActive; }
    QString fileTimecodeMode() const { return m_fileTimecodeMode; }
    QString isoInUse() const { return m_isoInUse; }
    QString whiteBalanceInUse() const { return m_whiteBalanceInUse; }
    bool isoSetByCamera() const { return m_isoSetByCamera; }
    bool whiteBalanceSetByCamera() const { return m_whiteBalanceSetByCamera; }
    bool shutterSetByCamera() const { return m_shutterSetByCamera; }
    double exposureCompensation() const { return m_exposureCompensation; }
    bool exposureCompensationAvailable() const { return m_exposureCompensationAvailable; }
    bool autoExposureEnabled() const { return m_isoAuto || m_shutterAuto; }
    QString exposureMetering() const { return m_exposureMetering; }
    QVariantList exposureMeteringOptions() const { return m_exposureMeteringOptions; }
    QString resolution() const;
    QString recordingFormat() const;
    QString proresProfile() const { return m_proresProfile; }
    QString proresColorProfile() const { return m_proresColorProfile; }
    QString cdngPreviewColorProfile() const { return m_cdngPreviewColorProfile; }
    QVariantMap previewExposureReference() const { return m_previewExposureReference; }
    QString cdngCompression() const { return m_cdngCompression; }
    bool rawCompressionSupported() const { return m_rawCompressionSupported; }
    bool rawRecordingSupported() const { return m_rawRecordingSupported; }
    bool proresSupported() const { return m_proresSupported; }
    bool h264HardwareEncoding() const { return m_h264HardwareEncoding; }
    int h264MaxWidth() const { return m_h264MaxWidth; }
    double h264MaxFps() const { return m_h264MaxFps; }
    QString tuningFile() const { return m_tuningFile; }
    QString rawBitDepth() const;
    bool clearHdr() const { return m_clearHdr; }
    QString h264Resolution() const;
    QString sensorName() const;
    QString autofocusMode() const;
    QString autofocusRange() const;
    QString autofocusSpeed() const;
    QString autofocusWindow() const;
    bool recording() const;
    bool recordingHasDroppedFrames() const { return m_recordingHasDroppedFrames; }
    int recordingDroppedFrames() const { return m_recordingDroppedFrames; }
    double bufferFill() const { return m_bufferFill; }
    QString bufferMode() const { return m_bufferMode; }
    bool bufferSafetyStop() const { return m_bufferSafetyStop; }
    bool storagePrerollActive() const { return m_storagePrerollActive; }
    bool storagePrerollAuto() const { return m_storagePrerollAuto; }
    bool storagePrerollAutoKnown() const { return m_storagePrerollAutoKnown; }
    double storagePrerollFps() const { return m_storagePrerollFps; }
    QString storagePrerollLast() const { return m_storagePrerollLast; }
    int bufferStopPercent() const { return m_bufferStopPercent; }
    QString bufferSetting() const { return m_bufferSetting; }
    int framesPerFolder() const { return m_framesPerFolder; }
    bool framesPerFolderEnv() const { return m_framesPerFolderEnv; }
    bool clipMergeKnown() const { return m_clipMergeKnown; }
    bool clipMergeEnabled() const { return m_clipMergeEnabled; }
    bool clipMergeEnvOff() const { return m_clipMergeEnvOff; }
    QString clipMergeActiveClip() const { return m_clipMergeActiveClip; }
    QString clipMergePaused() const { return m_clipMergePaused; }
    int clipMergePending() const { return m_clipMergePending; }
    int clipMergeClipDone() const { return m_clipMergeClipDone; }
    int clipMergeClipTotal() const { return m_clipMergeClipTotal; }
    int clipMergeAllDone() const { return m_clipMergeAllDone; }
    int clipMergeAllTotal() const { return m_clipMergeAllTotal; }
    int clipMergeAllClips() const { return m_clipMergeAllClips; }
    int clipMergeEtaS() const { return m_clipMergeEtaS; }
    QString bufferNote() const { return m_bufferNote; }
    QString clipNameTemplate() const { return m_clipNameTemplate; }
    QString clipNameExample() const { return m_clipNameExample; }
    QString clipNamePreview() const { return m_clipNamePreview; }
    bool clipNameKnown() const { return m_clipNameKnown; }
    bool cdngLogActive() const { return m_cdngLogActive; }
    int cdngLogBits() const { return m_cdngLogBits; }
    bool cdngLogOn() const { return m_cdngLogOn; }
    bool cdngLogAvailable() const { return m_cdngLogAvailable; }
    bool cdngLogApplied() const { return m_cdngLogApplied; }
    int controlsErrors() const { return m_controlsErrors; }
    int controlsWarnings() const { return m_controlsWarnings; }
    bool standby() const { return m_standby; }
    Q_INVOKABLE bool enterStandby();
    Q_INVOKABLE bool wakeFromStandby();
    Q_INVOKABLE void notifyUserActivity();
    bool timelapseActive() const;
    qulonglong timelapseShotCount() const { return m_timelapseShotCount; }
    bool stillExposureActive() const { return m_stillExposureActive; }
    bool mediaWritesPending() const { return m_mediaWritesPending; }
    double stillExposureRemainingSeconds() const;
    int audioInputLevel() const;
    bool connected() const;
    QString lastError() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool applyFps(const QString &displayValue);
    Q_INVOKABLE bool applyIso(const QString &displayValue);
    Q_INVOKABLE bool applyExposureCompensation(double ev);
    Q_INVOKABLE bool applyExposureMetering(const QString &mode);
    Q_INVOKABLE bool applyShutterAngle(const QString &displayValue);
    Q_INVOKABLE bool applyShutterSpeed(const QString &displayValue);
    Q_INVOKABLE bool applyWhiteBalance(const QString &displayValue);
    Q_INVOKABLE bool applyResolution(const QString &displayValue);
    Q_INVOKABLE bool applyRecordingFormat(const QString &displayValue);
    Q_INVOKABLE bool applyProresProfile(const QString &value);
    Q_INVOKABLE bool applyProresColorProfile(const QString &value);
    Q_INVOKABLE bool applyCdngPreviewColorProfile(const QString &value);
    Q_INVOKABLE bool applyCdngCompression(const QString &value);
    Q_INVOKABLE bool applyTuningFile(const QString &path);
    Q_INVOKABLE bool applyRawBitDepth(const QString &displayValue);
    Q_INVOKABLE void applyBufferMode(const QString &value);
    Q_INVOKABLE void applyFramesPerFolder(int value);
    Q_INVOKABLE void applyClipMerge(bool enabled);
    Q_INVOKABLE void applyStoragePreroll();
    Q_INVOKABLE void applyStoragePrerollAuto(bool on);
    Q_INVOKABLE void applyClipNameTemplate(const QString &value);
    Q_INVOKABLE void requestClipNamePreview(const QString &value);
    Q_INVOKABLE bool applyClearHdr(bool enabled);
    Q_INVOKABLE void applyCdngLog(bool on);
    Q_INVOKABLE bool applyH264Resolution(const QString &displayValue);
    // target: "ui" (what the screens show), "files" (the clips and the audio) or "both"
    Q_INVOKABLE bool applyTimecodeMode(const QString &displayValue, const QString &target);
    Q_INVOKABLE bool applyAutofocusMode(const QString &displayValue);
    Q_INVOKABLE bool applyAutofocusRange(const QString &displayValue);
    Q_INVOKABLE bool applyAutofocusSpeed(const QString &displayValue);
    Q_INVOKABLE bool applyAutofocusWindow(const QString &displayValue);
    Q_INVOKABLE bool applyPhotoTimelapse(const QString &displayValue, const QString &format);
    Q_INVOKABLE bool applyPhotoModeEnabled(bool enabled);
    Q_INVOKABLE bool applyCaptureMode(const QString &mode);
    Q_INVOKABLE bool applyPhotoLongExposureEnabled(bool enabled);
    Q_INVOKABLE bool applyPhotoBracketingEnabled(bool enabled);
    Q_INVOKABLE bool applyPhotoBracketingEv(double ev);
    Q_INVOKABLE bool setTimelapseActive(bool active, const QString &displayValue, const QString &format);
    Q_INVOKABLE bool setRecording(bool recording);
    Q_INVOKABLE bool capturePhoto(const QString &format, int count = 1);
    Q_INVOKABLE bool calibrateGyro();
    QJsonObject cameraPresetSettings() const;
    bool applyCameraPreset(const QJsonObject &settings);

signals:
    void fpsChanged();
    void isoChanged();
    void shutterAngleChanged();
    void shutterSpeedChanged();
    void whiteBalanceChanged();
    void whiteBalanceAvailableChanged();
    void cameraSetValuesChanged();
    void exposureCompensationChanged();
    void exposureMeteringChanged();
    void resolutionChanged();
    void recordingFormatChanged();
    void proresProfileChanged();
    void proresColorProfileChanged();
    void cdngPreviewColorProfileChanged();
    void previewExposureReferenceChanged();
    void cdngCompressionChanged();
    void recordingCapabilitiesChanged();
    void tuningFileChanged();
    void rawBitDepthChanged();
    void clearHdrChanged();
    void h264ResolutionChanged();
    void sensorNameChanged();
    void autofocusModeChanged();
    void fileTimecodeModeChanged();
    void autofocusRangeChanged();
    void autofocusSpeedChanged();
    void autofocusWindowChanged();
    void recordingChanged();
    void recordingHealthChanged();
    void bufferFillChanged();
    void bufferModeChanged();
    void bufferSafetyStopChanged();
    void storagePrerollActiveChanged();
    void storagePrerollAutoChanged();
    void storagePrerollAutoKnownChanged();
    void storagePrerollFpsChanged();
    void storagePrerollLastChanged();
    void bufferStopPercentChanged();
    void bufferSettingChanged();
    void bufferNoteChanged();
    void cdngLogChanged();
    void clipNameChanged();
    void clipSplitChanged();
    void clipMergeProgressChanged();
    void clipNamePreviewChanged();
    void controlsStatusChanged();
    void standbyChanged();
    // Core's media watcher state, from the "media" event and get_state.
    void coreMediaStateChanged(const QString &state, bool alive);
    void timelapseActiveChanged();
    void mediaWritesPendingChanged();
    void timelapseShotCountChanged();
    void stillExposureChanged();
    void audioInputLevelChanged();
    void connectedChanged();
    void lastErrorChanged();
    void recordingFailed(const QString &error);
    void bufferSafetyStopped(const QString &message);
    void gyroCalibrationFinished(bool ok, const QString &message);
    void sharedPhotoStateChanged(bool photoModeEnabled,
                                 const QString &photoFormat,
                                 const QString &photoTimelapse,
                                 bool longExposureEnabled,
                                 bool bracketingEnabled,
                                 double bracketingEv);
    void timelapseFrameCaptured();
    void photoCaptured();
    void photoCaptureFailed(const QString &error);
    void externalRecordingPreparationRequested();
    void hardwareActionTriggered(const QString &action);

private:
    void refreshFromCore();
    void updateRefreshTimer();
    void loadPersistedCameraSettings();
    void saveCurrentCameraSettings(int shutterUsOverride = -1);
    bool sendCoreCommand(const QString &commandName,
                         const QJsonObject &arguments = {},
                         QJsonObject *replyObject = nullptr);
    void applyCoreMessage(const QJsonObject &message);
    void applyCoreState(const QJsonObject &state);
    void applyClipNameState(const QJsonObject &state);
    void ensureEventSocketConnected();
    void processEventSocketMessages();
    void applyShutterFromMicroseconds(double shutterUs, double fps);
    int shutterUsForAngle(double angle, double fps) const;
    int shutterUsForSpeed(double denominator) const;
    double currentFpsValue() const;

    QString formatFpsValue(double value) const;
    QString formatIsoValue(double value) const;
    QString formatShutterAngleValue(double value) const;
    QString formatShutterSpeedValue(double value) const;
    QString formatResolutionValue(int width, int height) const;
    QString formatH264ResolutionValue(int width, int height) const;
    QString formatRecordingFormatValue(const QString &value) const;
    QString parseLossyDngRatioValue(const QString &displayValue) const;
    QString formatRawBitDepthValue(int value) const;
    QString formatAutofocusModeValue(const QString &value) const;
    QString formatAutofocusRangeValue(const QString &value) const;
    QString formatAutofocusSpeedValue(const QString &value) const;
    QString formatAutofocusWindowValue(double x, double y, double width, double height) const;

    double parseFpsValue(const QString &displayValue) const;
    double parseIsoValue(const QString &displayValue) const;
    double parseShutterAngleValue(const QString &displayValue) const;
    double parseShutterSpeedValue(const QString &displayValue) const;
    double parseWhiteBalanceValue(const QString &displayValue) const;
    bool parseResolutionValue(const QString &displayValue, int *width, int *height) const;
    bool parseH264ResolutionValue(const QString &displayValue, int *width, int *height) const;
    QString parseRecordingFormatValue(const QString &displayValue) const;
    int parseRawBitDepthValue(const QString &displayValue) const;
    QString parseTimecodeModeValue(const QString &displayValue) const;
    QString parseAutofocusModeValue(const QString &displayValue) const;
    QString parseAutofocusRangeValue(const QString &displayValue) const;
    QString parseAutofocusSpeedValue(const QString &displayValue) const;
    bool autofocusWindowPreset(const QString &displayValue,
                               double *x,
                               double *y,
                               double *width,
                               double *height) const;
    QString audioDeviceIdFromSelection(const QString &displayValue) const;
    QString compactNumber(double value, int decimals = 3) const;
    void setFps(const QString &value);
    void setIso(const QString &value);
    void setShutterAngle(const QString &value);
    void setShutterSpeed(const QString &value);
    void setWhiteBalance(const QString &value);
    void setResolution(const QString &value);
    void setRecordingFormatValue(const QString &value);
    void setProresProfileValue(const QString &value);
    void setProresColorProfileValue(const QString &value);
    void setCdngPreviewColorProfileValue(const QString &value);
    void setTuningFileValue(const QString &value);
    void setRawBitDepthValue(const QString &value);
    void setClearHdrValue(bool value);
    void setH264ResolutionValue(const QString &value);
    void setSensorNameValue(const QString &value);
    void setAutofocusModeValue(const QString &value);
    void setAutofocusRangeValue(const QString &value);
    void setAutofocusSpeedValue(const QString &value);
    void setAutofocusWindowValue(const QString &value);
    void setRecordingState(bool value);
    void applyBufferState(const QJsonObject &state);
    void applyRecordingDroppedFrames(const QJsonObject &state);
    void applyCdngLogState(const QJsonObject &state);
    void setTimelapseActiveState(bool value);
    void setTimelapseShotCount(qulonglong value);
    void setAudioInputLevel(int value);
    void setConnected(bool value);
    void setLastError(const QString &value);
    void setCoreMediaState(const QString &state, bool alive);

    QSettings m_settings;
    bool m_rawCompressionSupported = false;
    bool m_rawRecordingSupported = false;
    bool m_proresSupported = false;
    bool m_h264HardwareEncoding = false;
    int m_h264MaxWidth = 2560;
    double m_h264MaxFps = 0;
    QLocalSocket m_eventSocket;
    QString m_fps = QStringLiteral("24.000");
    QString m_iso = QStringLiteral("800");
    QString m_shutterAngle = QStringLiteral("180°");
    QString m_shutterSpeed = QStringLiteral("1/48");
    QString m_whiteBalance = QStringLiteral("5600K");
    QString m_resolution = QStringLiteral("1928x1090");
    QString m_recordingFormat = QStringLiteral("cDNG");
    QString m_cdngCompression = QStringLiteral("none");
    QString m_lossyDngRatio = QStringLiteral("3to1");
    QString m_proresProfile = QStringLiteral("422");
    QString m_proresColorProfile = QStringLiteral("standard");
    QString m_cdngPreviewColorProfile = QStringLiteral("standard");
    QVariantMap m_previewExposureReference;
    QString m_tuningFile;
    QString m_rawBitDepth = QStringLiteral("12-bit");
    bool m_clearHdr = false;
    QString m_h264Resolution = QStringLiteral("Match Capture");
    QString m_sensorName = QStringLiteral("Unknown");
    QString m_autofocusMode = QStringLiteral("Continuous");
    QString m_autofocusRange = QStringLiteral("Normal");
    QString m_autofocusSpeed = QStringLiteral("Normal");
    QString m_autofocusWindow = QStringLiteral("Center");
    double m_afX = 0.25, m_afY = 0.25, m_afWidth = 0.5, m_afHeight = 0.5;
    bool m_isoAuto = false;
    bool m_shutterAuto = false;
    bool m_whiteBalanceAuto = false;
    bool m_whiteBalanceAvailable = false;
    double m_exposureCompensation = 0.0;
    bool m_exposureCompensationAvailable = false;
    QString m_exposureMetering = QStringLiteral("centre-weighted");
    QVariantList m_exposureMeteringOptions;
    bool m_recording = false;
    double m_bufferFill = 0.0; // write-queue level 0..1 from Core ("buffer" event, buffer_fill)
    QString m_bufferMode = QStringLiteral("none"); // "frames", "ram" or "none"
    bool m_storagePrerollActive = false; // Core's storage_preroll_active: from the start of a pre-roll until its clip is deleted
    bool m_storagePrerollAuto = true; // Core's storage_preroll_auto: the automatic pre-roll (Core start, card insert/format); only meaningful once m_storagePrerollAutoKnown
    bool m_storagePrerollAutoKnown = false; // false until Core has sent storage_preroll_auto (older Core never does)
    double m_storagePrerollFps = 0.0; // Core's storage_preroll_fps: the pre-roll's own fps while one runs, 0 otherwise; display only, never the operator's fps
    QString m_storagePrerollLast; // Core's storage_preroll_last: "ok: ...", "skipped: ...", "failed: ..."; empty = none yet
    bool m_bufferSafetyStop = false; // Core ended the take because the write buffer filled; true until drained
    int m_bufferStopPercent = 0;     // Core's buffer stop threshold in percent, 0 = off
    QString m_bufferSetting; // requested mode from Core's buffer_setting; empty = unknown (control hidden)
    // Core's [storage] frames_per_folder (0 = one folder; -1 = unknown, row hidden) and clip_merge; *Env = set by the
    // environment (APERTAR_CDNG_FRAMES_PER_FOLDER / APERTAR_CLIP_MERGE=0), so the tiles are locked.
    int m_framesPerFolder = -1;
    bool m_framesPerFolderEnv = false;
    bool m_clipMergeKnown = false;
    bool m_clipMergeEnabled = true;
    bool m_clipMergeEnvOff = false;
    // Core's merge progress (clip_merge_* in get_state and the clip_merge event; KB clip-merge-progress-plan.md).
    QString m_clipMergeActiveClip;
    QString m_clipMergePaused;
    int m_clipMergePending = 0;
    int m_clipMergeClipDone = 0;
    int m_clipMergeClipTotal = 0;
    int m_clipMergeAllDone = 0;
    int m_clipMergeAllTotal = 0;
    int m_clipMergeAllClips = 0;
    int m_clipMergeEtaS = 0;
    QString m_bufferNote; // Core's buffer_note: why ram was or was not used
    // CineMate Log (Core: cdng_log_bits, cdng_log_available, cdng_log_applied); active = available && bits > 0 && applied.
    int m_cdngLogBits = 0;
    bool m_cdngLogAvailable = false;
    bool m_cdngLogApplied = true; // a missing cdng_log_applied (older Core) counts as applied
    bool m_cdngLogActive = false;
    bool m_cdngLogOn = false;
    // Clip naming (Core: clip_name_template, clip_name_example); known only once Core has sent the template (older Core never does).
    QString m_clipNameTemplate;
    QString m_clipNameExample;
    QString m_clipNamePreview; // reply of the last preview_clip_name; empty until asked
    bool m_clipNameKnown = false;
    bool m_fpsSpeedRamp = false; // Core's fps_speed_ramp (T31): FPS may change during a raw take
    bool m_soundRecording = false; // a sound-only take: recording, but not the camera
    bool m_fpsSpeedRampKeepExposure = false;
    bool m_isoAutoAfterClearHdr = false;
    bool m_whiteBalanceAutoAfterClearHdr = false;
    int m_isoMax = 0;
    double m_fpsMax = 0.0;
    bool m_ladderActive = false;
    QString m_fileTimecodeMode = QStringLiteral("Free Run");
    QString m_isoInUse;
    QString m_whiteBalanceInUse;
    bool m_isoSetByCamera = false;
    bool m_whiteBalanceSetByCamera = false;
    bool m_shutterSetByCamera = false;
    bool m_recordingHasDroppedFrames = false;
    int m_recordingDroppedFrames = 0; // the take's dropped frames, all kinds (Core recording_dropped_frames)
    int m_controlsErrors = 0;
    int m_controlsWarnings = 0;
    void setControlsStatus(const QJsonObject &object, const QString &errorsKey, const QString &warningsKey);
    bool m_standby = false;
    QString m_coreMediaState;
    bool m_coreMediaAlive = true;
    bool m_timelapseActive = false;
    qulonglong m_timelapseShotCount = 0;
    bool m_stillExposureActive = false;
    bool m_mediaWritesPending = false;
    qint64 m_mediaWriteRevision = -1;
    double m_stillExposureRemainingSeconds = 0;
    QElapsedTimer m_stillExposureTimer;
    int m_audioInputLevel = 0;
    bool m_connected = false;
    QString m_lastError;
    QString m_lastRecordingError;
    QString m_lastPhotoWriteError;
    QTimer m_retryTimer;
    int m_nextCommandId = 1;
    int m_pendingStateRequestId = -1;
};
