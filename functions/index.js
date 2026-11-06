'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

const { SLOT_STATES_UNDONE, slipUpdateFor } = require('./slip');

admin.initializeApp();
const db = admin.firestore();

/**
 * Slip detection.
 *
 * Runs on a schedule because the client cannot be relied on to be awake —
 * iOS gives no usable background execution window for this, which is the
 * whole reason this lives server-side.
 *
 * Deliberately does NOT re-place work. Placement lives in one implementation
 * (the Dart solver) and duplicating it here in JavaScript would guarantee the
 * two drift apart. What the server does is the part the client genuinely
 * cannot: authoritatively mark elapsed slots as missed and bump slip counts,
 * even if the app is never opened. It then pushes a high-priority message
 * asking the client to re-plan, which happens on receipt or next foreground.
 */
exports.detectSlips = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'Etc/UTC',
    retryCount: 2,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const elapsed = await db
      .collectionGroup('slots')
      .where('end', '<', now)
      .where('state', 'in', SLOT_STATES_UNDONE)
      .get();

    if (elapsed.empty) {
      logger.info('No elapsed undone slots.');
      return;
    }

    const byUser = new Map();
    for (const doc of elapsed.docs) {
      // users/{uid}/slots/{slotId} — the user doc is two levels up.
      const uid = doc.ref.parent.parent.id;
      if (!byUser.has(uid)) byUser.set(uid, []);
      byUser.get(uid).push(doc);
    }

    for (const [uid, slots] of byUser) {
      try {
        await recordSlipsForUser(uid, slots);
        await requestReplan(uid, slots.length);
      } catch (error) {
        // One user's failure must not stop the sweep for everyone else.
        logger.error(`Slip handling failed for ${uid}`, error);
      }
    }

    logger.info(
      `Marked ${elapsed.size} missed slots across ${byUser.size} users.`
    );
  }
);

async function recordSlipsForUser(uid, slotDocs) {
  const batch = db.batch();
  const taskRefs = new Map();

  for (const slot of slotDocs) {
    batch.update(slot.ref, { state: 'missed' });

    const taskId = slot.get('taskId');
    if (taskId && !taskRefs.has(taskId)) {
      taskRefs.set(
        taskId,
        db.collection('users').doc(uid).collection('tasks').doc(taskId)
      );
    }
  }

  // Read the tasks before writing so slipCount increments from a real value
  // rather than being overwritten blind.
  const tasks = await db.getAll(...taskRefs.values());

  for (const task of tasks) {
    if (!task.exists) continue;
    // A task already completed or already stuck needs no further slip.
    const status = task.get('status');
    if (status === 'done' || status === 'slipped') continue;

    batch.update(task.ref, slipUpdateFor(task.get('slipCount')));
  }

  await batch.commit();
}

/**
 * Asks the client to re-plan. High priority on both platforms because the
 * plan is wrong until it runs, and Android's Doze will otherwise defer it.
 */
async function requestReplan(uid, missedCount) {
  const user = await db.collection('users').doc(uid).get();
  const token = user.get('fcmToken');

  if (!token) {
    logger.info(`No FCM token for ${uid}; skipping re-plan push.`);
    return;
  }

  await admin.messaging().send({
    token,
    data: {
      type: 'replan_required',
      missedCount: String(missedCount),
    },
    android: { priority: 'high' },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { contentAvailable: true } },
    },
  });
}
