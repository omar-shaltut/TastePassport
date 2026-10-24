import type { Category, SharedCandidate, SlotId } from './types.ts';

export const CONTRACT_VERSION = 'JUDGE_EXPERIENCE_V1' as const;
export const SELECTOR_POLICY_ID = 'LEXIMIN_RANK_V1' as const;
export const SLOT_CONTRACT_ID = 'CROSS_CATEGORY_SLOT_CONTRACT_V1' as const;

export const CATEGORIES: readonly Category[] = [
  'art_gallery',
  'book_store',
  'museum',
  'park',
  'restaurant',
  'shopping_mall',
];

export const SLOT_ORDER: readonly SlotId[] = [
  'CULTURE',
  'OUTDOORS',
  'CITY_LIFE',
];

export const SLOT_CHAINS: Readonly<Record<SlotId, readonly Category[]>> = {
  CULTURE: ['museum', 'art_gallery', 'book_store'],
  OUTDOORS: ['park'],
  CITY_LIFE: ['restaurant', 'shopping_mall'],
};

export function compareEntityId(left: string, right: string): number {
  if (left === right) return 0;
  return left < right ? -1 : 1;
}

export function compareLeximin(
  left: SharedCandidate,
  right: SharedCandidate,
): number {
  if (left.worst_rank !== right.worst_rank) {
    return left.worst_rank - right.worst_rank;
  }
  if (left.total_rank !== right.total_rank) {
    return left.total_rank - right.total_rank;
  }
  return compareEntityId(left.entity_id, right.entity_id);
}
