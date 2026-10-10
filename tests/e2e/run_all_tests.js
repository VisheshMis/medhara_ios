#!/usr/bin/env node

/**
 * Medha Companion Application: Master E2E Test Suite Runner
 * Executes all 4 Tiers of requirement-driven opaque-box verification:
 *   - Tier 1: Feature Coverage (9 suites)
 *   - Tier 2: Boundary & Corner Cases (4 suites)
 *   - Tier 3: Cross-Feature Combinations (5 suites)
 *   - Tier 4: Real-World Application Scenarios (5 suites)
 */

const path = require('path');

// Tier 1 Suites
const tier1Suites = [
  require('./tier1_feature_coverage/01_schema_parity.test'),
  require('./tier1_feature_coverage/02_triggers_journal.test'),
  require('./tier1_feature_coverage/03_fsrs_math.test'),
  require('./tier1_feature_coverage/04_delta_sync_protocol.test'),
  require('./tier1_feature_coverage/05_lww_conflict_resolution.test'),
  require('./tier1_feature_coverage/06_hierarchical_reader.test'),
  require('./tier1_feature_coverage/07_fts5_search.test'),
  require('./tier1_feature_coverage/08_study_review_flow.test'),
  require('./tier1_feature_coverage/09_quick_capture.test'),
];

// Tier 2 Suites
const tier2Suites = [
  require('./tier2_boundary_cases/01_boundary_notes_text.test'),
  require('./tier2_boundary_cases/02_boundary_fsrs_math.test'),
  require('./tier2_boundary_cases/03_boundary_sync_conflicts.test'),
  require('./tier2_boundary_cases/04_boundary_limits_queues.test'),
];

// Tier 3 Suites
const tier3Suites = [
  require('./tier3_cross_feature/01_review_to_sync_push.test'),
  require('./tier3_cross_feature/02_quick_capture_to_fts_search.test'),
  require('./tier3_cross_feature/03_multi_device_offline_lww.test'),
  require('./tier3_cross_feature/04_capture_to_study_queue.test'),
  require('./tier3_cross_feature/05_reader_fold_and_search.test'),
];

// Tier 4 Suites
const tier4Suites = [
  require('./tier4_student_scenarios/01_student_review_session.test'),
  require('./tier4_student_scenarios/02_quick_capture_to_study.test'),
  require('./tier4_student_scenarios/03_offline_note_multi_device_sync.test'),
  require('./tier4_student_scenarios/04_knowledge_base_search_reader.test'),
  require('./tier4_student_scenarios/05_cross_platform_review_sync.test'),
];

async function runMasterSuite() {
  console.log('======================================================================');
  console.log('🧪 MEDHA COMPANION E2E TEST RUNNER — 4-TIER REQUIREMENT VERIFICATION');
  console.log('======================================================================');
  console.log(`Execution Start: ${new Date().toISOString()}`);

  const startTime = Date.now();
  let totalTests = 0;
  let totalPassed = 0;
  let totalFailed = 0;
  const tierStats = [];

  const tierGroups = [
    { name: 'Tier 1: Feature Coverage (R1, R2, R3)', suites: tier1Suites },
    { name: 'Tier 2: Boundary & Corner Cases', suites: tier2Suites },
    { name: 'Tier 3: Cross-Feature Combinations', suites: tier3Suites },
    { name: 'Tier 4: Real-World Student Scenarios', suites: tier4Suites },
  ];

  for (const group of tierGroups) {
    console.log(`\n\x1b[1m\x1b[35m=== ${group.name} ===\x1b[0m`);
    let groupPassed = 0;
    let groupFailed = 0;
    let groupTotal = 0;

    for (const suite of group.suites) {
      const res = await suite.run();
      groupTotal += res.total;
      groupPassed += res.passed;
      groupFailed += res.failed;
    }

    totalTests += groupTotal;
    totalPassed += groupPassed;
    totalFailed += groupFailed;

    tierStats.push({
      name: group.name,
      total: groupTotal,
      passed: groupPassed,
      failed: groupFailed,
    });
  }

  const duration = Date.now() - startTime;

  console.log('\n======================================================================');
  console.log('📊 FINAL STRUCTURED TEST EXECUTION RESULTS');
  console.log('======================================================================');
  for (const s of tierStats) {
    const statusMark = s.failed === 0 ? '\x1b[32m✔ PASS\x1b[0m' : '\x1b[31m✖ FAIL\x1b[0m';
    console.log(`  ${statusMark} ${s.name.padEnd(46)}: ${s.passed}/${s.total} passed`);
  }
  console.log('----------------------------------------------------------------------');
  console.log(`  \x1b[1mTOTAL SUITES\x1b[0m  : ${tier1Suites.length + tier2Suites.length + tier3Suites.length + tier4Suites.length}`);
  console.log(`  \x1b[1mTOTAL TESTS\x1b[0m   : ${totalTests}`);
  console.log(`  \x1b[32m✔ PASSED\x1b[0m      : ${totalPassed}`);
  console.log(`  ${totalFailed === 0 ? '\x1b[32m✔' : '\x1b[31m✖'} FAILED\x1b[0m      : ${totalFailed}`);
  console.log(`  \x1b[1mEXECUTION TIME\x1b[0m: ${duration}ms (${(duration / 1000).toFixed(2)}s)`);
  console.log('======================================================================');

  if (totalFailed > 0) {
    console.log('\x1b[31m💥 TEST SUITE FAILED — DEFECTS DETECTED\x1b[0m');
    process.exit(1);
  } else {
    console.log('\x1b[32m🎉 100% E2E REQUIREMENTS VERIFIED CLEANLY (ZERO DEFECTS)\x1b[0m');
    process.exit(0);
  }
}

if (require.main === module) {
  runMasterSuite().catch(err => {
    console.error('Fatal runner error:', err);
    process.exit(1);
  });
}

module.exports = { runMasterSuite };
