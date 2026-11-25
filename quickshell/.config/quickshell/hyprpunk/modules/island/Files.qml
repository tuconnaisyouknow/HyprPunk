pragma Singleton

import QtQuick
import Quickshell

// Paths and files the way the file picker shows them: your home as ~, sizes in KB or
// MB, an icon for each kind of file.
Singleton {
    readonly property string home: Quickshell.env("HOME")

    // ~ back to your home, for a path you typed.
    function expand(path) {
        return path === "~" || path.startsWith("~/") ? home + path.substring(1) : path;
    }

    function collapse(path) {
        return path === home || path.startsWith(home + "/") ? "~" + path.substring(home.length) : path;
    }

    function join(directory, name) {
        return directory === "/" ? "/" + name : directory + "/" + name;
    }

    function parent(path) {
        return path.substring(0, path.lastIndexOf("/")) || "/";
    }

    function name(path) {
        return path === "/" ? "/" : path.substring(path.lastIndexOf("/") + 1);
    }

    // path is in folder, however deep.
    function inside(folder, path) {
        return path.startsWith(folder === "/" ? "/" : folder + "/");
    }

    // Each part escaped, so a name with # or ? still points at its file.
    function url(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // An app's file type, as a pattern like "*.png".
    function globRegex(glob) {
        return new RegExp("^" + glob.replace(/[.+^${}()|\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$", "i");
    }

    function size(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit += 1;
        }
        return (unit === 0 ? value : value.toFixed(value < 10 ? 1 : 0)) + " " + units[unit];
    }

    function isImage(name) {
        return /\.(png|jpe?g|gif|webp|bmp|svg|avif|tiff?)$/i.test(name);
    }

    // entry: {name, isDir}.
    function icon(entry) {
        if (entry.isDir)
            return "folder";

        const name = entry.name.toLowerCase();
        if (isImage(name))
            return "image";

        if (/\.(mp4|mkv|webm|mov|avi)$/.test(name))
            return "video_file";

        if (/\.(mp3|flac|ogg|opus|wav|m4a)$/.test(name))
            return "audio_file";

        if (/\.pdf$/.test(name))
            return "picture_as_pdf";

        if (/\.(zip|tar|gz|xz|zst|bz2|7z|rar)$/.test(name))
            return "folder_zip";

        if (/\.(txt|md|odt|docx?|rtf)$/.test(name))
            return "description";

        return "draft";
    }

}
