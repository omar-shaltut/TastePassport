import { executeWithAdaptersEnvelope } from '../judge-experience/adapter-runner.ts';
import type { JudgeExperienceRunRequest } from '../judge-experience/adapters.ts';
import { createFixtureAdapters } from '../judge-experience/fixture-adapter.ts';
import type { FixtureRun } from '../judge-experience/types.ts';
import { buildFrontendPayload } from './presentation.ts';

export async function executeFixtureForFrontend(fixture: FixtureRun) {
  const personA = fixture.resolved_profiles.find((profile) => profile.side === 'A');
  const personB = fixture.resolved_profiles.find((profile) => profile.side === 'B');
  if (!personA || !personB) {
    throw new Error('Frontend fixture requires one resolved profile for each side.');
  }

  const request: JudgeExperienceRunRequest = {
    run_id: fixture.run_id,
    destination_city: fixture.destination_city,
    person_a: { profile_ref: personA.profile_ref },
    person_b: { profile_ref: personB.profile_ref },
  };

  const envelope = await executeWithAdaptersEnvelope(
    request,
    createFixtureAdapters(fixture),
  );
  return buildFrontendPayload(request, envelope);
}
