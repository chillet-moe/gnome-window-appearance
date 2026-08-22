import assert from 'node:assert/strict';
import test from 'node:test';

import {createRoundedRectMask, maskCacheKey} from '../../extension/lib/mask.js';

function alphaAt(mask, width, x, y) {
    return mask[y * width + x];
}

test('rejects invalid dimensions', () => {
    assert.throws(
        () => createRoundedRectMask(0, 10, {x: 0, y: 0, width: 1, height: 1}, 1),
        RangeError,
    );
});
test('fills a square mask without rounded corners', () => {
    const mask = createRoundedRectMask(
        6,
        5,
        {x: 1, y: 1, width: 4, height: 3},
        0,
    );

    assert.equal(alphaAt(mask, 6, 0, 0), 0);
    assert.equal(alphaAt(mask, 6, 1, 1), 255);
    assert.equal(alphaAt(mask, 6, 4, 3), 255);
    assert.equal(alphaAt(mask, 6, 5, 4), 0);
});

test('rounds all four corners while preserving the center', () => {
    const mask = createRoundedRectMask(
        12,
        12,
        {x: 0, y: 0, width: 12, height: 12},
        4,
    );

    assert.equal(alphaAt(mask, 12, 0, 0), 0);
    assert.equal(alphaAt(mask, 12, 11, 0), 0);
    assert.equal(alphaAt(mask, 12, 0, 11), 0);
    assert.equal(alphaAt(mask, 12, 11, 11), 0);
    assert.equal(alphaAt(mask, 12, 6, 6), 255);
    assert.ok(alphaAt(mask, 12, 2, 1) > 0);
});

test('clamps radius and rectangle to the mask bounds', () => {
    const mask = createRoundedRectMask(
        8,
        6,
        {x: -2, y: -1, width: 12, height: 8},
        100,
    );

    assert.equal(mask.length, 48);
    assert.equal(alphaAt(mask, 8, 4, 3), 255);
});

test('cache key includes geometry and radius', () => {
    const rect = {x: 0, y: 0, width: 100, height: 80};
    assert.notEqual(
        maskCacheKey(100, 80, rect, 12),
        maskCacheKey(100, 80, rect, 13),
    );
});
