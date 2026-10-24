import type {
  ExplanationPayload,
  SlotResult,
  ValidationResult,
} from './types.ts';

const forbiddenClaimPatterns = [
  /#1\s+overall/i,
  /\bperfect\s+match\b/i,
  /\buniquely\s+matched\b/i,
  /\bunique\s+to\s+(?:you|this\s+pair)\b/i,
  /\bguaranteed\s+to\s+(?:love|enjoy)\b/i,
];

export function validateExplanation(
  slots: readonly SlotResult[],
  payload: ExplanationPayload,
): ValidationResult {
  const reasons: string[] = [];
  const selected = slots.filter(
    (slot): slot is SlotResult & { selected: NonNullable<SlotResult['selected']> } =>
      slot.status === 'SHARED_PRIMARY' && slot.selected !== null,
  );

  if (payload.slots.length !== selected.length) {
    reasons.push('Explanation slot count does not match immutable selection.');
  }

  for (let index = 0; index < selected.length; index += 1) {
    const expected = selected[index];
    const actual = payload.slots[index];
    if (!expected || !actual) continue;

    if (actual.slot_id !== expected.slot_id) {
      reasons.push(`Slot order changed at index ${index}.`);
    }
    if (actual.entity_id !== expected.selected.entity_id) {
      reasons.push(`Entity ID changed for ${expected.slot_id}.`);
    }
    if ((actual.name ?? null) !== (expected.selected.name ?? null)) {
      reasons.push(`Venue name changed for ${expected.slot_id}.`);
    }
    if (
      actual.rank_a !== expected.selected.rank_a ||
      actual.rank_b !== expected.selected.rank_b
    ) {
      reasons.push(`Source ranks changed for ${expected.slot_id}.`);
    }
  }

  const text = [
    payload.shared_taste_summary ?? '',
    ...payload.slots.map((slot) => slot.why_it_works),
  ].join('\n');
  for (const pattern of forbiddenClaimPatterns) {
    if (pattern.test(text)) {
      reasons.push(`Unsupported truth-contract claim matched ${pattern}.`);
    }
  }

  return {
    status: reasons.length === 0 ? 'PASS' : 'FAIL',
    reasons,
  };
}
