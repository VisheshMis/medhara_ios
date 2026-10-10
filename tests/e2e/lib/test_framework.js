/**
 * Medha E2E Test Framework
 * Lightweight, robust test harness for opaque-box requirement verification.
 */

class TestSuite {
  constructor(name) {
    this.name = name;
    this.tests = [];
    this.passed = 0;
    this.failed = 0;
    this.errors = [];
  }

  test(description, fn) {
    this.tests.push({ description, fn });
  }

  async run() {
    console.log(`\n\x1b[36m▶ Running Suite: ${this.name}\x1b[0m`);
    const startTime = Date.now();
    for (const t of this.tests) {
      const testStart = Date.now();
      try {
        await t.fn();
        const duration = Date.now() - testStart;
        this.passed++;
        console.log(`  \x1b[32m✔\x1b[0m ${t.description} \x1b[90m(${duration}ms)\x1b[0m`);
      } catch (err) {
        const duration = Date.now() - testStart;
        this.failed++;
        this.errors.push({ description: t.description, error: err });
        console.log(`  \x1b[31m✖\x1b[0m ${t.description} \x1b[90m(${duration}ms)\x1b[0m`);
        console.log(`    \x1b[31mError: ${err.message}\x1b[0m`);
        if (err.stack) {
          const stackLine = err.stack.split('\n')[1];
          if (stackLine) console.log(`    \x1b[90m${stackLine.trim()}\x1b[0m`);
        }
      }
    }
    const totalTime = Date.now() - startTime;
    console.log(
      `  \x1b[1mSummary:\x1b[0m ${this.passed} passed, ${this.failed} failed (${totalTime}ms)`
    );
    return {
      name: this.name,
      total: this.tests.length,
      passed: this.passed,
      failed: this.failed,
      errors: this.errors,
      duration: totalTime,
    };
  }
}

const Assert = {
  ok(condition, message) {
    if (!condition) {
      throw new Error(message || 'Assertion failed: expected truthy condition');
    }
  },

  equal(actual, expected, message) {
    if (actual !== expected) {
      throw new Error(
        message || `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
      );
    }
  },

  notEqual(actual, expected, message) {
    if (actual === expected) {
      throw new Error(
        message || `Expected values not to equal ${JSON.stringify(actual)}`
      );
    }
  },

  deepEqual(actual, expected, message) {
    const act = JSON.stringify(actual);
    const exp = JSON.stringify(expected);
    if (act !== exp) {
      throw new Error(
        message || `Deep equal failure:\n  Expected: ${exp}\n  Actual:   ${act}`
      );
    }
  },

  closeTo(actual, expected, delta = 0.01, message) {
    const diff = Math.abs(actual - expected);
    if (diff > delta) {
      throw new Error(
        message || `Expected ${actual} to be close to ${expected} (within ±${delta}, diff=${diff.toFixed(4)})`
      );
    }
  },

  throws(fn, expectedMsgPattern, message) {
    let threw = false;
    let thrownError = null;
    try {
      fn();
    } catch (e) {
      threw = true;
      thrownError = e;
    }
    if (!threw) {
      throw new Error(message || 'Expected function to throw an error, but it succeeded');
    }
    if (expectedMsgPattern && !thrownError.message.includes(expectedMsgPattern)) {
      throw new Error(
        `Expected error message to contain "${expectedMsgPattern}", got "${thrownError.message}"`
      );
    }
  },

  doesNotThrow(fn, message) {
    try {
      fn();
    } catch (e) {
      throw new Error(message || `Expected function not to throw, but got: ${e.message}`);
    }
  },
};

module.exports = {
  TestSuite,
  Assert,
};
