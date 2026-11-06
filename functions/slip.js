'use strict';

/**
 * Pure slip-detection logic, kept free of Firestore and the clock so it can
 * be tested directly.
 *
 * Mirrors TaskModel.stuckSlipThreshold in the Dart client. If you change one,
 * change the other — the two are a contract, not a coincidence.
 */

const STUCK_SLIP_THRESHOLD = 3;

const SLOT_STATES_UNDONE = ['planned', 'notified', 'started'];

/**
 * Given a task's current slip count, returns the fields to write after one of
 * its slots was missed.
 *
 * A single miss returns the task to the pool so the next plan picks it up.
 * Crossing the threshold moves it to `slipped`, where the planner stops
 * placing it and waits for the user to decide — the anti-graveyard rule.
 */
function slipUpdateFor(currentSlipCount) {
  const slipCount = (currentSlipCount || 0) + 1;
  return {
    slipCount,
    status: slipCount >= STUCK_SLIP_THRESHOLD ? 'slipped' : 'inbox',
  };
}

module.exports = {
  STUCK_SLIP_THRESHOLD,
  SLOT_STATES_UNDONE,
  slipUpdateFor,
};
