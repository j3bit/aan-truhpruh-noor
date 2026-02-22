import test from 'node:test';
import assert from 'node:assert/strict';

import { greeting } from '../index.js';

test('greeting returns expected text', () => {
  assert.equal(greeting('template'), 'Hello, template!');
});
