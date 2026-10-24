import type {
  JudgeExperienceAdapters,
  JudgeExperienceRunRequest,
  RetrievalRequest,
} from './adapters.ts';
import { assembleSlots, reconcileAll } from './engine.ts';
import { CATEGORIES } from './policy.ts';
import { executeFixtureRun } from './state-machine.ts';
import type {
  ExplanationPayload,
  FixtureExecutionResult,
  FixtureRun,
  ResolvedProfile,
  RetrievalResult,
  Side,
} from './types.ts';

const EMPTY_EXPLANATION: ExplanationPayload = { slots: [] };

function buildFixture(
  request: JudgeExperienceRunRequest,
  resolvedProfiles: readonly ResolvedProfile[],
  retrievals: readonly RetrievalResult[],
  explanationPayload: ExplanationPayload,
): FixtureRun {
  return {
    contract_version: 'JUDGE_EXPERIENCE_V1',
    selector_policy_id: 'LEXIMIN_RANK_V1',
    slot_contract_id: 'CROSS_CATEGORY_SLOT_CONTRACT_V1',
    run_id: request.run_id,
    destination_city: request.destination_city,
    resolved_profiles: resolvedProfiles,
    retrievals,
    explanation_payload: explanationPayload,
  };
}

function profileRefFor(
  request: JudgeExperienceRunRequest,
  side: Side,
): string {
  return side === 'A'
    ? request.person_a.profile_ref
    : request.person_b.profile_ref;
}

function unavailableRetrieval(
  request: RetrievalRequest,
): RetrievalResult {
  return {
    side: request.side,
    category: request.category,
    destination_city: request.destination_city,
    status: 'EVIDENCE_UNAVAILABLE',
    entities: [],
  };
}

function retrievalMatchesRequest(
  result: RetrievalResult,
  request: RetrievalRequest,
): boolean {
  return (
    result.side === request.side &&
    result.category === request.category &&
    result.destination_city === request.destination_city
  );
}

export async function executeWithAdapters(
  request: JudgeExperienceRunRequest,
  adapters: JudgeExperienceAdapters,
): Promise<FixtureExecutionResult> {
  const profiles: ResolvedProfile[] = [];

  for (const side of ['A', 'B'] as const) {
    const profileRef = profileRefFor(request, side);
    try {
      const profile = await adapters.profileResolver.resolveProfile({
        side,
        profile_ref: profileRef,
      });

      if (
        profile.side !== side ||
        profile.profile_ref !== profileRef ||
        profile.qloo_seed_entity_ids.length === 0
      ) {
        throw new Error('Profile adapter returned evidence for the wrong request.');
      }

      profiles.push(profile);
    } catch {
      return executeFixtureRun(
        buildFixture(request, [], [], EMPTY_EXPLANATION),
      );
    }
  }

  const retrievals: RetrievalResult[] = [];
  for (const side of ['A', 'B'] as const) {
    const profile = profiles.find((item) => item.side === side);
    if (!profile) {
      return executeFixtureRun(
        buildFixture(request, [], [], EMPTY_EXPLANATION),
      );
    }

    for (const category of CATEGORIES) {
      const retrievalRequest: RetrievalRequest = {
        side,
        category,
        destination_city: request.destination_city,
        profile,
      };

      try {
        const result = await adapters.retrievalSource.retrieve(retrievalRequest);
        retrievals.push(
          retrievalMatchesRequest(result, retrievalRequest)
            ? result
            : unavailableRetrieval(retrievalRequest),
        );
      } catch {
        retrievals.push(unavailableRetrieval(retrievalRequest));
      }
    }
  }

  let slots;
  try {
    const reconciliation = reconcileAll(retrievals);
    slots = assembleSlots(reconciliation);
  } catch {
    return executeFixtureRun(
      buildFixture(request, profiles, retrievals, EMPTY_EXPLANATION),
    );
  }

  if (slots.some((slot) => slot.status === 'EVIDENCE_UNAVAILABLE')) {
    return executeFixtureRun(
      buildFixture(request, profiles, retrievals, EMPTY_EXPLANATION),
    );
  }

  let explanationPayload: ExplanationPayload;
  try {
    explanationPayload = await adapters.explanationSource.explain({
      run_id: request.run_id,
      destination_city: request.destination_city,
      slots,
    });
  } catch {
    explanationPayload = EMPTY_EXPLANATION;
  }

  return executeFixtureRun(
    buildFixture(request, profiles, retrievals, explanationPayload),
  );
}
