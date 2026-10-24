import type {
  ExplanationRequest,
  ExplanationSourceAdapter,
  JudgeExperienceAdapters,
  ProfileResolutionRequest,
  ProfileResolverAdapter,
  RetrievalRequest,
  RetrievalSourceAdapter,
} from './adapters.ts';
import type {
  ExplanationPayload,
  FixtureRun,
  ResolvedProfile,
  RetrievalResult,
} from './types.ts';

export class FixtureAdapter
  implements
    ProfileResolverAdapter,
    RetrievalSourceAdapter,
    ExplanationSourceAdapter
{
  readonly adapter_id = 'FIXTURE_ADAPTER_V1';
  private readonly fixture: FixtureRun;

  constructor(fixture: FixtureRun) {
    this.fixture = fixture;
  }

  async resolveProfile(
    request: ProfileResolutionRequest,
  ): Promise<ResolvedProfile> {
    const matches = this.fixture.resolved_profiles.filter(
      (profile) =>
        profile.side === request.side &&
        profile.profile_ref === request.profile_ref,
    );
    const match = matches[0];

    if (matches.length !== 1 || !match) {
      throw new Error(
        `Fixture profile resolution failed for ${request.side}:${request.profile_ref}.`,
      );
    }

    return match;
  }

  async retrieve(request: RetrievalRequest): Promise<RetrievalResult> {
    if (
      request.profile.side !== request.side ||
      request.profile.qloo_seed_entity_ids.length === 0
    ) {
      throw new Error('Fixture retrieval request has invalid resolved profile evidence.');
    }

    const matches = this.fixture.retrievals.filter(
      (retrieval) =>
        retrieval.side === request.side &&
        retrieval.category === request.category &&
        retrieval.destination_city === request.destination_city,
    );
    const match = matches[0];

    if (matches.length !== 1 || !match) {
      throw new Error(
        `Fixture retrieval missing for ${request.side}:${request.category}:${request.destination_city}.`,
      );
    }

    return match;
  }

  async explain(_request: ExplanationRequest): Promise<ExplanationPayload> {
    return this.fixture.explanation_payload;
  }
}

export function createFixtureAdapters(
  fixture: FixtureRun,
): JudgeExperienceAdapters {
  const adapter = new FixtureAdapter(fixture);
  return {
    profileResolver: adapter,
    retrievalSource: adapter,
    explanationSource: adapter,
  };
}
