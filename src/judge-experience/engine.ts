import { CATEGORIES, SLOT_CHAINS, SLOT_ORDER, compareLeximin } from './policy.ts';
import type {
  Category,
  CategoryReconciliation,
  RankedEntity,
  RetrievalResult,
  SharedCandidate,
  Side,
  SlotResult,
} from './types.ts';

function firstOccurrenceMap(
  entities: readonly RankedEntity[],
): ReadonlyMap<string, RankedEntity> {
  const result = new Map<string, RankedEntity>();
  for (const entity of entities) {
    if (!result.has(entity.entity_id)) {
      result.set(entity.entity_id, entity);
    }
  }
  return result;
}

export function reconcileCategory(
  category: Category,
  listA: RetrievalResult,
  listB: RetrievalResult,
): CategoryReconciliation {
  if (listA.side !== 'A' || listB.side !== 'B') {
    throw new Error('Expected A/B retrieval ordering.');
  }
  if (listA.category !== category || listB.category !== category) {
    throw new Error(`Category mismatch while reconciling ${category}.`);
  }
  if (listA.destination_city !== listB.destination_city) {
    throw new Error(`City mismatch while reconciling ${category}.`);
  }
  if (listA.status !== 'COMPLETE' || listB.status !== 'COMPLETE') {
    return {
      category,
      status: 'EVIDENCE_UNAVAILABLE',
      ordered_shared_candidates: [],
    };
  }

  const a = firstOccurrenceMap(listA.entities);
  const b = firstOccurrenceMap(listB.entities);
  const shared: SharedCandidate[] = [];

  for (const [entityId, entityA] of a) {
    const entityB = b.get(entityId);
    if (!entityB) continue;

    const rankA = entityA.rank;
    const rankB = entityB.rank;
    shared.push({
      entity_id: entityId,
      name: entityA.name ?? entityB.name ?? null,
      display_type: entityA.display_type ?? entityB.display_type ?? null,
      retrieval_category: category,
      rank_a: rankA,
      rank_b: rankB,
      worst_rank: Math.max(rankA, rankB),
      total_rank: rankA + rankB,
    });
  }

  shared.sort(compareLeximin);
  return {
    category,
    status:
      shared.length > 0
        ? 'SHARED_CANDIDATES_AVAILABLE'
        : 'NO_SHARED_QLOO_EVIDENCE',
    ordered_shared_candidates: shared,
  };
}

function retrievalKey(side: Side, category: Category): string {
  return `${side}:${category}`;
}

export function reconcileAll(
  retrievals: readonly RetrievalResult[],
): readonly CategoryReconciliation[] {
  const index = new Map<string, RetrievalResult>();
  for (const retrieval of retrievals) {
    const key = retrievalKey(retrieval.side, retrieval.category);
    if (index.has(key)) {
      throw new Error(`Duplicate retrieval evidence for ${key}.`);
    }
    index.set(key, retrieval);
  }

  return CATEGORIES.map((category) => {
    const a = index.get(retrievalKey('A', category));
    const b = index.get(retrievalKey('B', category));
    if (!a || !b) {
      throw new Error(`Missing retrieval evidence for category ${category}.`);
    }
    return reconcileCategory(category, a, b);
  });
}

export function assembleSlots(
  reconciliation: readonly CategoryReconciliation[],
): readonly SlotResult[] {
  const byCategory = new Map(
    reconciliation.map((item) => [item.category, item] as const),
  );
  const used = new Set<string>();
  const slots: SlotResult[] = [];

  for (const slotId of SLOT_ORDER) {
    let resolved: SlotResult | null = null;

    for (const category of SLOT_CHAINS[slotId]) {
      const evidence = byCategory.get(category);
      if (!evidence) {
        resolved = {
          slot_id: slotId,
          status: 'EVIDENCE_UNAVAILABLE',
          resolved_category: category,
          selected: null,
        };
        break;
      }
      if (evidence.status === 'EVIDENCE_UNAVAILABLE') {
        resolved = {
          slot_id: slotId,
          status: 'EVIDENCE_UNAVAILABLE',
          resolved_category: category,
          selected: null,
        };
        break;
      }
      if (evidence.status === 'NO_SHARED_QLOO_EVIDENCE') {
        continue;
      }

      const selected = evidence.ordered_shared_candidates.find(
        (candidate) => !used.has(candidate.entity_id),
      );
      if (!selected) continue;

      used.add(selected.entity_id);
      resolved = {
        slot_id: slotId,
        status: 'SHARED_PRIMARY',
        resolved_category: category,
        selected,
      };
      break;
    }

    slots.push(
      resolved ?? {
        slot_id: slotId,
        status: 'NO_SHARED_QLOO_EVIDENCE',
        resolved_category: null,
        selected: null,
      },
    );
  }

  return slots;
}
