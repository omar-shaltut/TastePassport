import type { JudgeExperienceRunRequest } from '../judge-experience/adapters.ts';
import type { AdapterExecutionEnvelope } from '../judge-experience/adapter-runner.ts';
import type { Category, SlotId, SlotStatus } from '../judge-experience/types.ts';

export interface FrontendPerson {
  readonly side: 'A' | 'B';
  readonly label: string;
  readonly profile_ref: string;
}

export interface FrontendProgressItem {
  readonly key: string;
  readonly label: string;
  readonly completed: boolean;
}

export interface FrontendRecommendationCard {
  readonly slot_id: SlotId;
  readonly slot_label: string;
  readonly status: SlotStatus;
  readonly category: Category | null;
  readonly category_label: string | null;
  readonly entity_id: string | null;
  readonly name: string | null;
  readonly display_type: string | null;
  readonly rank_a: number | null;
  readonly rank_b: number | null;
  readonly why_it_works: string | null;
  readonly empty_message: string | null;
}

export interface JudgeExperienceFrontendPayload {
  readonly schema_version: 'JUDGE_FRONTEND_V1';
  readonly run_id: string;
  readonly destination_city: string;
  readonly state: 'READY' | 'PARTIAL_READY' | 'FAILED';
  readonly state_label: string;
  readonly people: readonly FrontendPerson[];
  readonly summary: string | null;
  readonly progress: readonly FrontendProgressItem[];
  readonly cards: readonly FrontendRecommendationCard[];
  readonly evidence_note: string;
}

const SLOT_LABELS: Readonly<Record<SlotId, string>> = {
  CULTURE: 'Culture Pick',
  OUTDOORS: 'Outdoor Pick',
  CITY_LIFE: 'City Life Pick',
};

const CATEGORY_LABELS: Readonly<Record<Category, string>> = {
  art_gallery: 'Art Gallery',
  book_store: 'Book Store',
  museum: 'Museum',
  park: 'Park',
  restaurant: 'Restaurant',
  shopping_mall: 'Shopping Mall',
};

const EVIDENCE_NOTE =
  'Qloo surfaces the venue evidence. TastePassport reconciles it deterministically. AI only explains the selected places.';

function stateLabel(state: JudgeExperienceFrontendPayload['state']): string {
  if (state === 'READY') return '3 shared picks found';
  if (state === 'PARTIAL_READY') return 'Shared picks found with an honest shortfall';
  return 'Run could not be safely presented';
}

function emptyMessage(status: SlotStatus, slotId: SlotId): string | null {
  if (status === 'SHARED_PRIMARY') return null;
  if (status === 'EVIDENCE_UNAVAILABLE') {
    return `Evidence was unavailable for the ${SLOT_LABELS[slotId]} slot.`;
  }
  return `No shared Qloo evidence was found for the ${SLOT_LABELS[slotId]} slot.`;
}

export function buildFrontendPayload(
  request: JudgeExperienceRunRequest,
  envelope: AdapterExecutionEnvelope,
): JudgeExperienceFrontendPayload {
  const { execution, explanation_payload: explanationPayload } = envelope;
  const explanationIsSafe =
    execution.state !== 'FAILED' && execution.validation?.status === 'PASS';

  const explanationBySlot = new Map(
    explanationIsSafe
      ? (explanationPayload?.slots ?? []).map((slot) => [slot.slot_id, slot] as const)
      : [],
  );

  const cards = execution.slots.map((slot): FrontendRecommendationCard => {
    const selected = slot.selected;
    const explanation = explanationBySlot.get(slot.slot_id);
    const explanationMatches = Boolean(
      selected &&
        explanation &&
        explanation.entity_id === selected.entity_id &&
        explanation.rank_a === selected.rank_a &&
        explanation.rank_b === selected.rank_b,
    );

    return {
      slot_id: slot.slot_id,
      slot_label: SLOT_LABELS[slot.slot_id],
      status: slot.status,
      category: slot.resolved_category,
      category_label: slot.resolved_category
        ? CATEGORY_LABELS[slot.resolved_category]
        : null,
      entity_id: selected?.entity_id ?? null,
      name: selected?.name ?? null,
      display_type: selected?.display_type ?? null,
      rank_a: selected?.rank_a ?? null,
      rank_b: selected?.rank_b ?? null,
      why_it_works:
        explanationIsSafe && explanationMatches
          ? explanation?.why_it_works ?? null
          : null,
      empty_message: emptyMessage(slot.status, slot.slot_id),
    };
  });

  return {
    schema_version: 'JUDGE_FRONTEND_V1',
    run_id: request.run_id,
    destination_city: request.destination_city,
    state: execution.state,
    state_label: stateLabel(execution.state),
    people: [
      { side: 'A', label: 'Person A', profile_ref: request.person_a.profile_ref },
      { side: 'B', label: 'Person B', profile_ref: request.person_b.profile_ref },
    ],
    summary:
      explanationIsSafe
        ? explanationPayload?.shared_taste_summary ?? null
        : null,
    progress: execution.progress.map((item) => ({
      key: item.state,
      label: item.label,
      completed: item.completed,
    })),
    cards,
    evidence_note: EVIDENCE_NOTE,
  };
}
