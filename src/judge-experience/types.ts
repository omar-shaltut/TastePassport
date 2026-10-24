export type Side = 'A' | 'B';

export type Category =
  | 'art_gallery'
  | 'book_store'
  | 'museum'
  | 'park'
  | 'restaurant'
  | 'shopping_mall';

export type SlotId = 'CULTURE' | 'OUTDOORS' | 'CITY_LIFE';

export type RunState =
  | 'IDLE'
  | 'INPUT_READY'
  | 'RESOLVING_PROFILES'
  | 'RETRIEVING_QLOO'
  | 'RECONCILING'
  | 'ASSEMBLING_SLOTS'
  | 'EXPLAINING'
  | 'VALIDATING'
  | 'READY'
  | 'PARTIAL_READY'
  | 'FAILED';

export type RetrievalStatus = 'COMPLETE' | 'EVIDENCE_UNAVAILABLE';
export type ReconciliationStatus =
  | 'SHARED_CANDIDATES_AVAILABLE'
  | 'NO_SHARED_QLOO_EVIDENCE'
  | 'EVIDENCE_UNAVAILABLE';
export type SlotStatus =
  | 'SHARED_PRIMARY'
  | 'NO_SHARED_QLOO_EVIDENCE'
  | 'EVIDENCE_UNAVAILABLE';

export interface RankedEntity {
  readonly entity_id: string;
  readonly rank: number;
  readonly name?: string | null;
  readonly display_type?: string | null;
}

export interface RetrievalResult {
  readonly side: Side;
  readonly category: Category;
  readonly destination_city: string;
  readonly status: RetrievalStatus;
  readonly entities: readonly RankedEntity[];
}

export interface SharedCandidate {
  readonly entity_id: string;
  readonly name: string | null;
  readonly display_type: string | null;
  readonly retrieval_category: Category;
  readonly rank_a: number;
  readonly rank_b: number;
  readonly worst_rank: number;
  readonly total_rank: number;
}

export interface CategoryReconciliation {
  readonly category: Category;
  readonly status: ReconciliationStatus;
  readonly ordered_shared_candidates: readonly SharedCandidate[];
}

export interface SlotResult {
  readonly slot_id: SlotId;
  readonly status: SlotStatus;
  readonly resolved_category: Category | null;
  readonly selected: SharedCandidate | null;
}

export interface ResolvedProfile {
  readonly side: Side;
  readonly profile_ref: string;
  readonly qloo_seed_entity_ids: readonly string[];
}

export interface ExplanationSlot {
  readonly slot_id: SlotId;
  readonly entity_id: string;
  readonly name: string | null;
  readonly rank_a: number;
  readonly rank_b: number;
  readonly why_it_works: string;
}

export interface ExplanationPayload {
  readonly slots: readonly ExplanationSlot[];
  readonly shared_taste_summary?: string | null;
}

export interface FixtureRun {
  readonly contract_version: 'JUDGE_EXPERIENCE_V1';
  readonly selector_policy_id: 'LEXIMIN_RANK_V1';
  readonly slot_contract_id: 'CROSS_CATEGORY_SLOT_CONTRACT_V1';
  readonly run_id: string;
  readonly destination_city: string;
  readonly resolved_profiles: readonly ResolvedProfile[];
  readonly retrievals: readonly RetrievalResult[];
  readonly explanation_payload: ExplanationPayload;
}

export interface ValidationResult {
  readonly status: 'PASS' | 'FAIL';
  readonly reasons: readonly string[];
}

export interface ProgressItem {
  readonly state:
    | 'RESOLVING_PROFILES'
    | 'RETRIEVING_QLOO'
    | 'RECONCILING'
    | 'ASSEMBLING_SLOTS'
    | 'EXPLAINING'
    | 'VALIDATING';
  readonly label: string;
  readonly completed: boolean;
}

export interface FixtureExecutionResult {
  readonly run_id: string;
  readonly state: 'READY' | 'PARTIAL_READY' | 'FAILED';
  readonly state_history: readonly RunState[];
  readonly completed_states: readonly RunState[];
  readonly progress: readonly ProgressItem[];
  readonly reconciliation: readonly CategoryReconciliation[];
  readonly slots: readonly SlotResult[];
  readonly validation: ValidationResult | null;
  readonly error_code:
    | 'PROFILE_RESOLUTION_FAILED'
    | 'QLOO_RETRIEVAL_FAILED'
    | 'EXPLANATION_VALIDATION_FAILED'
    | 'INTERNAL_CONTRACT_VIOLATION'
    | null;
}
