# TastePassport

**Make a new city feel like yours.**

TastePassport is an agentic cultural translation project for the **Qloo Agentic Hackathon 2026**. It is designed for people relocating to a new city—international students, expats, relocated workers, and others who want local recommendations that reflect their existing tastes rather than generic popularity.

## Core idea

A user provides a few taste signals across domains (for example food, films, brands, design, places, or other interests) plus a destination city. TastePassport uses Qloo as the core source of cultural intelligence to:

1. resolve the user's taste signals to Qloo entities;
2. build a cross-domain taste profile;
3. discover locally relevant matches in the new city;
4. evaluate result quality and diversity;
5. refine the search when needed; and
6. explain each final recommendation using grounded Qloo evidence.

The goal is **cultural translation**, not another generic travel planner.

## Agentic workflow

`Understand → Resolve → Profile → Discover → Evaluate → Refine → Explain`

The planned MVP limits refinement to two loops so the behavior remains inspectable and predictable.

## Grounding principle

Qloo is intended to be the source of recommendation decisions. Any LLM layer is limited to planning, evaluation, and natural-language explanation; it must not invent venues or recommendations that were not grounded in Qloo results.

## Compliance

TastePassport is developed under a project-owner compliance policy that takes precedence over competition optimization. See [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md).

## Project constitution

The current product scope and non-negotiable design decisions are documented in [`docs/PROJECT_CONSTITUTION.md`](docs/PROJECT_CONSTITUTION.md).

## Status

Early development / technical validation.

The immediate milestone is to validate the taste-translation workflow against real Qloo API responses before building the full UI and agent loop.

The next protocol is the [QMBT-2R draft](docs/QMBT_2R_PROTOCOL.md), which is
**not yet pre-registered** and authorizes no live execution. It preserves the
frozen evaluator rules and leaves holdout selection and retrieval depth for
human review. Its static checks run offline:

```powershell
./scripts/validation/Test-Qmbt2rProtocol.ps1
./scripts/validation/Test-Qmbt2rProtocol.Tests.ps1
```

## Planned stack

- Next.js
- TypeScript
- Node.js
- Qloo API
- Vercel
- GitHub

No local GPU or model training is required for the MVP.

## Security

Secrets must never be committed. Use local environment variables and the provided `.env.example` template.

## License

MIT License. See [`LICENSE`](LICENSE).
