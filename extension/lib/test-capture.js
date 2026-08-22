import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

let captureScheduled = false;

function captureScreenshot(artifactDir, filename, onComplete = null) {
    const path = GLib.build_filenamev([artifactDir, filename]);
    const file = Gio.File.new_for_path(path);
    let stream;
    try {
        stream = file.replace(
            null,
            false,
            Gio.FileCreateFlags.REPLACE_DESTINATION,
            null,
        );
    } catch (error) {
        console.error(`[gnome-window-appearance] test capture open failed: ${error}`);
        onComplete?.(false);
        return;
    }

    const screenshot = new Shell.Screenshot();
    screenshot.screenshot(false, stream, (_source, result) => {
        try {
            const [success] = screenshot.screenshot_finish(result);
            stream.close(null);
            if (!success)
                throw new Error('Shell.Screenshot returned false');
            console.log(`[gnome-window-appearance] test capture ${path}`);
            onComplete?.(true);
        } catch (error) {
            console.error(`[gnome-window-appearance] test capture failed: ${error}`);
            onComplete?.(false);
        }
    });
}

function scheduleStateTransitions(window, artifactDir, getNativeClip,
                                  getHasMappedClones) {
    const states = [
        ['maximized', () => window.maximize(), 'mutter-native-maximized.png', 600],
        ['restored', () => window.unmaximize(), 'mutter-native-restored.png', 600],
        ['fullscreen', () => window.make_fullscreen(), 'mutter-native-fullscreen.png', 600],
        ['restored-final', () => window.unmake_fullscreen(), 'mutter-native-restored-final.png', 600],
        ['overview', () => Main.overview.show(), 'mutter-native-overview.png', 900],
        ['overview-restored', () => Main.overview.hide(), 'mutter-native-overview-restored.png', 900],
    ];

    const advance = index => {
        if (index >= states.length)
            return;

        const [name, transition, filename, delay] = states[index];
        transition();
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, () => {
            const frame = window.get_frame_rect();
            console.log(
                `[gnome-window-appearance] state=${name} ` +
                `native-clip=${getNativeClip?.() ?? false} ` +
                `mapped-clones=${getHasMappedClones?.() ?? false} ` +
                `frame=${frame.width}x${frame.height}+${frame.x}+${frame.y}`,
            );
            captureScreenshot(artifactDir, filename, () => advance(index + 1));
            return GLib.SOURCE_REMOVE;
        });
    };

    advance(0);
}

export function scheduleTestCapture(window, getNativeClip = null,
                                    getHasMappedClones = null) {
    const artifactDir = GLib.getenv('TEST_ARTIFACT_DIR');
    const testWmClass = GLib.getenv('GWA_TEST_WM_CLASS') ?? 'window-probe';
    if (!artifactDir || captureScheduled ||
        window.get_wm_class() !== testWmClass) {
        return;
    }

    captureScheduled = true;
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 750, () => {
        captureScreenshot(artifactDir, 'fractional-2.5.png', success => {
            if (success && GLib.getenv('GWA_TEST_STATE_TRANSITIONS') === '1')
                scheduleStateTransitions(window, artifactDir, getNativeClip,
                                         getHasMappedClones);
        });
        return GLib.SOURCE_REMOVE;
    });
}
