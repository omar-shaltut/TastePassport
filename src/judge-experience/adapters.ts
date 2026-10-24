import type {
  Category,
  ExplanationPayload,
  ResolvedProfile,
  Side,
  SlotResult,
  RetrievalResult,
} from './types.ts';

export interface JudgeExperienceRunRequest {
  readonly run_id: string;
  readonly destination_city: string;
  readonly person_a: {
    readonly profile_ref: string;
  };
  readonly person_b: {
    readonly profile_ref: string;
  };
}

export interface ProfileResolutionRequest {
  readonly side: Side;
  readonly profile_ref: string;
}

export interface RetrievalRequest {
  readonly side: Side;
  readonly category: Category;
  readonly destination_city: string;
  readonly profile: ResolvedProfile;
}

export interface ExplanationRequest {
  readonly run_id: string;
  readonly destination_city: string;
  readonly slots: readonly SlotResult[];
}

export interface ProfileResolverAdapter {
  readonly adapter_id: string;
  resolveProfile(
    request: ProfileResolutionRequest,
  ): Promise<ResolvedProfile>;
}

export interface RetrievalSourceAdapter {
  readonly adapter_id: string;
  retrieve(
    request: RetrievalRequest,
  ): Promise<RetrievalResult>;
}

export interface ExplanationSourceAdapter {
  readonly adapter_id: string;
  explain(
    request: ExplanationRequest,
  ): Promise<ExplanationPayload>;
}

export interface JudgeExperienceAdapters {
  readonly profileResolver: ProfileResolverAdapter;
  readonly retrievalSource: RetrievalSourceAdapter;
  readonly explanationSource: ExplanationSourceAdapter;
}
