import { assembleSlots, reconcileAll } from './engine.ts';
import { CATEGORIES } from './policy.ts';
import { validateExplanation } from './validator.ts';
import type {
  FixtureExecutionResult,
  FixtureRun,
  ProgressItem,
  RunState,
} from './types.ts';

const PROGRESS_LABELS: readonly ProgressItem[] = [
  { state: 'RESOLVING_PROFILES', label: 'Understanding both taste profiles', completed: false },
  { state: 'RETRIEVING_QLOO', label: 'Searching the city through Qloo', completed: false },
  { state: 'RECONCILING', label: 'Finding shared Qloo matches', completed: false },
  { state: 'ASSEMBLING_SLOTS', label: 'Building Culture, Outdoor, and City Life picks', completed: false },
  { state: 'EXPLAINING', label: 'Explaining why the selected places work for both', completed: false },
  { state: 'VALIDATING', label: 'Verifying the final recommendations', completed: false },
];

function progressFor(completedStates: readonly RunState[]): readonly ProgressItem[] {
  const completed = new Set(completedStates);
  return PROGRESS_LABELS.map((item) => ({
    ...item,
    completed: completed.has(item.state),
  }));
}

function retrievalSetComplete(fixture: FixtureRun): boolean {
  for (const side of ['A', 'B'] as const) {
    for (const category of CATEGORIES) {
      const matches = fixture.retrievals.filter(
        (item) => item.side === side && item.category === category,
      );
      if (matches.length !== 1) return false;
    }
  }
  return true;
}

function failed(
  fixture: FixtureRun,
  history: RunState[],
  completedStates: RunState[],
  errorCode: FixtureExecutionResult['error_code'],
  reconciliation: FixtureExecutionResult['reconciliation'] = [],
  slots: FixtureExecutionResult['slots'] = [],
  validation: FixtureExecutionResult['validation'] = null,
): FixtureExecutionResult {
  history.push('FAILED');
  return {
    run_id: fixture.run_id,
    state: 'FAILED',
    state_history: history,
    completed_states: completedStates,
    progress: progressFor(completedStates),
    reconciliation,
    slots,
    validation,
    error_code: errorCode,
  };
}

export function executeFixtureRun(fixture: FixtureRun): FixtureExecutionResult {
  const history: RunState[] = ['IDLE', 'INPUT_READY'];
  const completedStates: RunState[] = [];

  history.push('RESOLVING_PROFILES');
  if (
    fixture.resolved_profiles.length !== 2 ||
    fixture.resolved_profiles.some(
      (profile) => profile.qloo_seed_entity_ids.length === 0,
    )
  ) {
    return failed(fixture, history, completedStates, 'PROFILE_RESOLUTION_FAILED');
  }
  completedStates.push('RESOLVING_PROFILES');

  history.push('RETRIEVING_QLOO');
  if (!retrievalSetComplete(fixture)) {
    return failed(fixture, history, completedStates, 'QLOO_RETRIEVAL_FAILED');
  }
  completedStates.push('RETRIEVING_QLOO');

  history.push('RECONCILING');
  let reconciliation: FixtureExecutionResult['reconciliation'];
  try {
    reconciliation = reconcileAll(fixture.retrievals);
  } catch {
    return failed(fixture, history, completedStates, 'INTERNAL_CONTRACT_VIOLATION');
  }
  completedStates.push('RECONCILING');

  history.push('ASSEMBLING_SLOTS');
  const slots = assembleSlots(reconciliation);
  completedStates.push('ASSEMBLING_SLOTS');

  if (slots.some((slot) => slot.status === 'EVIDENCE_UNAVAILABLE')) {
    return failed(
      fixture,
      history,
      completedStates,
      'QLOO_RETRIEVAL_FAILED',
      reconciliation,
      slots,
    );
  }

  history.push('EXPLAINING');
  completedStates.push('EXPLAINING');

  history.push('VALIDATING');
  const validation = validateExplanation(slots, fixture.explanation_payload);
  if (validation.status === 'FAIL') {
    return failed(
      fixture,
      history,
      completedStates,
      'EXPLANATION_VALIDATION_FAILED',
      reconciliation,
      slots,
      validation,
    );
  }
  completedStates.push('VALIDATING');

  const terminalState = slots.every((slot) => slot.status === 'SHARED_PRIMARY')
    ? 'READY'
    : 'PARTIAL_READY';
  history.push(terminalState);

  return {
    run_id: fixture.run_id,
    state: terminalState,
    state_history: history,
    completed_states: completedStates,
    progress: progressFor(completedStates),
    reconciliation,
    slots,
    validation,
    error_code: null,
  };
}
