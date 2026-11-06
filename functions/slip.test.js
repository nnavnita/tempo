'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { slipUpdateFor, STUCK_SLIP_THRESHOLD } = require('./slip');

test('a first miss returns the task to the pool', () => {
  assert.deepStrictEqual(slipUpdateFor(0), { slipCount: 1, status: 'inbox' });
});

test('treats a missing slip count as zero', () => {
  assert.deepStrictEqual(slipUpdateFor(undefined), {
    slipCount: 1,
    status: 'inbox',
  });
});

test('stays in the pool below the stuck threshold', () => {
  const update = slipUpdateFor(STUCK_SLIP_THRESHOLD - 2);
  assert.strictEqual(update.status, 'inbox');
});

test('becomes stuck on reaching the threshold', () => {
  const update = slipUpdateFor(STUCK_SLIP_THRESHOLD - 1);
  assert.strictEqual(update.slipCount, STUCK_SLIP_THRESHOLD);
  assert.strictEqual(update.status, 'slipped');
});

test('stays stuck past the threshold', () => {
  assert.strictEqual(slipUpdateFor(STUCK_SLIP_THRESHOLD + 5).status, 'slipped');
});

test('threshold matches the Dart client contract', () => {
  assert.strictEqual(STUCK_SLIP_THRESHOLD, 3);
});
