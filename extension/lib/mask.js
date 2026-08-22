function clamp(value, lower, upper) {
    return Math.min(Math.max(value, lower), upper);
}
function fillSpan(data, stride, y, x1, x2, value = 255) {
    const start = y * stride + clamp(Math.ceil(x1), 0, stride);
    const end = y * stride + clamp(Math.floor(x2), 0, stride);
    if (end > start)
        data.fill(value, start, end);
}

/**
 * Build an A8 rounded-rectangle mask.
 *
 * Coordinates and radius are expressed in mask pixels. The one-pixel smooth
 * transition is intentional: when the mask matches the client texture size,
 * Mutter samples both with the same transform and filtering.
 */
export function createRoundedRectMask(width, height, rect, radius) {
    if (!Number.isInteger(width) || !Number.isInteger(height) ||
        width <= 0 || height <= 0) {
        throw new RangeError('Mask dimensions must be positive integers');
    }

    const x1 = clamp(rect.x, 0, width);
    const y1 = clamp(rect.y, 0, height);
    const x2 = clamp(rect.x + rect.width, x1, width);
    const y2 = clamp(rect.y + rect.height, y1, height);
    const effectiveRadius = clamp(radius, 0, Math.min(x2 - x1, y2 - y1) / 2);
    const data = new Uint8Array(width * height);

    if (x2 <= x1 || y2 <= y1)
        return data;

    if (effectiveRadius < 0.5) {
        for (let y = Math.floor(y1); y < Math.ceil(y2); y++)
            fillSpan(data, width, y, x1, x2);
        return data;
    }

    const topBandEnd = y1 + effectiveRadius;
    const bottomBandStart = y2 - effectiveRadius;
    for (let y = Math.floor(y1); y < Math.ceil(y2); y++) {
        if (y + 0.5 >= topBandEnd && y + 0.5 < bottomBandStart)
            fillSpan(data, width, y, x1, x2);
        else
            fillSpan(data, width, y, x1 + effectiveRadius, x2 - effectiveRadius);
    }

    const centers = [
        [x1 + effectiveRadius, y1 + effectiveRadius, -1, -1],
        [x2 - effectiveRadius, y1 + effectiveRadius, 1, -1],
        [x1 + effectiveRadius, y2 - effectiveRadius, -1, 1],
        [x2 - effectiveRadius, y2 - effectiveRadius, 1, 1],
    ];

    for (const [cx, cy, xDirection, yDirection] of centers) {
        const cornerX1 = xDirection < 0 ? x1 : cx;
        const cornerX2 = xDirection < 0 ? cx : x2;
        const cornerY1 = yDirection < 0 ? y1 : cy;
        const cornerY2 = yDirection < 0 ? cy : y2;

        for (let y = Math.floor(cornerY1); y < Math.ceil(cornerY2); y++) {
            if (y < 0 || y >= height)
                continue;

            for (let x = Math.floor(cornerX1); x < Math.ceil(cornerX2); x++) {
                if (x < 0 || x >= width)
                    continue;

                const distance = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) -
                    effectiveRadius;
                const alpha = Math.round(clamp(0.5 - distance, 0, 1) * 255);
                data[y * width + x] = alpha;
            }
        }
    }

    return data;
}

export function maskCacheKey(width, height, rect, radius) {
    return [
        width,
        height,
        rect.x.toFixed(3),
        rect.y.toFixed(3),
        rect.width.toFixed(3),
        rect.height.toFixed(3),
        radius.toFixed(3),
    ].join(':');
}
