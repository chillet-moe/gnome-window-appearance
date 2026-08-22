import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

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

function scheduleStateTransitions(window, artifactDir, getNativeClip) {
    const states = [
        ['maximized', () => window.maximize(), 'mutter-native-maximized.png'],
        ['restored', () => window.unmaximize(), 'mutter-native-restored.png'],
        ['fullscreen', () => window.make_fullscreen(), 'mutter-native-fullscreen.png'],
        ['restored-final', () => window.unmake_fullscreen(), 'mutter-native-restored-final.png'],
    ];

    const advance = index => {
        if (index >= states.length)
            return;

        const [name, transition, filename] = states[index];
        transition();
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 600, () => {
            const frame = window.get_frame_rect();
            console.log(
                `[gnome-window-appearance] state=${name} ` +
                `native-clip=${getNativeClip?.() ?? false} ` +
                `frame=${frame.width}x${frame.height}+${frame.x}+${frame.y}`,
            );
            captureScreenshot(artifactDir, filename, () => advance(index + 1));
            return GLib.SOURCE_REMOVE;
        });
    };

    advance(0);
}

export function scheduleTestCapture(window, getNativeClip = null) {
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
                scheduleStateTransitions(window, artifactDir, getNativeClip);
        });
        return GLib.SOURCE_REMOVE;
    });
}
