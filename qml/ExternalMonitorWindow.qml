import QtQuick
import QtQuick.Window
import Apertar 1.0

Window {
    id: root
    color: "#000000"
    flags: Qt.FramelessWindowHint
    property bool shutdownPopupVisible: monitorRuntimeBridge
                                        ? monitorRuntimeBridge.shutdownPopupVisible
                                        : false
    property bool shutdownPopupTriggered: monitorRuntimeBridge
                                          ? monitorRuntimeBridge.shutdownPopupTriggered
                                          : false
    property bool shutdownHoldActive: monitorRuntimeBridge
                                      ? monitorRuntimeBridge.shutdownHoldActive
                                      : false
    property real shutdownHoldProgress: monitorRuntimeBridge
                                        ? monitorRuntimeBridge.shutdownHoldProgress
                                        : 0.0
    property string shutdownErrorText: monitorRuntimeBridge
                                       ? monitorRuntimeBridge.shutdownErrorText
                                       : ""
    readonly property bool synchronizedCaptureStateAvailable: monitorRuntimeBridge
                                                              ? monitorRuntimeBridge.captureStateAvailable
                                                              : false
    readonly property bool recordingActive: synchronizedCaptureStateAvailable
                                            ? monitorRuntimeBridge.recordingActive
                                            : (apertarControlBridge ? apertarControlBridge.recording : false)
    readonly property bool timelapseActive: synchronizedCaptureStateAvailable
                                            ? monitorRuntimeBridge.timelapseActive
                                            : (apertarControlBridge ? apertarControlBridge.timelapseActive : false)

    readonly property bool photoModeEnabled: settingsBridge ? settingsBridge.photoModeEnabled : false
    readonly property bool recordAudioEnabled: settingsBridge ? settingsBridge.recordAudioEnabled : false
    readonly property bool audioMeterEnabled: settingsBridge ? settingsBridge.audioMeterEnabled : false
    readonly property int inputVolumeLevel: settingsBridge ? settingsBridge.inputVolume : 60
    readonly property bool localAudioMeterAvailable: typeof audioMeterBridge !== "undefined"
                                                     && audioMeterBridge
    readonly property bool audioInputAvailable: localAudioMeterAvailable
                                               ? audioMeterBridge.inputDeviceAvailable
                                               : root.recordAudioEnabled
    readonly property bool showAudioMeter: root.recordAudioEnabled
                                           && root.audioMeterEnabled
                                           && !root.photoModeEnabled
                                           && root.audioInputAvailable
    readonly property string timecodeMode: settingsBridge ? settingsBridge.timecodeMode : "Free Run"
    readonly property bool overlayFeedEnabled: settingsBridge
                                               ? settingsBridge.externalMonitorMode === "Assist Feed"
                                               : false
    readonly property bool infoOverlayEnabled: settingsBridge
                                               ? settingsBridge.externalMonitorInfoOverlay !== "Off"
                                               : true
    readonly property string externalMonitorOrientation: settingsBridge
                                                         ? settingsBridge.externalMonitorOrientation
                                                         : "Landscape"
    readonly property bool externalMonitorPortrait: externalMonitorOrientation === "Portrait Left"
                                                    || externalMonitorOrientation === "Portrait Right"
    readonly property int externalMonitorRotation: externalMonitorOrientation === "Portrait Left" ? -90
                                                   : externalMonitorOrientation === "Portrait Right" ? 90
                                                   : externalMonitorOrientation === "Upside Down" ? 180
                                                   : 0
    readonly property real monitorContentWidth: externalMonitorPortrait ? height : width
    readonly property real monitorContentHeight: externalMonitorPortrait ? width : height
    readonly property bool falseColorLegendVisible: root.infoOverlayEnabled
                                                    && root.overlayFeedEnabled
                                                    && !root.smpteEnabled
                                                    && settingsBridge
                                                    ? settingsBridge.falseColorEnabled
                                                    : false
    readonly property bool horizontalLevelEnabled: root.infoOverlayEnabled
                                                   && root.overlayFeedEnabled
                                                   && !root.smpteEnabled
                                                   && root.layoutKind !== "both"
                                                   && settingsBridge
                                                   ? settingsBridge.horizontalLevelEnabled
                                                   : false
    readonly property color hudShadowColor: "#d8000000"
    readonly property int hudShadowOffset: 2
    readonly property color guideShadowColor: "#90000000"
    readonly property int guidesThickness: settingsBridge ? Math.max(1, settingsBridge.guidesThickness) : 1
    readonly property int guideStrokeWidth: guidesThickness * 2
    readonly property int guideShadowOffset: Math.max(1, guidesThickness)
    readonly property string shutterDisplayValue: photoModeEnabled
                                                 ? apertarControlBridge.shutterSpeed
                                                 : apertarControlBridge.shutterAngle
    readonly property string recordingFormatValue: apertarControlBridge && apertarControlBridge.recordingFormat.length > 0
                                                  ? apertarControlBridge.recordingFormat
                                                  : "cDNG"
    readonly property string h264ResolutionValue: apertarControlBridge && apertarControlBridge.h264Resolution.length > 0
                                                  ? apertarControlBridge.h264Resolution
                                                  : "Match Capture"
    readonly property string fpsValue: apertarControlBridge && apertarControlBridge.fps.length > 0
                                      ? apertarControlBridge.fps
                                      : "24.000"
    // Shown in the FPS readout: the pre-roll's own fps while one runs (display only), else fpsValue.
    readonly property string fpsDisplayValue: apertarControlBridge && apertarControlBridge.storagePrerollActive
                                               && apertarControlBridge.storagePrerollFps > 0
                                               ? Number(apertarControlBridge.storagePrerollFps).toFixed(3)
                                               : root.fpsValue
    // The ISO in use is the ceiling the camera added (not one of the operator's values; the
    // built-in list when none is set).
    readonly property bool isoOnAddedCap: {
        const maximum = apertarControlBridge ? apertarControlBridge.isoMax : 0
        if (!(maximum > 0) || !apertarControlBridge || Math.round(parseFloat(apertarControlBridge.iso)) !== maximum)
            return false
        const own = settingsBridge && settingsBridge.isoSteps.length > 0 ? settingsBridge.isoSteps
                    : [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200]
        return !own.some(v => Math.abs(Number(v) - maximum) < 0.5)
    }
    readonly property string isoValue: apertarControlBridge && apertarControlBridge.isoInUse.length > 0
                                      ? apertarControlBridge.isoInUse
                                      : (apertarControlBridge && apertarControlBridge.iso.length > 0
                                         ? apertarControlBridge.iso
                                         : "800")
    readonly property string wbValue: apertarControlBridge && apertarControlBridge.whiteBalanceInUse.length > 0
                                     ? apertarControlBridge.whiteBalanceInUse
                                     : (apertarControlBridge && apertarControlBridge.whiteBalance.length > 0
                                        ? apertarControlBridge.whiteBalance
                                        : "5600K")
    // Raw takes add bit depth and Clear HDR on the resolution line, same size as the pixels.
    readonly property string rawBitDepthValue: apertarControlBridge && apertarControlBridge.rawBitDepth.length > 0
                                              ? apertarControlBridge.rawBitDepth : ""
    readonly property bool rawRecordFormat: !root.photoModeEnabled && root.recordingFormatValue.indexOf("ProRes") !== 0
                                            && root.recordingFormatValue !== "H.264"
    readonly property string resolutionLineValue: root.resolutionValue
                                                  + (root.rawRecordFormat && root.rawBitDepthValue.length > 0
                                                     ? " · " + root.rawBitDepthValue
                                                       + (!!apertarControlBridge && apertarControlBridge.clearHdr ? " · Clear HDR" : "")
                                                     : "")
    readonly property string resolutionValue: apertarControlBridge && apertarControlBridge.resolution.length > 0
                                             ? apertarControlBridge.resolution
                                             : "1920x1080"
    readonly property string processedVideoDefaultResolutionValue: "2560x1440"
    readonly property string h264OutputResolutionValue: root.h264ResolutionValue === "Match Capture"
                                                        ? root.processedVideoDefaultResolutionValue
                                                        : root.h264ResolutionValue
    readonly property bool processedVideoRecordFormat: !root.photoModeEnabled && root.recordingFormatValue === "H.264"
    readonly property string previewAspectResolutionValue: root.processedVideoRecordFormat
                                                          ? root.h264OutputResolutionValue
                                                          : root.resolutionValue
    readonly property string formatInfoValue: root.processedVideoRecordFormat
                                              ? (root.h264OutputResolutionValue + " " + root.recordingFormatValue)
                                              : (root.recordingFormatValue
                                                 + (!root.photoModeEnabled && root.recordingFormatValue === "cDNG"
                                                    && !!apertarControlBridge && apertarControlBridge.cdngLogActive ? " · Log" : ""))
    readonly property real cam0ImageAspect: root.aspectRatioForResolution(root.previewAspectResolutionValue)
    // The main pane's picture (cam1's when the panes are swapped): the guides and the level follow it.
    readonly property real previewImageAspectRatio: root.swapped ? root.cam1ImageAspect : root.cam0ImageAspect
    readonly property real previewDisplayAspectRatio: previewImageAspectRatio
                                                      * (settingsBridge && settingsBridge.anamorphicDesqueezeEnabled && !smpteEnabled
                                                         ? anamorphicRatioValue(settingsBridge.anamorphicRatio) : 1.0)
    readonly property string remainingValue: mediaBridge
                                             ? (photoModeEnabled ? mediaBridge.remainingStillsText
                                                                 : mediaBridge.remainingMinutesText)
                                             : "N/A"
    readonly property bool smpteEnabled: settingsBridge ? settingsBridge.smpteEnabled : false
    readonly property bool externalNoMedia: mediaBridge ? !mediaBridge.mediaMounted : true
    // Buffer safety stop: Core may still report recording until the flush ends; the pill treats it as READY.
    readonly property bool pillRecordingActive: root.recordingActive && !(!!apertarControlBridge && apertarControlBridge.bufferSafetyStop)
    readonly property bool externalActiveCapture: root.pillRecordingActive || root.timelapseActive
    readonly property bool guidesEnabled: (!smpteEnabled && infoOverlayEnabled && overlayFeedEnabled && settingsBridge
                                           && root.layoutKind !== "both")
                                          ? settingsBridge.guidesEnabled
                                          : false
    readonly property string guideType: settingsBridge ? settingsBridge.guidesType : "Thirds"
    readonly property bool centerMarkerEnabled: (!smpteEnabled && infoOverlayEnabled && overlayFeedEnabled && settingsBridge
                                                 && root.layoutKind !== "both")
                                                ? settingsBridge.centerMarkerEnabled
                                                : false
    readonly property string centerMarkerType: settingsBridge ? settingsBridge.centerMarkerType : "Circle/Dot"
    readonly property real selectedAspectRatio: guideType === "16:9" ? (16.0 / 9.0)
                                             : guideType === "2.39:1" ? 2.39
                                             : guideType === "4:3" ? (4.0 / 3.0)
                                             : guideType === "1:1" ? 1.0
                                             : guideType === "Academy 1.37:1" ? 1.37
                                             : guideType === "5:4" ? 1.25
                                             : guideType === "9:16" ? (9.0 / 16.0)
                                             : guideType === "14:9" ? (14.0 / 9.0)
                                             : 0.0
    readonly property bool showThirdsGuides: guidesEnabled && guideType === "Thirds"
    readonly property bool showAspectGuides: guidesEnabled && selectedAspectRatio > 0.0
    readonly property real guideFrameWidth: showAspectGuides
                                           ? ((monitorContentWidth / monitorContentHeight) > selectedAspectRatio
                                              ? monitorContentHeight * selectedAspectRatio
                                              : monitorContentWidth)
                                           : 0
    readonly property real guideFrameHeight: showAspectGuides
                                            ? ((monitorContentWidth / monitorContentHeight) > selectedAspectRatio
                                               ? monitorContentHeight
                                               : monitorContentWidth / selectedAspectRatio)
                                            : 0
    readonly property bool externalPreroll: !!apertarControlBridge && apertarControlBridge.storagePrerollActive && !externalActiveCapture
    readonly property color externalStatusFill: externalPreroll ? "#80124eb7"
                                                                : externalNoMedia ? "#806b5200"
                                                                : (externalActiveCapture ? "#80b71212" : "#70000000")
    readonly property color externalStatusBorder: externalPreroll ? "#662b7fff"
                                                                  : externalNoMedia ? "#66ffd54a"
                                                                  : (externalActiveCapture ? "#66ff6666" : "#0affffff")
    readonly property color externalStatusDot: externalPreroll ? "#2b7fff"
                                                               : externalNoMedia ? "#ffd54a"
                                                               : (externalActiveCapture ? "#fb2c36" : apertarControlBridge && apertarControlBridge.mediaWritesPending && !apertarControlBridge.bufferSafetyStop ? "#ffd54a" : "#00c951")
    readonly property string externalStatusLabel: externalPreroll ? "PRE-ROLL"
                                                                  : externalNoMedia ? "NO MEDIA"
                                                                  : (root.timelapseActive ? "TIMELAPSE" : (root.pillRecordingActive ? "REC" : apertarControlBridge && apertarControlBridge.mediaWritesPending && !apertarControlBridge.bufferSafetyStop ? "WRITING" : "READY"))
    readonly property var topMonitorInfoItems: [
        { label: "FORMAT", value: root.overlayFormatValue },
        { label: "FPS", value: root.overlayFpsValue, cameraSet: root.overlayCam1 ? false : (!!apertarControlBridge && apertarControlBridge.storagePrerollActive) },
        { label: "ISO", value: root.overlayIsoValue, cameraSet: root.overlayCam1 ? root.cam1IsoSetByCamera : ((!!apertarControlBridge && apertarControlBridge.isoSetByCamera) || root.isoOnAddedCap) },
        { label: "SHUTTER", value: root.overlayShutterValue, cameraSet: root.overlayCam1 ? root.cam1ShutterSetByCamera : (!!apertarControlBridge && apertarControlBridge.shutterSetByCamera) },
        { label: "WB", value: root.overlayWbValue, cameraSet: root.overlayCam1 ? root.cam1WbSetByCamera : (!!apertarControlBridge && apertarControlBridge.whiteBalanceSetByCamera) }
    ]

    // ---- Dual sensor views (T66) ----
    // The cam1 preview client exists only in the normal process; the monitor-only one shows cam0.
    readonly property bool cam1Available: typeof apertarPreviewBridge1 !== "undefined" && apertarPreviewBridge1 !== null
    readonly property bool cam1Test: typeof cam1InsetTest !== "undefined" && cam1InsetTest
    readonly property bool cam1Present: !!apertarControlBridge && apertarControlBridge.cam1Present
    readonly property bool cam1Wanted: cam1Available && (cam1Present || cam1Test)
    // Photo mode and timelapse run on cam0 alone (P11): the cam1 sources then show cam0.
    readonly property bool photoRule: root.photoModeEnabled || root.timelapseActive
    // The view as HDMI 0's setting asks for it. Without cam1 it is Cam 0 as before; the test override
    // (APERTAR_UI_CAM1_INSET) forces PiP Cam 0 when Core's state has no cam1.
    readonly property string requestedSource: root.cam1Present
                                              ? (settingsBridge && settingsBridge.previewSource ? settingsBridge.previewSource : "Both")
                                              : (root.cam1Test ? "PiP Cam 0" : "Cam 0")
    readonly property string viewSource: (root.photoRule || !root.cam1Available) ? "Cam 0" : root.requestedSource
    readonly property bool viewHasCam1: root.viewSource !== "Cam 0"

    // A pane has a signal while its client's framesReceived moved in the last second (polled every 500 ms).
    property real cam1FrameCount: 0
    property real cam1LastMovedMs: 0
    property bool cam1SignalSeen: false
    readonly property bool cam1Signal: root.cam1Wanted && root.cam1SignalSeen
    function pollCam1Signal() {
        if (!root.cam1Available) {
            root.cam1SignalSeen = false
            return
        }
        var count = apertarPreviewBridge1.framesReceived
        var now = Date.now()
        if (count !== root.cam1FrameCount) {
            root.cam1FrameCount = count
            root.cam1LastMovedMs = now
        }
        root.cam1SignalSeen = count > 0 && (now - root.cam1LastMovedMs) < 900
    }

    Timer {
        interval: 500
        repeat: true
        running: root.cam1Wanted && !apertarControlBridge.standby
        triggeredOnStart: true
        onTriggered: root.pollCam1Signal()
        onRunningChanged: {
            if (!running)
                root.cam1SignalSeen = false
        }
    }

    // Layouts (§5.2). "both": two panes side by side; "pip": the second camera as an inset; "single".
    // Cam 1 and PiP Cam 1 without a cam1 signal fall back to cam0 full screen (banner); PiP Cam 0 loses its inset.
    readonly property string layoutKind: {
        if (root.viewSource === "Both" || root.viewSource === "Both (Cam 1 left)")
            return "both"
        if (root.viewSource === "PiP Cam 0" || root.viewSource === "PiP Cam 1")
            return root.cam1Signal ? "pip" : "single"
        return "single"
    }
    // True when the main item takes cam1's bridge (and the second item cam0's).
    readonly property bool swapped: {
        if (root.viewSource === "Cam 1" || root.viewSource === "PiP Cam 1")
            return root.cam1Signal
        return root.viewSource === "Both (Cam 1 left)"
    }
    readonly property bool cam1FallbackBanner: (root.viewSource === "Cam 1" || root.viewSource === "PiP Cam 1") && !root.cam1Signal
    // The pane that shows cam1 in a Both view, black with a NO SIGNAL line while cam1 sends nothing.
    readonly property bool cam1PaneMissing: root.layoutKind === "both" && !root.cam1Signal
    readonly property bool mainPaneVisible: !(root.cam1PaneMissing && root.swapped)
    readonly property bool secondPaneVisible: root.layoutKind !== "single" && !(root.cam1PaneMissing && !root.swapped)

    // cam1.settings, read the way the primary's own are (width/height or resolution, then the 1928x1090 style
    // sizes folded to the nominal ones).
    readonly property var cam1S: apertarControlBridge ? apertarControlBridge.cam1Settings : ({})
    readonly property string cam1ResolutionValue: {
        var s = root.cam1S
        var w = 0
        var h = 0
        if (s.width > 0 && s.height > 0) {
            w = Number(s.width)
            h = Number(s.height)
        } else if (s.resolution) {
            var parts = String(s.resolution).split("x")
            if (parts.length === 2) {
                w = parseInt(parts[0])
                h = parseInt(parts[1])
            }
        }
        if (!(w > 0 && h > 0))
            return ""
        if (w === 1928 && h === 1090)
            return "1920x1080"
        if (w === 3856 && h === 2180)
            return "3840x2160"
        return w + "x" + h
    }
    // cam1's recording format, named the way the primary names its own; cam0's while cam1.settings has none.
    readonly property string cam1RecordingFormat: {
        var f = String(root.cam1S.recording_format || "").toLowerCase()
        if (f.length === 0)
            return root.recordingFormatValue
        if (f.indexOf("prores") === 0) {
            var profile = String(root.cam1S.prores_profile || "422").toLowerCase()
            return "ProRes " + (profile === "proxy" ? "Proxy" : profile === "lt" ? "LT" : profile === "hq" ? "HQ" : "422")
        }
        if (f === "mlv")
            return "MLV"
        if (f === "h264" || f === "h.264" || f === "mp4")
            return "H.264"
        return "cDNG"
    }
    readonly property bool cam1ProcessedVideo: root.cam1RecordingFormat === "H.264"
    readonly property string cam1PreviewAspectResolution: {
        if (root.cam1ResolutionValue.length === 0)
            return ""
        if (!root.cam1ProcessedVideo)
            return root.cam1ResolutionValue
        if (root.cam1S.h264_width > 0 && root.cam1S.h264_height > 0)
            return Number(root.cam1S.h264_width) + "x" + Number(root.cam1S.h264_height)
        return root.processedVideoDefaultResolutionValue
    }
    // Each pane letterboxes its own aspect; without cam1's size it borrows cam0's.
    readonly property real cam1ImageAspect: root.cam1PreviewAspectResolution.length > 0
                                            ? root.aspectRatioForResolution(root.cam1PreviewAspectResolution)
                                            : root.cam0ImageAspect
    readonly property real desqueezeFactor: (settingsBridge && settingsBridge.anamorphicDesqueezeEnabled && !root.smpteEnabled)
                                            ? root.anamorphicRatioValue(settingsBridge.anamorphicRatio) : 1.0
    readonly property real mainDisplayAspect: root.previewImageAspectRatio * root.desqueezeFactor
    readonly property real secondImageAspect: root.swapped ? root.cam0ImageAspect : root.cam1ImageAspect
    readonly property real secondDisplayAspect: root.secondImageAspect * root.desqueezeFactor

    // ---- The info overlay follows the window's main camera (T66) ----
    // The main camera is the full-screen one, or the left pane's in a Both view: cam1 exactly when the
    // main item holds cam1's bridge. Its values come from cam1.settings; under auto, the value in use.
    readonly property bool overlayCam1: root.cam1Present && root.swapped
    readonly property string cam1IsoInUse: {
        var s = root.cam1S
        if (s.iso_auto === true)
            return Number(s.iso_actual) > 0 ? String(Math.round(Number(s.iso_actual))) : "Auto"
        return root.cam1IsoSet()
    }
    readonly property string cam1WbInUse: {
        var s = root.cam1S
        if (s.wb_auto === true) {
            var kelvin = Math.round(Number(s.wb_actual_kelvin))
            return (s.wb_measured === true && kelvin > 0) ? kelvin + "K" : "Auto"
        }
        return root.cam1WbSet()
    }
    readonly property bool cam1IsoOnAddedCap: {
        var maximum = Number(root.cam1S.iso_max)
        if (!(maximum > 0) || Math.round(Number(root.cam1S.iso)) !== maximum)
            return false
        var own = settingsBridge && settingsBridge.isoSteps.length > 0 ? settingsBridge.isoSteps
                  : [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200]
        return !own.some(v => Math.abs(Number(v) - maximum) < 0.5)
    }
    readonly property bool cam1IsoSetByCamera: root.cam1S.iso_auto_after_clear_hdr === true || root.cam1IsoOnAddedCap
    readonly property bool cam1WbSetByCamera: root.cam1S.wb_auto_after_clear_hdr === true
    readonly property bool cam1ShutterSetByCamera: root.recordingActive && root.cam1S.fps_speed_ramp === true
                                                   && root.cam1S.fps_speed_ramp_keep_exposure === true
    readonly property string overlayFpsValue: root.overlayCam1 && root.cam1FpsNumber() > 0
                                              ? Number(root.cam1FpsNumber()).toFixed(3) : root.fpsDisplayValue
    readonly property string overlayIsoValue: root.overlayCam1 && root.cam1IsoInUse.length > 0 ? root.cam1IsoInUse : root.isoValue
    readonly property string overlayShutterValue: root.overlayCam1 && root.cam1ShutterAngle().length > 0
                                                  ? root.cam1ShutterAngle() : root.shutterDisplayValue
    readonly property string overlayWbValue: root.overlayCam1 && root.cam1WbInUse.length > 0 ? root.cam1WbInUse : root.wbValue
    readonly property string overlayFormatValue: root.overlayCam1
                                                 ? (root.cam1ProcessedVideo
                                                    ? root.cam1PreviewAspectResolution + " H.264"
                                                    : root.cam1RecordingFormat)
                                                 : root.formatInfoValue
    readonly property string cam1BitDepthValue: Number(root.cam1S.raw_bit_depth) > 0 ? Number(root.cam1S.raw_bit_depth) + "-bit" : ""
    readonly property bool cam1RawRecordFormat: root.cam1RecordingFormat.indexOf("ProRes") !== 0 && !root.cam1ProcessedVideo
    readonly property string overlayResolutionLine: root.overlayCam1 && root.cam1ResolutionValue.length > 0
                                                    ? root.cam1ResolutionValue
                                                      + (root.cam1RawRecordFormat && root.cam1BitDepthValue.length > 0
                                                         ? " \u00b7 " + root.cam1BitDepthValue + (root.cam1S.clear_hdr === true ? " \u00b7 Clear HDR" : "")
                                                         : "")
                                                    : root.resolutionLineValue
    // cam1's own mode, picked by closest() for a different sensor, is the system's: italic like the ladder's.
    readonly property bool overlayResolutionSystemChosen: root.overlayCam1 && root.cam1ModeSystemChosen

    // ---- Pane tags and frames (T66, section 5.0 with v2.5 A2) ----
    // cam1Settings (UI.conf) is "unison" or the comma list of controls tied to cam0. A tied control is
    // cam0's; resolution untied acts as Own, an untied iso, shutter, fps or wb as Independent for that control.
    function cam1Tied(control) {
        var ties = (settingsBridge && settingsBridge.cam1Settings !== undefined) ? String(settingsBridge.cam1Settings) : "unison"
        if (ties === "unison")
            return true
        return ("," + ties + ",").indexOf("," + control + ",") >= 0
    }
    readonly property bool cam1DifferentSensor: root.cam1Present
                                                && String(apertarControlBridge.cam1Sensor).length > 0
                                                && String(apertarControlBridge.sensorName).length > 0
                                                && String(apertarControlBridge.cam1Sensor).toLowerCase()
                                                   !== String(apertarControlBridge.sensorName).toLowerCase()
    // cam1's mode shows in its pane tag when its resolution is its own (Own), and for a different sensor
    // at every level; the closest-match pick (resolution tied) is the system's choice and goes italic.
    readonly property bool cam1ModeInTag: root.cam1Present && (!root.cam1Tied("resolution") || root.cam1DifferentSensor)
    readonly property bool cam1ModeSystemChosen: root.cam1DifferentSensor && root.cam1Tied("resolution")

    function compactNumber(value, decimals) {
        var text = Number(value).toFixed(decimals)
        if (text.indexOf(".") >= 0)
            text = text.replace(/0+$/, "").replace(/\.$/, "")
        return text
    }
    function cam1FpsNumber() {
        var value = Number(root.cam1S.fps)
        return value > 0 ? value : 0
    }
    function cam1IsoSet() {
        var s = root.cam1S
        if (s.iso_auto === true)
            return "Auto"
        return Number(s.iso) > 0 ? String(Math.round(Number(s.iso))) : ""
    }
    function cam1ShutterAngle() {
        var s = root.cam1S
        if (s.shutter_auto === true)
            return "Auto"
        var us = Number(s.shutter_us)
        var fps = root.cam1FpsNumber()
        if (!(us > 0) || !(fps > 0))
            return ""
        return root.compactNumber(Math.round(us * fps * 360 / 1000000 * 100) / 100, 2) + "\u00b0"
    }
    function cam1WbSet() {
        var s = root.cam1S
        if (s.wb_auto === true)
            return "Auto"
        return Number(s.wb_kelvin) > 0 ? String(Math.round(Number(s.wb_kelvin))) + "K" : ""
    }
    function cam1ModeText() {
        var res = root.cam1ResolutionValue
        if (res.length === 0)
            return ""
        var label = res === "1920x1080" ? "1080p" : (res === "3840x2160" ? "2160p" : res)
        var format = root.cam1RecordingFormat
        var tail = ""
        if (format.indexOf("ProRes") === 0)
            tail = "ProRes"
        else if (format === "H.264")
            tail = "H.264"
        else if (Number(root.cam1S.raw_bit_depth) > 0)
            tail = Number(root.cam1S.raw_bit_depth) + "-bit"
        return tail.length > 0 ? label + " \u00b7 " + tail : label
    }
    // The values of the untied controls that differ between the cameras, for one camera's tag (0 or 1).
    function differingValues(camera) {
        var out = []
        if (!root.cam1Present || !apertarControlBridge)
            return out
        if (!root.cam1Tied("iso")) {
            var iso0 = String(apertarControlBridge.iso)
            var iso1 = root.cam1IsoSet()
            if (iso1.length > 0 && iso0 !== iso1)
                out.push("ISO " + (camera === 1 ? iso1 : iso0))
        }
        if (!root.cam1Tied("shutter")) {
            var shutter0 = String(apertarControlBridge.shutterAngle)
            var shutter1 = root.cam1ShutterAngle()
            if (shutter1.length > 0 && shutter0 !== shutter1)
                out.push(camera === 1 ? shutter1 : shutter0)
        }
        if (!root.cam1Tied("fps")) {
            var fps0 = parseFloat(apertarControlBridge.fps)
            var fps1 = root.cam1FpsNumber()
            if (fps1 > 0 && Math.abs(fps0 - fps1) > 0.001)
                out.push(root.compactNumber(camera === 1 ? fps1 : fps0, 3) + " FPS")
        }
        if (!root.cam1Tied("wb")) {
            var wb0 = String(apertarControlBridge.whiteBalance)
            var wb1 = root.cam1WbSet()
            if (wb1.length > 0 && wb0 !== wb1)
                out.push(camera === 1 ? wb1 : wb0)
        }
        return out
    }
    // StyledText: the system-chosen mode is italic.
    function paneTagText(camera) {
        var parts = [camera === 1 ? "CAM1" : "CAM0"]
        if (camera === 1 && root.cam1ModeInTag) {
            var mode = root.cam1ModeText()
            if (mode.length > 0)
                parts.push(root.cam1ModeSystemChosen ? "<i>" + mode + "</i>" : mode)
        }
        var diffs = root.differingValues(camera)
        for (var i = 0; i < diffs.length; ++i)
            parts.push(diffs[i])
        return parts.join(" \u00b7 ")
    }

    // Which cameras the next or running take records (Core's record_cameras: cam0, cam1, both, none).
    readonly property string recordCamerasValue: apertarControlBridge ? String(apertarControlBridge.recordCameras) : ""
    readonly property bool cam0InTake: root.recordCamerasValue !== "cam1" && root.recordCamerasValue !== "none"
    readonly property bool cam1InTake: root.recordCamerasValue === "cam1" || root.recordCamerasValue === "both"
    readonly property bool cam0Recording: root.pillRecordingActive && root.cam0InTake
    readonly property bool cam1Recording: root.pillRecordingActive && root.cam1InTake
    readonly property bool mainRecording: root.swapped ? root.cam1Recording : root.cam0Recording
    readonly property bool secondRecording: root.swapped ? root.cam0Recording : root.cam1Recording

    // Geometry in the monitor surface's own coordinates (the surface is the rotated item).
    readonly property real paneDividerWidth: 4
    readonly property real paneHalfWidth: Math.floor((monitorSurface.width - root.paneDividerWidth) / 2)
    readonly property real mainPaneWidth: root.layoutKind === "both" ? root.paneHalfWidth : monitorSurface.width
    readonly property real mainPaneHeight: monitorSurface.height
    readonly property real secondPaneX: root.layoutKind === "both" ? root.paneHalfWidth + root.paneDividerWidth
                                                                    : monitorSurface.width - root.secondPaneWidth - monitorSurface.width * 0.03
    readonly property real secondPaneWidth: root.layoutKind === "both" ? monitorSurface.width - root.paneHalfWidth - root.paneDividerWidth
                                                                        : monitorSurface.width * 0.28
    // The inset's height follows its frame (U-new6); a pane in a Both view is as tall as the surface.
    readonly property real secondPaneHeight: root.layoutKind === "both" ? monitorSurface.height
                                                                         : root.secondPaneWidth / Math.max(0.1, root.secondDisplayAspect)
    readonly property real secondPaneY: root.layoutKind === "both" ? 0
                                                                    : monitorSurface.height - root.secondPaneHeight - monitorSurface.width * 0.03
    // The picture inside each pane, letterboxed (the renderer fits the same way).
    readonly property real mainFitWidth: (root.mainPaneWidth / Math.max(1, root.mainPaneHeight)) > root.mainDisplayAspect
                                         ? root.mainPaneHeight * root.mainDisplayAspect : root.mainPaneWidth
    readonly property real mainFitHeight: (root.mainPaneWidth / Math.max(1, root.mainPaneHeight)) > root.mainDisplayAspect
                                          ? root.mainPaneHeight : root.mainPaneWidth / root.mainDisplayAspect
    readonly property real mainFitX: Math.round((root.mainPaneWidth - root.mainFitWidth) / 2)
    readonly property real mainFitY: Math.round((root.mainPaneHeight - root.mainFitHeight) / 2)
    readonly property real secondFitWidth: (root.secondPaneWidth / Math.max(1, root.secondPaneHeight)) > root.secondDisplayAspect
                                           ? root.secondPaneHeight * root.secondDisplayAspect : root.secondPaneWidth
    readonly property real secondFitHeight: (root.secondPaneWidth / Math.max(1, root.secondPaneHeight)) > root.secondDisplayAspect
                                            ? root.secondPaneHeight : root.secondPaneWidth / root.secondDisplayAspect
    readonly property real secondFitX: root.secondPaneX + Math.round((root.secondPaneWidth - root.secondFitWidth) / 2)
    readonly property real secondFitY: root.secondPaneY + Math.round((root.secondPaneHeight - root.secondFitHeight) / 2)
    // ---- The CAM1 pill and the status pill's readouts (T66, section 5.2) ----
    readonly property string cam1StateValue: root.cam1Present ? String(apertarControlBridge.cam1State) : ""
    readonly property bool cam1Down: ["not_found", "offline", "refused", "lost", "standby"].indexOf(root.cam1StateValue) >= 0
    readonly property bool cam1ReadyToRecord: root.cam1StateValue === "ready" || root.cam1StateValue === "recording"
    // The shooting mode (UI.conf recordCameras). What it asks for, before the system drops a camera.
    readonly property string shootingMode: settingsBridge && settingsBridge.recordCamerasSetting ? settingsBridge.recordCamerasSetting : "Both"
    readonly property bool previewWantsCam1: ["Both", "Both (Cam 1 left)", "Cam 1", "PiP Cam 1"].indexOf(root.requestedSource) >= 0
    readonly property bool policyWantsCam1: root.cam1Present && !root.photoRule
                                            && (root.shootingMode === "Both" || root.shootingMode === "Cam 1"
                                                || (root.shootingMode === "Follow preview" && root.previewWantsCam1))
    // cam1 was asked for, a take runs, and cam1 is not in it: the pill blinks.
    readonly property bool cam1DroppedInTake: root.policyWantsCam1 && root.externalActiveCapture && !root.cam1InTake
    readonly property bool cam1NotSynced: root.pillRecordingActive && root.cam0InTake && root.cam1InTake && !apertarControlBridge.cam1Locked
    function cam1StateLabel(state) {
        if (state === "not_found")
            return "NOT FOUND"
        if (state === "recording")
            return "REC"
        return String(state).toUpperCase()
    }
    readonly property string cam1PillLabel: root.cam1NotSynced ? "NOT SYNCED" : root.cam1StateLabel(root.cam1StateValue)
    // red: in a take; amber: something is wrong; white: ready and in the next take; grey: ready, out of it.
    readonly property string cam1PillTone: {
        if (root.cam1Down || root.cam1NotSynced || root.cam1DroppedInTake
                || root.cam1StateValue === "busy" || root.cam1StateValue === "writing")
            return "amber"
        if (root.cam1Recording || root.cam1StateValue === "recording")
            return "red"
        return root.cam1InTake ? "white" : "grey"
    }
    // What a press records, when it is not just what this window shows. text is appended to READY or REC.
    readonly property var statusReadout: {
        var none = { text: "", italic: false, amber: false }
        var base = root.externalStatusLabel
        if (!root.cam1Present || root.photoRule || (base !== "READY" && base !== "REC"))
            return none
        var rc = root.recordCamerasValue
        // Frames came and stopped for a second: the press is refused (T69 checks it with a real cam1).
        if (base === "READY" && root.cam1ReadyToRecord && root.cam1InTake && root.cam1FrameCount > 0 && !root.cam1Signal)
            return { text: "CAM1 NO PICTURE", italic: false, amber: true }
        // No frame since the client connected: the press still records cam1.
        if (root.cam1ReadyToRecord && root.cam1InTake && root.cam1FrameCount === 0)
            return { text: rc === "cam1" ? "CAM1 ONLY \u00b7 NO SIGNAL" : "BOTH \u00b7 CAM1 NO SIGNAL", italic: false, amber: true }
        // The setting wants cam1 and the system dropped it: the system's choice, italic.
        if (root.policyWantsCam1 && !root.cam1InTake && rc !== "none" && rc !== "")
            return { text: "CAM0 ONLY \u00b7 CAM1 " + root.cam1StateLabel(root.cam1StateValue), italic: true, amber: false }
        if (rc === "cam1")
            return { text: "CAM1 ONLY", italic: false, amber: false }
        if (rc === "cam0" && root.viewHasCam1)
            return { text: "CAM0 ONLY", italic: false, amber: false }
        return none
    }
    readonly property string externalStatusText: root.statusReadout.text.length > 0
                                                 ? root.externalStatusLabel + " \u00b7 " + root.statusReadout.text
                                                 : root.externalStatusLabel

    property int timecodeFrames: 0
    property string localTimecode: "00:00:00:00"
    readonly property string timecode: synchronizedCaptureStateAvailable
                                       && monitorRuntimeBridge.timecode.length > 0
                                       ? monitorRuntimeBridge.timecode
                                       : localTimecode

    FontLoader { id: interRegular; source: "qrc:/qml/fonts/Inter/Inter-Regular.ttf" }
    FontLoader { id: interMedium; source: "qrc:/qml/fonts/Inter/Inter-Medium.ttf" }
    FontLoader { id: interBold; source: "qrc:/qml/fonts/Inter/Inter-Bold.ttf" }

    function anamorphicRatioValue(value) {
        if (!value || value.length === 0)
            return 1.33

        var normalized = value.replace("x", "")
        var parsed = Number(normalized)
        if (isNaN(parsed) || parsed < 1.0)
            return 1.33
        return parsed
    }

    function pad2(v) {
        return v < 10 ? "0" + v : "" + v
    }

    function currentFpsInt() {
        var parsed = parseFloat(root.fpsValue)
        if (isNaN(parsed) || parsed <= 0)
            return 24
        return Math.round(parsed)
    }

    function aspectRatioForResolution(resolutionValue) {
        var parts = String(resolutionValue || "").split("x")
        if (parts.length === 2) {
            var width = parseFloat(parts[0])
            var height = parseFloat(parts[1])
            if (width > 0 && height > 0)
                return width / height
        }
        return 16.0 / 9.0
    }

    function formatTimecode(totalFrames) {
        var fpsInt = currentFpsInt()
        var hours = Math.floor(totalFrames / (fpsInt * 3600))
        var remainder = totalFrames % (fpsInt * 3600)
        var minutes = Math.floor(remainder / (fpsInt * 60))
        remainder = remainder % (fpsInt * 60)
        var seconds = Math.floor(remainder / fpsInt)
        var frames = remainder % fpsInt
        return pad2(hours) + ":" + pad2(minutes) + ":" + pad2(seconds) + ":" + pad2(frames)
    }

    function updateTimecodeDisplay() {
        if (root.timecodeMode === "Free Run") {
            var now = new Date()
            var fpsInt = currentFpsInt()
            var frame = Math.floor((now.getMilliseconds() / 1000) * fpsInt)
            if (frame >= fpsInt)
                frame = fpsInt - 1

            root.localTimecode = pad2(now.getHours())
                               + ":" + pad2(now.getMinutes())
                               + ":" + pad2(now.getSeconds())
                               + ":" + pad2(frame)
        } else {
            root.localTimecode = root.formatTimecode(root.timecodeFrames)
        }
    }

    function triggerCaptureFeedback() {
        externalPhotoFlashOverlay.opacity = 0.0
        externalPhotoFramePulse.opacity = 0.0
        externalPhotoFramePulse.scale = 0.992
        externalPhotoCaptureFeedbackAnimation.restart()
    }

    function topHudSlotWidth(index, rowWidth) {
        if (index === 0 || index === root.topMonitorInfoItems.length - 1)
            return Math.max(220, rowWidth * 0.17)

        return Math.max(160, rowWidth * 0.125)
    }

    function topHudX(index, rowWidth) {
        var slotWidth = root.topHudSlotWidth(index, rowWidth)
        if (index === 0)
            return 0
        if (index === root.topMonitorInfoItems.length - 1)
            return rowWidth - slotWidth

        var positions = [0.29, 0.50, 0.71]
        return (rowWidth * positions[index - 1]) - (slotWidth / 2)
    }

    function updateHorizontalLevelPolling() {
        if (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) {
            gyroConfigBridge.setLivePollingRequest("external-horizontal-level",
                                                   root.horizontalLevelEnabled && !apertarControlBridge.standby,
                                                   true,
                                                   80)
        }
    }

    Component.onCompleted: {
        root.updateTimecodeDisplay()
        root.updateHorizontalLevelPolling()
    }

    onHorizontalLevelEnabledChanged: root.updateHorizontalLevelPolling()

    Connections {
        target: apertarControlBridge
        function onStandbyChanged() {
            root.updateHorizontalLevelPolling()
            if (apertarControlBridge.standby)
                apertarPreviewBridge.disconnectFromCore()
            else
                apertarPreviewBridge.connectToCore("/tmp/apertar-core.sock")
            // The cam1 client exists only in the normal process.
            if (typeof apertarPreviewBridge1 !== "undefined" && apertarPreviewBridge1) {
                if (!apertarControlBridge.standby
                        && (apertarControlBridge.cam1Present || (typeof cam1InsetTest !== "undefined" && cam1InsetTest)))
                    apertarPreviewBridge1.connectToCore("/tmp/apertar-core-cam1.sock")
                else
                    apertarPreviewBridge1.disconnectFromCore()
            }
        }
    }

    Component.onDestruction: {
        if (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge)
            gyroConfigBridge.setLivePollingRequest("external-horizontal-level", false, true, 80)
    }

    onTimecodeModeChanged: {
        if (root.timecodeMode === "Rec Run" && !root.recordingActive)
            root.timecodeFrames = 0
        root.updateTimecodeDisplay()
    }

    onRecordingActiveChanged: {
        if (!root.synchronizedCaptureStateAvailable
                && root.timecodeMode === "Rec Run"
                && root.recordingActive) {
            root.timecodeFrames = 0
        }
        root.updateTimecodeDisplay()
    }

    Connections {
        target: apertarPreviewBridge

        function onFrameArrived() {
            if (!root.synchronizedCaptureStateAvailable
                    && root.timecodeMode === "Rec Run"
                    && root.recordingActive) {
                root.timecodeFrames += 1
                root.updateTimecodeDisplay()
            }
        }
    }

    Connections {
        target: apertarControlBridge

        function onFpsChanged() {
            root.updateTimecodeDisplay()
        }

        function onPhotoCaptured() {
            root.triggerCaptureFeedback()
        }

        function onTimelapseFrameCaptured() {
            root.triggerCaptureFeedback()
        }
    }

    Timer {
        id: freeRunTimecodeTimer
        interval: Math.max(1, Math.round(1000 / root.currentFpsInt()))
        running: !apertarControlBridge.standby && !root.synchronizedCaptureStateAvailable && root.timecodeMode === "Free Run"
        repeat: true
        onTriggered: root.updateTimecodeDisplay()
    }

    Item {
        id: monitorSurface
        visible: !apertarControlBridge.standby
        width: root.monitorContentWidth
        height: root.monitorContentHeight
        anchors.centerIn: parent
        rotation: root.externalMonitorRotation
        transformOrigin: Item.Center

        StillExposureOverlay {
            anchors.fill: parent
            z: 1000
            controlBridge: apertarControlBridge
        }

        CameraPreviewItem {
            id: preview
            objectName: "externalPreviewItem"
            // The main pane: full screen, or the left half in a Both view. With the panes swapped it
            // takes cam1's bridge (the renderer resets its frame state on a bridge change). The aids
            // below are properties of this item alone; the second item sets none of them.
            x: 0
            y: 0
            width: root.mainPaneWidth
            height: root.mainPaneHeight
            visible: root.mainPaneVisible
            bridge: (root.swapped && root.cam1Available) ? apertarPreviewBridge1 : apertarPreviewBridge
            zoom: 1.0
            panX: 0.0
            panY: 0.0
            zebraEnabled: root.overlayFeedEnabled && settingsBridge ? settingsBridge.zebraEnabled : false
            zebraThreshold: settingsBridge ? settingsBridge.zebraThreshold : 0.70
            focusPeakingEnabled: root.overlayFeedEnabled && settingsBridge ? settingsBridge.focusPeakingEnabled : false
            focusPeakingThreshold: settingsBridge ? settingsBridge.focusPeakingThreshold : 0.04
            focusPeakingColor: settingsBridge ? settingsBridge.focusPeakingColor : "Red"
            grayscaleEnabled: root.overlayFeedEnabled && settingsBridge ? settingsBridge.grayscaleEnabled : false
            smpteEnabled: root.smpteEnabled
            anamorphicDesqueezeEnabled: settingsBridge ? settingsBridge.anamorphicDesqueezeEnabled : false
            anamorphicDesqueezeRatio: root.anamorphicRatioValue(settingsBridge ? settingsBridge.anamorphicRatio : "1.33x")
            falseColorEnabled: root.overlayFeedEnabled && settingsBridge ? settingsBridge.falseColorEnabled : false
            falseColorMode: settingsBridge ? settingsBridge.falseColorMode : 0
            lutPreviewEnabled: settingsBridge ? settingsBridge.lutPreviewEnabled : false
            lutPreviewFile: settingsBridge ? settingsBridge.lutPreviewFile : ""
            // The reference is cam0's; a cam1 main pane has none of its own yet.
            exposureReference: apertarControlBridge && !root.swapped ? apertarControlBridge.previewExposureReference : ({})
            displayRotation: root.externalMonitorRotation
            previewAspectRatio: root.previewImageAspectRatio
        }

        // The second pane (cam1, or cam0 when swapped): the right half of a Both view, or the inset in PiP.
        // It keeps the display transforms (LUT, desqueeze, SMPTE, rotation, aspect) and none of the aids
        // (zebra, peaking, false colour, greyscale): those are per-item properties and stay at their
        // defaults here (off).
        CameraPreviewItem {
            id: preview1
            objectName: "externalPreviewItem1"
            bridge: root.cam1Available ? (root.swapped ? apertarPreviewBridge : apertarPreviewBridge1) : null
            visible: root.cam1Available && root.secondPaneVisible
            x: root.secondPaneX
            y: root.secondPaneY
            width: root.secondPaneWidth
            height: root.secondPaneHeight
            z: 5
            zoom: 1.0
            panX: 0.0
            panY: 0.0
            smpteEnabled: root.smpteEnabled
            anamorphicDesqueezeEnabled: settingsBridge ? settingsBridge.anamorphicDesqueezeEnabled : false
            anamorphicDesqueezeRatio: root.anamorphicRatioValue(settingsBridge ? settingsBridge.anamorphicRatio : "1.33x")
            lutPreviewEnabled: settingsBridge ? settingsBridge.lutPreviewEnabled : false
            lutPreviewFile: settingsBridge ? settingsBridge.lutPreviewFile : ""
            displayRotation: root.externalMonitorRotation
            previewAspectRatio: root.secondImageAspect
        }

        // The divider between the panes of a Both view.
        Rectangle {
            visible: root.layoutKind === "both"
            x: root.paneHalfWidth
            y: 0
            width: root.paneDividerWidth
            height: parent.height
            color: "#262626"
            z: 6
        }

        // A Both pane whose camera is cam1 while cam1 sends nothing: black, with the reason.
        Text {
            visible: root.cam1PaneMissing
            x: root.swapped ? 0 : root.secondPaneX
            y: 0
            width: root.swapped ? root.mainPaneWidth : root.secondPaneWidth
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "CAM1 NO SIGNAL"
            color: "#ffd54a"
            font.family: interBold.font.family
            font.pixelSize: 26
            font.letterSpacing: 2.0
            renderType: Text.NativeRendering
            z: 6
        }

        // Each pane gets a 2 px white frame around its picture, red while its camera records.
        Rectangle {
            visible: root.layoutKind !== "single"
            x: root.mainFitX
            y: root.mainFitY
            width: root.mainFitWidth
            height: root.mainFitHeight
            color: "transparent"
            border.width: 2
            border.color: root.mainRecording ? "#ff4d4d" : "white"
            z: 7
        }

        Rectangle {
            visible: root.layoutKind !== "single"
            x: root.secondFitX
            y: root.secondFitY
            width: root.secondFitWidth
            height: root.secondFitHeight
            color: "transparent"
            border.width: 2
            border.color: root.secondRecording ? "#ff4d4d" : "white"
            z: 7
        }

        // Pane tags of the Both views: the camera, its mode when it is cam1's own or another sensor's,
        // and the values that differ.
        Rectangle {
            visible: root.layoutKind === "both"
            x: root.mainFitX + 12
            y: root.mainFitY + 12
            width: mainPaneTagText.implicitWidth + 20
            height: mainPaneTagText.implicitHeight + 10
            radius: 6
            color: "#99000000"
            z: 8

            Text {
                id: mainPaneTagText
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: root.paneTagText(root.swapped ? 1 : 0)
                color: "white"
                font.family: interBold.font.family
                font.pixelSize: 18
                font.letterSpacing: 1.4
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            visible: root.layoutKind === "both"
            x: root.secondFitX + 12
            y: root.secondFitY + 12
            width: secondPaneTagText.implicitWidth + 20
            height: secondPaneTagText.implicitHeight + 10
            radius: 6
            color: "#99000000"
            z: 8

            Text {
                id: secondPaneTagText
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: root.paneTagText(root.swapped ? 0 : 1)
                color: "white"
                font.family: interBold.font.family
                font.pixelSize: 18
                font.letterSpacing: 1.4
                renderType: Text.NativeRendering
            }
        }

        // Cam 1 and PiP Cam 1 fall back to cam0 full screen when cam1 sends no frames.
        Rectangle {
            visible: root.cam1FallbackBanner
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36 + 58 + 12
            width: fallbackBannerText.implicitWidth + 28
            height: 36
            radius: 18
            color: "#e63b2a13"
            border.width: 1
            border.color: "#bfaa7937"
            z: 21

            Text {
                id: fallbackBannerText
                anchors.centerIn: parent
                text: "CAM1 NO SIGNAL \u00b7 SHOWING CAM0"
                color: "#ffd27a"
                font.family: interBold.font.family
                font.pixelSize: 17
                font.letterSpacing: 1.6
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            id: externalPhotoFlashOverlay
            anchors.fill: parent
            color: "white"
            opacity: 0.0
            visible: opacity > 0.01
            z: 80
        }

        Rectangle {
            id: externalPhotoFramePulse
            anchors.fill: parent
            anchors.margins: 18
            radius: 32
            color: "transparent"
            border.width: 3
            border.color: "white"
            opacity: 0.0
            scale: 0.992
            visible: opacity > 0.01
            z: 81
        }

        SequentialAnimation {
            id: externalPhotoCaptureFeedbackAnimation

            ScriptAction {
                script: {
                    externalPhotoFlashOverlay.opacity = 0.0
                    externalPhotoFramePulse.opacity = 0.0
                    externalPhotoFramePulse.scale = 0.992
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: externalPhotoFlashOverlay
                    property: "opacity"
                    from: 0.58
                    to: 0.0
                    duration: 320
                    easing.type: Easing.OutCubic
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: externalPhotoFramePulse
                        property: "opacity"
                        from: 0.88
                        to: 0.48
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: externalPhotoFramePulse
                        property: "opacity"
                        to: 0.0
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                NumberAnimation {
                    target: externalPhotoFramePulse
                    property: "scale"
                    from: 0.992
                    to: 1.018
                    duration: 460
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: guideOverlay
            anchors.fill: parent
            z: 12
            layer.enabled: root.showThirdsGuides || root.showAspectGuides || root.centerMarkerEnabled
            layer.smooth: false

            readonly property real activeAspectRatio: root.previewDisplayAspectRatio
            readonly property real activeImageWidth: (parent.width / Math.max(1, parent.height)) > activeAspectRatio
                                                     ? parent.height * activeAspectRatio
                                                     : parent.width
            readonly property real activeImageHeight: (parent.width / Math.max(1, parent.height)) > activeAspectRatio
                                                      ? parent.height
                                                      : parent.width / activeAspectRatio
            readonly property real activeImageX: Math.round((parent.width - activeImageWidth) / 2)
            readonly property real activeImageY: Math.round((parent.height - activeImageHeight) / 2)
            readonly property real aspectGuideWidth: root.showAspectGuides
                                                     ? ((activeImageWidth / activeImageHeight) > root.selectedAspectRatio
                                                        ? activeImageHeight * root.selectedAspectRatio
                                                        : activeImageWidth)
                                                     : 0
            readonly property real aspectGuideHeight: root.showAspectGuides
                                                      ? ((activeImageWidth / activeImageHeight) > root.selectedAspectRatio
                                                         ? activeImageHeight
                                                         : activeImageWidth / root.selectedAspectRatio)
                                                      : 0

            Rectangle {
            visible: root.showThirdsGuides
            width: root.guideStrokeWidth
            color: root.guideShadowColor
            x: Math.round(guideOverlay.activeImageX + (guideOverlay.activeImageWidth / 3)) + root.guideShadowOffset
            y: guideOverlay.activeImageY + root.guideShadowOffset
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            width: root.guideStrokeWidth
            color: "#5cffffff"
            x: Math.round(guideOverlay.activeImageX + (guideOverlay.activeImageWidth / 3))
            y: guideOverlay.activeImageY
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            width: root.guideStrokeWidth
            color: root.guideShadowColor
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth * 2) / 3)) + root.guideShadowOffset
            y: guideOverlay.activeImageY + root.guideShadowOffset
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            width: root.guideStrokeWidth
            color: "#5cffffff"
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth * 2) / 3))
            y: guideOverlay.activeImageY
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            height: root.guideStrokeWidth
            color: root.guideShadowColor
            x: guideOverlay.activeImageX + root.guideShadowOffset
            y: Math.round(guideOverlay.activeImageY + (guideOverlay.activeImageHeight / 3)) + root.guideShadowOffset
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            height: root.guideStrokeWidth
            color: "#5cffffff"
            x: guideOverlay.activeImageX
            y: Math.round(guideOverlay.activeImageY + (guideOverlay.activeImageHeight / 3))
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            height: root.guideStrokeWidth
            color: root.guideShadowColor
            x: guideOverlay.activeImageX + root.guideShadowOffset
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight * 2) / 3)) + root.guideShadowOffset
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showThirdsGuides
            height: root.guideStrokeWidth
            color: "#5cffffff"
            x: guideOverlay.activeImageX
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight * 2) / 3))
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            width: root.guideStrokeWidth
            color: root.guideShadowColor
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth - guideOverlay.aspectGuideWidth) / 2)) + root.guideShadowOffset
            y: guideOverlay.activeImageY + root.guideShadowOffset
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            width: root.guideStrokeWidth
            color: "#5cffffff"
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth - guideOverlay.aspectGuideWidth) / 2))
            y: guideOverlay.activeImageY
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            width: root.guideStrokeWidth
            color: root.guideShadowColor
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth + guideOverlay.aspectGuideWidth) / 2)) + root.guideShadowOffset
            y: guideOverlay.activeImageY + root.guideShadowOffset
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            width: root.guideStrokeWidth
            color: "#5cffffff"
            x: Math.round(guideOverlay.activeImageX + ((guideOverlay.activeImageWidth + guideOverlay.aspectGuideWidth) / 2))
            y: guideOverlay.activeImageY
            height: guideOverlay.activeImageHeight
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            height: root.guideStrokeWidth
            color: root.guideShadowColor
            x: guideOverlay.activeImageX + root.guideShadowOffset
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight - guideOverlay.aspectGuideHeight) / 2)) + root.guideShadowOffset
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            height: root.guideStrokeWidth
            color: "#5cffffff"
            x: guideOverlay.activeImageX
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight - guideOverlay.aspectGuideHeight) / 2))
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            height: root.guideStrokeWidth
            color: root.guideShadowColor
            x: guideOverlay.activeImageX + root.guideShadowOffset
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight + guideOverlay.aspectGuideHeight) / 2)) + root.guideShadowOffset
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.showAspectGuides
            height: root.guideStrokeWidth
            color: "#5cffffff"
            x: guideOverlay.activeImageX
            y: Math.round(guideOverlay.activeImageY + ((guideOverlay.activeImageHeight + guideOverlay.aspectGuideHeight) / 2))
            width: guideOverlay.activeImageWidth
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Circle/Dot"
            width: 108
            height: 108
            radius: 54
            color: "transparent"
            border.width: 2
            border.color: root.guideShadowColor
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.guideShadowOffset
            anchors.verticalCenterOffset: root.guideShadowOffset
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Circle/Dot"
            width: 108
            height: 108
            radius: 54
            color: "transparent"
            border.width: 2
            border.color: "#4dffffff"
            anchors.centerIn: parent
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Circle/Dot"
            width: 15
            height: 15
            radius: 7.5
            color: root.guideShadowColor
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.guideShadowOffset
            anchors.verticalCenterOffset: root.guideShadowOffset
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Circle/Dot"
            width: 15
            height: 15
            radius: 7.5
            color: "white"
            anchors.centerIn: parent
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Crosshair"
            width: 2
            height: 96
            color: root.guideShadowColor
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.guideShadowOffset
            anchors.verticalCenterOffset: root.guideShadowOffset
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Crosshair"
            width: 2
            height: 96
            color: "#4dffffff"
            anchors.centerIn: parent
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Crosshair"
            width: 96
            height: 2
            color: root.guideShadowColor
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.guideShadowOffset
            anchors.verticalCenterOffset: root.guideShadowOffset
            antialiasing: false
        }

            Rectangle {
            visible: root.centerMarkerEnabled && root.centerMarkerType === "Crosshair"
            width: 96
            height: 2
            color: "#4dffffff"
            anchors.centerIn: parent
            antialiasing: false
        }
        }

        HorizontalLevelOverlay {
            id: horizontalLevelOverlay
            z: 17
            anchors.fill: parent
            levelEnabled: root.horizontalLevelEnabled
            smpteEnabled: root.smpteEnabled
            previewAspectRatio: root.previewDisplayAspectRatio
            orientation: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.orientation : "XYZ"
            liveAvailable: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.liveAvailable : false
            liveStatusText: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.liveStatusText : "Live gyro unavailable"
            accelXG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.accelXG : 0
            accelYG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.accelYG : 0
            accelZG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.accelZG : 0
            levelReferenceSet: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.levelReferenceSet : false
            levelAccelXG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.levelAccelXG : 0
            levelAccelYG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.levelAccelYG : 0
            levelAccelZG: (typeof gyroConfigBridge !== "undefined" && gyroConfigBridge) ? gyroConfigBridge.levelAccelZG : 0
            levelColor: settingsBridge ? settingsBridge.horizontalLevelColor : "Blue"
            large: true
            compact: false
        }

        FalseColorLegend {
            id: falseColorLegend
            z: 18
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            layer.enabled: root.falseColorLegendVisible
            layer.smooth: true
            mode: settingsBridge ? settingsBridge.falseColorMode === 0 ? "Exposure Based"
                                   : settingsBridge.falseColorMode === 1 ? "Skin Tone"
                                   : settingsBridge.falseColorMode === 2 ? "Highlight Priority"
                                   : settingsBridge.falseColorMode === 3 ? "Shadow Priority"
                                   : "Exposure Based"
                                : "Exposure Based"
            opacity: root.falseColorLegendVisible ? 1.0 : 0.0
            scale: root.falseColorLegendVisible ? 1.68 : 1.58
        }

        Item {
            anchors.fill: parent
            anchors.margins: 36
            z: 20
            visible: root.infoOverlayEnabled && !root.smpteEnabled

            Item {
            id: topInfoRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 58
            layer.enabled: visible
            layer.smooth: true

            Repeater {
                model: root.topMonitorInfoItems

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: root.topHudSlotWidth(index, topInfoRow.width)
                    height: topInfoRow.height
                    x: root.topHudX(index, topInfoRow.width)

                    Column {
                        id: infoColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 2

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: labelText.implicitWidth + root.hudShadowOffset
                            height: labelText.implicitHeight + root.hudShadowOffset

                            Text {
                                x: root.hudShadowOffset
                                y: root.hudShadowOffset
                                text: modelData.label
                                color: root.hudShadowColor
                                font.family: interBold.font.family
                                font.pixelSize: 13
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 2.0
                                renderType: Text.NativeRendering
                            }

                            Text {
                                id: labelText
                                text: modelData.label
                                color: "#b8ffffff"
                                font.family: interBold.font.family
                                font.pixelSize: 13
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 2.0
                                style: Text.Outline
                                styleColor: "#a0000000"
                                renderType: Text.NativeRendering
                            }
                        }

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: valueText.implicitWidth + root.hudShadowOffset
                            height: valueText.implicitHeight + root.hudShadowOffset

                            Text {
                                x: root.hudShadowOffset
                                y: root.hudShadowOffset
                                text: modelData.value
                                color: root.hudShadowColor
                                font.family: interBold.font.family
                                font.pixelSize: 34
                                renderType: Text.NativeRendering
                            }

                            Text {
                                id: valueText
                                text: modelData.value
                                // Italic: a value the camera decides (held for Clear HDR, an added cap, a ramp angle).
                                color: "white"
                                font.italic: modelData.cameraSet === true
                                font.family: interBold.font.family
                                font.pixelSize: 34
                                style: Text.Outline
                                styleColor: "#a0000000"
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }

            // Camera badge: names the main camera's picture whenever cam1 is configured. A Both view's pane
            // tags name the cameras, so the badge is off there. Photo and timelapse show cam0 tagged.
            Rectangle {
                visible: root.cam1Present && root.layoutKind !== "both"
                x: 0
                y: topInfoRow.height + 8
                width: cameraBadgeText.implicitWidth + 20
                height: cameraBadgeText.implicitHeight + 8
                radius: 6
                color: "#99000000"
                border.width: 1
                border.color: "#33ffffff"

                Text {
                    id: cameraBadgeText
                    anchors.centerIn: parent
                    text: root.photoRule && root.requestedSource !== "Cam 0" ? "PHOTO \u00b7 CAM0"
                          : (root.overlayCam1 ? "CAM1" : "CAM0")
                    color: "white"
                    font.family: interBold.font.family
                    font.pixelSize: 18
                    font.letterSpacing: 1.6
                    renderType: Text.NativeRendering
                }
            }

            Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 2
            layer.enabled: visible
            layer.smooth: true

            Item {
                width: resolutionLabel.implicitWidth + root.hudShadowOffset
                height: resolutionLabel.implicitHeight + root.hudShadowOffset

                Text {
                    x: root.hudShadowOffset
                    y: root.hudShadowOffset
                    text: "RESOLUTION"
                    color: root.hudShadowColor
                    font.family: interBold.font.family
                    font.pixelSize: 13
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2.0
                    renderType: Text.NativeRendering
                }

                Text {
                    id: resolutionLabel
                    text: "RESOLUTION"
                    color: "#b8ffffff"
                    font.family: interBold.font.family
                    font.pixelSize: 13
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2.0
                    style: Text.Outline
                    styleColor: "#a0000000"
                    renderType: Text.NativeRendering
                }
            }

            Item {
                width: resolutionText.implicitWidth + root.hudShadowOffset
                height: resolutionText.implicitHeight + root.hudShadowOffset

                Text {
                    x: root.hudShadowOffset
                    y: root.hudShadowOffset
                    text: root.overlayResolutionLine
                    font.italic: root.overlayResolutionSystemChosen
                    color: root.hudShadowColor
                    font.family: interBold.font.family
                    font.pixelSize: 34
                    renderType: Text.NativeRendering
                }

                Text {
                    id: resolutionText
                    text: root.overlayResolutionLine
                    font.italic: root.overlayResolutionSystemChosen
                    color: "white"
                    font.family: interBold.font.family
                    font.pixelSize: 34
                    style: Text.Outline
                    styleColor: "#a0000000"
                    renderType: Text.NativeRendering
                }
            }
        }

            Column {
            id: centerHud
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10

            Rectangle {
                id: hdmiAudioMeterPanel
                anchors.horizontalCenter: parent.horizontalCenter
                width: 304
                height: 40
                visible: root.showAudioMeter
                radius: 10
                color: "#38000000"
                border.width: 1
                border.color: (root.recordingActive && root.recordAudioEnabled && root.audioInputAvailable
                               && (!settingsBridge || settingsBridge.audioRecordedOutlineEnabled)) ? "#73fb2c36"
                              : (root.inputVolumeLevel <= 0 ? "#664a2f2f" : "#26ffffff")
                layer.enabled: visible
                layer.smooth: true

                readonly property int meterLevel: root.localAudioMeterAvailable
                                                  ? audioMeterBridge.inputLevel
                                                  : (apertarControlBridge
                                                     ? apertarControlBridge.audioInputLevel
                                                     : 0)
                readonly property real normalizedLevel: Math.max(0, Math.min(1, meterLevel / 100))
                readonly property int segmentCount: 18

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        id: audioMeterIconHolder
                        width: 28
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.inputVolumeLevel <= 0 ? "#4b1f1f" : "#18ffffff"
                        border.width: 1
                        border.color: root.inputVolumeLevel <= 0 ? "#8f3d3d" : "#1affffff"

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: root.inputVolumeLevel <= 0
                                    ? "qrc:/qml/icons/microphone-muted.png"
                                    : "qrc:/qml/icons/microphone.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    Rectangle {
                        width: parent.width - parent.spacing - audioMeterIconHolder.width
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 3
                        color: "#10000000"
                        border.width: 1
                        border.color: "#1affffff"

                        Item {
                            anchors.fill: parent
                            anchors.margins: 2

                            Row {
                                anchors.fill: parent
                                spacing: 2

                                Repeater {
                                    model: hdmiAudioMeterPanel.segmentCount

                                    delegate: Rectangle {
                                        readonly property real threshold: (index + 1) / hdmiAudioMeterPanel.segmentCount

                                        width: (parent.width - ((hdmiAudioMeterPanel.segmentCount - 1) * 2)) / hdmiAudioMeterPanel.segmentCount
                                        height: parent.height
                                        radius: 1
                                        color: root.inputVolumeLevel <= 0
                                               ? "#382020"
                                               : (hdmiAudioMeterPanel.normalizedLevel >= threshold
                                                  ? (threshold > 0.84 ? "#ff5d5d"
                                                     : threshold > 0.62 ? "#ffd55a"
                                                     : "#4ce28f")
                                                  : "#172126")

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 95
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: externalStatusPill
                anchors.horizontalCenter: parent.horizontalCenter
                width: statusRow.implicitWidth + 28
                height: 44
                radius: 22
                color: root.externalStatusFill
                border.width: 1
                border.color: root.externalStatusBorder
                layer.enabled: visible
                layer.smooth: true

                Behavior on color {
                    ColorAnimation { duration: 220 }
                }

                Behavior on border.color {
                    ColorAnimation { duration: 220 }
                }

                // Safety stop (buffer full): READY green pill, no dot or text, green bar emptying.
                readonly property bool drainOnly: !!apertarControlBridge && apertarControlBridge.bufferSafetyStop
                                                  && !root.externalActiveCapture
                                                  && !!settingsBridge && settingsBridge.frameBufferBarEnabled
                                                  && apertarControlBridge.bufferMode !== "none"

                // Frame buffer bar: red fill from the left, behind the dot and text. A clipped Item of the fill's
                // width holds a copy of the pill's own shape, so the pill's rounded ends crop the bar.
                Item {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: externalStatusPill.border.width
                    width: Math.max(0, (externalStatusPill.width - 2 * externalStatusPill.border.width)
                                       * (apertarControlBridge ? apertarControlBridge.bufferFill : 0.0))
                    clip: true
                    visible: !!settingsBridge && settingsBridge.frameBufferBarEnabled
                             && !!apertarControlBridge && apertarControlBridge.bufferMode !== "none"

                    Behavior on width {
                        NumberAnimation { duration: 150 }
                    }

                    Rectangle {
                        x: 0
                        y: 0
                        width: externalStatusPill.width - 2 * externalStatusPill.border.width
                        height: externalStatusPill.height - 2 * externalStatusPill.border.width
                        radius: Math.max(0, externalStatusPill.radius - externalStatusPill.border.width)
                        color: externalStatusPill.drainOnly ? "#00c951" : "#fb2c36"
                        opacity: 0.85
                    }
                }

                // Clip merge (all clips): a faint grey fill in the READY pill that empties as the clips are merged,
                // as StatusChip on the camera page.
                Item {
                    readonly property real progress: !!apertarControlBridge && apertarControlBridge.clipMergeEnabled
                                                     && apertarControlBridge.clipMergeAllClips > 0 && apertarControlBridge.clipMergeAllTotal > 0
                                                     && apertarControlBridge.clipMergePaused === ""
                                                     ? apertarControlBridge.clipMergeAllDone / apertarControlBridge.clipMergeAllTotal : -1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: externalStatusPill.border.width
                    width: Math.max(0, (externalStatusPill.width - 2 * externalStatusPill.border.width) * (1 - Math.min(1, progress)))
                    clip: true
                    visible: progress >= 0 && root.externalStatusLabel === "READY" && !externalStatusPill.drainOnly

                    Behavior on width {
                        NumberAnimation { duration: 400 }
                    }

                    Rectangle {
                        width: externalStatusPill.width - 2 * externalStatusPill.border.width
                        height: externalStatusPill.height - 2 * externalStatusPill.border.width
                        radius: Math.max(0, externalStatusPill.radius - externalStatusPill.border.width)
                        color: "#ffffff"
                        opacity: 0.18
                    }
                }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    opacity: externalStatusPill.drainOnly ? 0.0 : 1.0
                    spacing: 10

                    Item {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            radius: 8
                            color: root.externalStatusDot
                            opacity: root.externalActiveCapture && !root.externalNoMedia ? 0.22 : 0.0
                            visible: root.externalActiveCapture && !root.externalNoMedia
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            radius: 6
                            color: root.externalStatusDot
                        }
                    }

                    Text {
                        text: root.externalStatusText
                        // Italic: the system chose it (a dropped cam1). Amber: cam1 has no signal or picture.
                        font.italic: root.statusReadout.italic
                        color: root.statusReadout.amber ? "#ffd54a" : "white"
                        font.family: interBold.font.family
                        font.pixelSize: 20
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.8
                        style: Text.Outline
                        styleColor: "#cc000000"
                        renderType: Text.NativeRendering
                    }

                    DroppedFrameWarning {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        visible: apertarControlBridge ? apertarControlBridge.recordingHasDroppedFrames : false
                        count: apertarControlBridge ? apertarControlBridge.recordingDroppedFrames : 0
                    }
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: timecodeText.implicitWidth + root.hudShadowOffset
                height: timecodeText.implicitHeight + root.hudShadowOffset

                Text {
                    x: root.hudShadowOffset
                    y: root.hudShadowOffset
                    text: root.timecode
                    color: root.hudShadowColor
                    font.family: interBold.font.family
                    font.pixelSize: 42
                    renderType: Text.NativeRendering
                }

                Text {
                    id: timecodeText
                    text: root.timecode
                    color: root.recordingActive && (!settingsBridge || settingsBridge.recordingRedTimecodeEnabled) ? "#ff4d4d" : "white"
                    font.family: interBold.font.family
                    font.pixelSize: 42
                    style: Text.Outline
                    styleColor: "#a0000000"
                    renderType: Text.NativeRendering
                }
            }
        }

        // CAM1 pill beside the status pill: cam1's state and drops, built like DroppedFrameWarning.
        Rectangle {
            id: cam1Pill
            visible: root.cam1Present
            x: centerHud.x + externalStatusPill.x + externalStatusPill.width + 12
            y: centerHud.y + externalStatusPill.y + (externalStatusPill.height - height) / 2
            height: 36
            width: cam1PillRow.implicitWidth + 24
            radius: height / 2
            color: root.cam1PillTone === "red" ? "#80b71212"
                   : root.cam1PillTone === "amber" ? "#e63b2a13"
                   : root.cam1PillTone === "white" ? "#70000000" : "#50000000"
            border.width: 1
            border.color: root.cam1PillTone === "red" ? "#66ff6666"
                          : root.cam1PillTone === "amber" ? "#bfaa7937"
                          : root.cam1PillTone === "white" ? "#66ffffff" : "#26ffffff"
            layer.enabled: visible
            layer.smooth: true

            Accessible.role: Accessible.StaticText
            Accessible.name: "CAM1 " + root.cam1PillLabel

            Row {
                id: cam1PillRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CAM1 " + root.cam1PillLabel
                    color: root.cam1PillTone === "amber" ? "#ffd27a"
                           : root.cam1PillTone === "grey" ? "#8f9096" : "white"
                    font.family: interBold.font.family
                    font.pixelSize: 16
                    font.letterSpacing: 1.4
                    renderType: Text.NativeRendering
                }

                DroppedFrameWarning {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    visible: root.cam1Recording && apertarControlBridge.cam1RecordingDroppedFrames > 0
                    count: apertarControlBridge.cam1RecordingDroppedFrames
                }
            }

            // Blinks while a take that wants cam1 runs without it.
            SequentialAnimation {
                running: root.cam1DroppedInTake
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: cam1Pill; property: "opacity"; to: 0.35; duration: 500 }
                NumberAnimation { target: cam1Pill; property: "opacity"; to: 1.0; duration: 500 }
            }
        }

        Column {
            id: remainingColumn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Math.max(remainingLabelItem.width, remainingValueItem.width)
            spacing: 2
            layer.enabled: visible
            layer.smooth: true

            Item {
                id: remainingLabelItem
                anchors.right: parent.right
                width: remainingLabel.implicitWidth + root.hudShadowOffset
                height: remainingLabel.implicitHeight + root.hudShadowOffset

                Text {
                    x: root.hudShadowOffset
                    y: root.hudShadowOffset
                    text: "REMAINING"
                    color: root.hudShadowColor
                    font.family: interBold.font.family
                    font.pixelSize: 13
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2.0
                    renderType: Text.NativeRendering
                }

                Text {
                    id: remainingLabel
                    anchors.right: parent.right
                    text: "REMAINING"
                    color: "#b8ffffff"
                    font.family: interBold.font.family
                    font.pixelSize: 13
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2.0
                    style: Text.Outline
                    styleColor: "#a0000000"
                    renderType: Text.NativeRendering
                }
            }

            Item {
                id: remainingValueItem
                anchors.right: parent.right
                width: remainingText.implicitWidth + root.hudShadowOffset
                height: remainingText.implicitHeight + root.hudShadowOffset

                Text {
                    x: root.hudShadowOffset
                    y: root.hudShadowOffset
                    text: root.remainingValue
                    color: root.hudShadowColor
                    font.family: interBold.font.family
                    font.pixelSize: 34
                    renderType: Text.NativeRendering
                }

                Text {
                    id: remainingText
                    anchors.right: parent.right
                    text: root.remainingValue
                    color: "white"
                    font.family: interBold.font.family
                    font.pixelSize: 34
                    style: Text.Outline
                    styleColor: "#a0000000"
                    renderType: Text.NativeRendering
                }
            }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#cc000000"
        visible: root.shutdownPopupVisible
        opacity: root.shutdownPopupVisible ? 1.0 : 0.0
        z: 5000

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        width: 440
        height: 272
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10
        radius: 26
        color: "#151515"
        border.width: 1
        border.color: "#1affffff"
        visible: root.shutdownPopupVisible
        opacity: root.shutdownPopupVisible ? 1.0 : 0.0
        scale: root.shutdownPopupVisible ? 1.0 : 0.96
        z: 5001

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            anchors.bottomMargin: 30
            spacing: 14

            Text {
                text: "Shutdown System?"
                color: "white"
                font.family: interBold.font.family
                font.pixelSize: 28
                renderType: Text.NativeRendering
            }

            Text {
                text: root.shutdownPopupTriggered
                      ? "Shutting down..."
                      : "Hold the physical power button or press and hold below for 3 seconds to confirm shutdown."
                color: "#8f9096"
                font.family: interRegular.font.family
                font.pixelSize: 17
                wrapMode: Text.WordWrap
                width: parent.width
                renderType: Text.NativeRendering
            }

            Rectangle {
                width: parent.width
                height: 62
                radius: 18
                clip: true
                color: root.shutdownHoldActive ? "#a32828" : "#171717"
                border.width: 1
                border.color: "#ba4a4a"
                opacity: root.shutdownPopupTriggered ? 0.85 : 1.0

                Rectangle {
                    x: 1
                    y: 1
                    width: (parent.width - 2) * root.shutdownHoldProgress
                    height: parent.height - 2
                    radius: parent.radius - 1
                    color: "#c84242"
                    opacity: 0.6
                }

                Text {
                    anchors.centerIn: parent
                    text: root.shutdownPopupTriggered
                          ? "Shutting Down..."
                          : (root.shutdownHoldActive ? "Keep Holding..." : "Hold to Shut Down")
                    color: "#ffd6d6"
                    font.family: interMedium.font.family
                    font.pixelSize: 17
                    renderType: Text.NativeRendering
                }
            }

            Text {
                visible: root.shutdownErrorText.length > 0
                text: root.shutdownErrorText
                color: "#ff9b9b"
                font.family: interRegular.font.family
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                width: parent.width
                renderType: Text.NativeRendering
            }

            Rectangle {
                width: parent.width
                height: 54
                radius: 18
                color: "#14ffffff"
                border.width: 1
                border.color: "#1affffff"
                opacity: root.shutdownPopupTriggered ? 0.45 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: "Waiting for Main Screen"
                    color: "white"
                    font.family: interMedium.font.family
                    font.pixelSize: 18
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // Recording frame (request 25): a red border at the monitor's edges during a take.
    Rectangle {
        anchors.fill: parent
        z: 10000
        color: "transparent"
        border.color: "#ff4d4d"
        border.width: Math.max(4, Math.round(Math.min(width, height) * 0.008))
        visible: root.recordingActive && !!settingsBridge && settingsBridge.recordingFrameEnabled
                 && root.layoutKind !== "both" && (!root.cam1Present || root.mainRecording)
    }
}
