import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {createRoundedRectMask, maskCacheKey} from './mask.js';

const SHADOW_PADDING = 64;

function connect(object, signal, callback, connections) {
    connections.push([object, object.connect(signal, callback)]);
}

function findContentActor(actor, content) {
    if (actor.content === content)
        return actor;

    for (const child of actor.get_children()) {
        const result = findContentActor(child, content);
        if (result)
            return result;
    }

    return null;
}

function disconnectAll(connections) {
    for (const [object, id] of connections.splice(0)) {
        try {
            object.disconnect(id);
        } catch (error) {
            console.warn(`[gnome-window-appearance] disconnect failed: ${error}`);
        }
    }
}

export class WindowAppearanceEffect {
    #actor;
    #window;
    #texture;
    #settings;
    #connections = [];
    #bindings = [];
    #shadow = null;
    #maskTexture = null;
    #opaqueMaskTexture = null;
    #contentActor = null;
    #originalContentOpacity = null;
    #maskKey = '';
    #hadClip = false;
    #originalClip = null;

    constructor(actor, settings) {
        this.#actor = actor;
        this.#window = actor.get_meta_window();
        this.#texture = actor.get_texture();
        this.#settings = settings;
    }

    enable() {
        if (!this.#texture)
            return false;

        this.#hadClip = this.#actor.has_clip;
        if (this.#hadClip)
            this.#originalClip = this.#actor.get_clip();

        connect(this.#actor, 'notify::size', () => this.update(), this.#connections);
        connect(this.#texture, 'size-changed', () => this.update(), this.#connections);
        connect(this.#window, 'notify::fullscreen', () => this.update(), this.#connections);
        connect(this.#window, 'notify::maximized-horizontally', () => this.update(), this.#connections);
        connect(this.#window, 'notify::maximized-vertically', () => this.update(), this.#connections);
        connect(this.#window, 'notify::appears-focused', () => this.#updateShadowStyle(), this.#connections);

        this.#createShadow();
        this.update();
        return true;
    }

    update() {
        if (!this.#texture || this.#actor.is_destroyed())
            return;

        if (this.#shouldSuppressAppearance()) {
            this.#clearMaskAndClip();
            if (this.#shadow)
                this.#shadow.visible = false;
            return;
        }

        const frameRect = this.#window.get_frame_rect();
        const bufferRect = this.#window.get_buffer_rect();
        if (frameRect.width <= 0 || frameRect.height <= 0)
            return;

        const frameLocal = {
            x: frameRect.x - bufferRect.x,
            y: frameRect.y - bufferRect.y,
            width: frameRect.width,
            height: frameRect.height,
        };
        this.#actor.set_clip(
            frameLocal.x,
            frameLocal.y,
            frameLocal.width,
            frameLocal.height,
        );

        this.#updateMask(frameLocal);
        this.#updateShadowGeometry(frameRect, bufferRect);
        this.#updateShadowStyle();
        if (this.#shadow)
            this.#shadow.visible = this.#actor.visible;
    }

    restackShadow() {
        if (this.#shadow && this.#shadow.get_parent() === global.windowGroup)
            global.windowGroup.set_child_below_sibling(this.#shadow, this.#actor);
    }

    disable() {
        disconnectAll(this.#connections);
        this.#setOpaqueMask();
        this.#maskTexture = null;
        this.#maskKey = '';
        this.#restoreContentOpacity();

        if (this.#hadClip && this.#originalClip) {
            const [x, y, width, height] = this.#originalClip;
            this.#actor.set_clip(x, y, width, height);
        } else {
            this.#actor.remove_clip();
        }

        for (const binding of this.#bindings.splice(0))
            binding.unbind();

        if (this.#shadow) {
            this.#shadow.destroy();
            this.#shadow = null;
        }
    }

    #shouldSuppressAppearance() {
        return this.#settings.get_boolean('skip-maximized') &&
            (this.#window.fullscreen ||
             this.#window.maximized_horizontally ||
             this.#window.maximized_vertically);
    }

    #clearMaskAndClip() {
        this.#setOpaqueMask();
        this.#maskTexture = null;
        this.#maskKey = '';
        this.#restoreContentOpacity();
        this.#restoreClip();
    }

    #restoreClip() {
        if (this.#hadClip && this.#originalClip) {
            const [x, y, width, height] = this.#originalClip;
            this.#actor.set_clip(x, y, width, height);
        } else {
            this.#actor.remove_clip();
        }
    }

    #setOpaqueMask() {
        if (!this.#texture)
            return;

        // meta_shaped_texture_set_mask_texture() accepts NULL in C, but the
        // GNOME 50 GIR lacks the nullable annotation, so GJS rejects null.
        // A 1x1 opaque texture restores identical pixels without an offscreen
        // framebuffer; the only residual cost is one constant-alpha sample.
        this.#opaqueMaskTexture ??= Cogl.Texture2D.new_from_data(
            this.#getCoglContext(),
            1,
            1,
            Cogl.PixelFormat.A_8,
            1,
            new Uint8Array([255]),
        );
        this.#texture.set_mask_texture(this.#opaqueMaskTexture);
    }

    #getCoglContext() {
        return this.#actor.get_context().get_backend().get_cogl_context();
    }

    #updateMask(frameLocal) {
        const contentActor = findContentActor(this.#actor, this.#texture);
        const multiTexture = this.#texture.get_texture();
        if (!contentActor || !multiTexture ||
            contentActor.width <= 0 || contentActor.height <= 0) {
            return;
        }

        const textureWidth = multiTexture.get_width();
        const textureHeight = multiTexture.get_height();
        if (textureWidth <= 0 || textureHeight <= 0)
            return;

        this.#forceBlendedContent(contentActor);

        const scaleX = textureWidth / contentActor.width;
        const scaleY = textureHeight / contentActor.height;
        const maskRect = {
            x: (frameLocal.x - contentActor.x) * scaleX,
            y: (frameLocal.y - contentActor.y) * scaleY,
            width: frameLocal.width * scaleX,
            height: frameLocal.height * scaleY,
        };
        const logicalRadius = this.#settings.get_uint('corner-radius');
        const radius = logicalRadius * Math.min(scaleX, scaleY);
        const key = maskCacheKey(
            textureWidth,
            textureHeight,
            maskRect,
            radius,
        );
        if (key === this.#maskKey)
            return;

        const maskData = createRoundedRectMask(
            textureWidth,
            textureHeight,
            maskRect,
            radius,
        );
        const maskTexture = Cogl.Texture2D.new_from_data(
            this.#getCoglContext(),
            textureWidth,
            textureHeight,
            Cogl.PixelFormat.A_8,
            textureWidth,
            maskData,
        );

        this.#texture.set_mask_texture(maskTexture);
        this.#maskTexture = maskTexture;
        this.#maskKey = key;
        const frameRect = this.#window.get_frame_rect();
        console.log(
            `[gnome-window-appearance] mask ${this.#window.get_wm_class()} ` +
            `${textureWidth}x${textureHeight} radius=${radius.toFixed(2)} ` +
            `frame=${frameLocal.width}x${frameLocal.height} ` +
            `frame-position=${frameRect.x},${frameRect.y} ` +
            `surface-scale=${scaleX.toFixed(2)}x${scaleY.toFixed(2)} ` +
            `resource-scale=${this.#actor.get_resource_scale().toFixed(2)} ` +
            `content-opacity=${contentActor.opacity}`,
        );
    }

    #forceBlendedContent(contentActor) {
        if (this.#contentActor !== contentActor) {
            this.#restoreContentOpacity();
            this.#contentActor = contentActor;
            this.#originalContentOpacity = contentActor.opacity;
        }

        // MetaShapedTexture applies its mask only on the blended paint path.
        // A fully opaque client surface otherwise bypasses the mask through
        // Mutter's opaque-region optimization. Opacity 254 forces the direct
        // texture pipeline through the mask without allocating an offscreen
        // framebuffer. The visual tradeoff is at most one alpha level.
        if (contentActor.opacity === 255)
            contentActor.opacity = 254;
    }

    #restoreContentOpacity() {
        if (this.#contentActor && this.#originalContentOpacity !== null &&
            this.#contentActor.opacity === 254) {
            this.#contentActor.opacity = this.#originalContentOpacity;
        }
        this.#contentActor = null;
        this.#originalContentOpacity = null;
    }

    #createShadow() {
        const child = new St.Widget({
            x_expand: true,
            y_expand: true,
            style_class: 'gnome-window-appearance-shadow-surface',
        });
        this.#shadow = new St.Bin({
            name: 'gnome-window-appearance-shadow',
            child,
            reactive: false,
            style: `padding: ${SHADOW_PADDING}px;`,
        });

        global.windowGroup.insert_child_below(this.#shadow, this.#actor);
        for (let coordinate = 0; coordinate < 4; coordinate++) {
            this.#shadow.add_constraint(new Clutter.BindConstraint({
                source: this.#actor,
                coordinate,
                offset: 0,
            }));
        }

        for (const property of [
            'pivot-point',
            'translation-x',
            'translation-y',
            'scale-x',
            'scale-y',
            'visible',
        ]) {
            this.#bindings.push(this.#actor.bind_property(
                property,
                this.#shadow,
                property,
                GObject.BindingFlags.SYNC_CREATE,
            ));
        }
    }

    #updateShadowGeometry(frameRect, bufferRect) {
        if (!this.#shadow)
            return;

        const offsets = [
            frameRect.x - bufferRect.x - SHADOW_PADDING,
            frameRect.y - bufferRect.y - SHADOW_PADDING,
            frameRect.width - bufferRect.width + 2 * SHADOW_PADDING,
            frameRect.height - bufferRect.height + 2 * SHADOW_PADDING,
        ];
        this.#shadow.get_constraints().forEach((constraint, index) => {
            if (constraint instanceof Clutter.BindConstraint)
                constraint.offset = offsets[index];
        });
    }

    #updateShadowStyle() {
        if (!this.#shadow)
            return;

        const radius = this.#settings.get_uint('corner-radius');
        const blur = this.#settings.get_uint('shadow-blur');
        const spread = this.#settings.get_int('shadow-spread');
        const offsetY = this.#settings.get_int('shadow-offset-y');
        const configuredOpacity = this.#settings.get_uint('shadow-opacity') / 100;
        const opacity = this.#window.appears_focused
            ? configuredOpacity
            : configuredOpacity * 0.65;
        this.#shadow.child.style = `
            background-color: rgba(0, 0, 0, 0);
            border-radius: ${radius}px;
            box-shadow: 0 ${offsetY}px ${blur}px ${spread}px
                rgba(0, 0, 0, ${opacity.toFixed(3)});
        `;
    }
}
