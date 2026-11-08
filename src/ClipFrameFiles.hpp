#pragma once

// The DNG frames of a clip folder, flat or split. Core's [storage] frames_per_folder=N records a take as
// <clip>/part_NNN/<clip>_<frame>.dng (the names unchanged, numbering running on across parts; the WAV and the
// sidecars stay in the clip folder), and Core's merge worker moves them back into the clip folder while the camera
// is idle, so a clip may be flat, split, or partly merged (a flat prefix plus the remaining parts). These helpers
// list every frame as a path relative to the clip folder and order them by file name, so all three layouts give the
// same frames in the same order as a flat clip always did.

#include <QCollator>
#include <QDir>
#include <QFileInfo>
#include <QString>
#include <QStringList>

#include <algorithm>

namespace apertar::clipframes {

// "part_" + at least three digits (Core's FramePath.hpp partDirName).
inline bool isPartDirName(const QString &name)
{
    if (!name.startsWith(QStringLiteral("part_")) || name.size() < 8)
        return false;
    for (int i = 5; i < name.size(); ++i)
        if (!name.at(i).isDigit())
            return false;
    return true;
}

// The clip folder of a frame file: its own folder, or the folder above a part_NNN folder.
inline QDir clipDirForFrame(const QString &framePath)
{
    QDir dir = QFileInfo(framePath).dir();
    if (isPartDirName(dir.dirName()))
        dir.cdUp();
    return dir;
}

// The frames: the clip folder's files matching `filters`, then those of every part_NNN folder as "part_NNN/<name>",
// all ordered by file name (numeric collation, as the flat listings did). clipDir.absoluteFilePath() of an entry is
// the frame's path.
inline QStringList dngFramesOfClip(const QDir &clipDir, const QStringList &filters, QDir::Filters fileFilters = QDir::Files)
{
    QStringList frames = clipDir.entryList(filters, fileFilters, QDir::Name);
    const QStringList dirs = clipDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks, QDir::Name);
    for (const QString &part : dirs) {
        if (!isPartDirName(part))
            continue;
        const QDir partDir(clipDir.absoluteFilePath(part));
        for (const QString &name : partDir.entryList(filters, fileFilters, QDir::Name))
            frames.append(part + QLatin1Char('/') + name);
    }
    QCollator collator;
    collator.setNumericMode(true);
    const auto fileName = [](const QString &path) {
        const int slash = path.lastIndexOf(QLatin1Char('/'));
        return slash < 0 ? path : path.mid(slash + 1);
    };
    std::stable_sort(frames.begin(), frames.end(), [&](const QString &lhs, const QString &rhs) {
        return collator.compare(fileName(lhs), fileName(rhs)) < 0;
    });
    return frames;
}

} // namespace apertar::clipframes
