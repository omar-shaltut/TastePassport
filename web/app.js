const app = document.querySelector('#app');

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined && text !== null) node.textContent = text;
  return node;
}

function rankBadge(label, rank) {
  const badge = element('span', 'rank-badge');
  badge.append(element('strong', '', label), document.createTextNode(` #${rank}`));
  return badge;
}

function venueVisual(card) {
  const visual = element('div', 'venue-visual');
  visual.append(
    element('span', 'venue-visual-slot', card.slot_label),
    element(
      'span',
      'venue-visual-title',
      card.display_type || card.category_label || 'Shared place',
    ),
  );
  return visual;
}

function recommendationCard(card) {
  const article = element('article', `pick-card ${card.status !== 'SHARED_PRIMARY' ? 'pick-card--empty' : ''}`);
  const eyebrow = element('div', 'pick-label', card.slot_label);
  article.append(eyebrow);

  if (card.status !== 'SHARED_PRIMARY') {
    article.append(
      element('div', 'empty-icon', '—'),
      element('h2', 'pick-title', 'No shared match'),
      element('p', 'pick-copy', card.empty_message),
    );
    return article;
  }

  article.append(
    venueVisual(card),
    element('div', 'category-pill', card.display_type || card.category_label || 'Shared place'),
    element('h2', 'pick-title', card.name || 'Shared Qloo venue'),
  );

  const evidence = element('div', 'evidence-row');
  evidence.append(
    element('span', 'shared-badge', 'Shared Qloo match'),
    rankBadge('You', card.rank_a),
    rankBadge('Partner', card.rank_b),
  );
  article.append(evidence);

  if (card.why_it_works) {
    const reason = element('div', 'reason-box');
    reason.append(element('span', 'reason-label', 'Why it works for both'), element('p', '', card.why_it_works));
    article.append(reason);
  }

  return article;
}

function progressPanel(progress) {
  const section = element('section', 'trace-panel');
  const heading = element('div', 'section-heading');
  heading.append(
    element('span', 'eyebrow', 'Verified execution'),
    element('h2', '', 'How TastePassport built these picks'),
  );
  section.append(heading);

  const list = element('ol', 'trace-list');
  for (const item of progress) {
    const row = element('li', 'trace-item');
    row.append(
      element('span', `trace-check ${item.completed ? 'trace-check--done' : ''}`, item.completed ? '✓' : '•'),
      element('span', '', item.label),
    );
    list.append(row);
  }
  section.append(list);
  return section;
}

function renderFailure(payload) {
  app.replaceChildren();
  const panel = element('section', 'failure-card');
  panel.append(
    element('span', 'eyebrow', 'Unable to verify'),
    element('h1', '', 'We could not safely present shared picks.'),
    element('p', '', payload?.state_label || 'The run did not pass the presentation contract.'),
    element('p', 'muted', 'No venue is substituted or invented when evidence or validation fails.'),
  );
  app.append(panel);
}

function renderReady(payload) {
  app.replaceChildren();

  const hero = element('section', 'hero');
  const meta = element('div', 'hero-meta');
  meta.append(
    element('span', 'city-pill', payload.destination_city),
    element('span', 'status-pill', payload.state_label),
  );
  hero.append(
    meta,
    element('p', 'eyebrow', 'Your shared taste'),
    element('h1', '', 'Your Shared Picks'),
    element('p', 'hero-lead', `Three ways to experience ${payload.destination_city} together.`),
    element('p', 'hero-copy', payload.summary || 'Qloo surfaced shared evidence across your two taste profiles.'),
  );

  const people = element('div', 'people-row');
  for (const person of payload.people) {
    const chip = element('div', 'person-chip');
    chip.append(
      element('span', 'person-avatar', person.side),
      element('span', 'person-name', person.label),
    );
    people.append(chip);
  }
  hero.append(people);
  app.append(hero);

  const picksHeading = element('div', 'section-heading picks-heading');
  picksHeading.append(
    element('span', 'eyebrow', 'Culture · Outdoors · City Life'),
    element('h2', '', 'Shared picks across three parts of the city'),
  );
  app.append(picksHeading);

  const grid = element('section', 'pick-grid');
  for (const card of payload.cards) grid.append(recommendationCard(card));
  app.append(grid, progressPanel(payload.progress));

  const trust = element('section', 'trust-bar');
  trust.append(
    element('span', 'trust-mark', 'Q'),
    element('p', '', payload.evidence_note),
  );
  app.append(trust);
}

async function load() {
  try {
    const response = await fetch('/api/judge-run', { cache: 'no-store' });
    const payload = await response.json();
    if (!response.ok || payload.state === 'FAILED') {
      renderFailure(payload);
      return;
    }
    renderReady(payload);
  } catch {
    renderFailure(null);
  }
}

load();
