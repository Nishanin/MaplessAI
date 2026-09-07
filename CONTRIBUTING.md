# Contributing to MapLess AI

Welcome to **MapLess AI** — "A Graph-Augmented Indoor Mapping and Spatial Intelligence Platform".

To enable 4 engineers to develop concurrently without waiting on each other or experiencing merge friction, this repository enforces strict feature boundaries, clean shared contracts, and established Git collaboration standards.

---

## 1. Team Ownership & Feature Boundaries

| Member | Feature Domain | Mobile Workspace (`apps/mobile/lib/`) | Backend Workspace (`backend/src/`) |
| :--- | :--- | :--- | :--- |
| **Nishant** | **Complete UI/UX & Mapping**: All Flutter screens (mapping, navigation, AI chat, versioning, creator/visitor/contributor), router shell, shared widgets, design system, sensor integration, map editor. | `features/mapping/`<br>`core/` (UI, shell, widgets, theme, router) | `features/mapping/` |
| **Pratik** | **Spatial Intelligence Domain**: Spatial Graph engine, A*, Dijkstra, multi-floor routing, accessibility routing, emergency routing, blocked-path handling, turn instruction generation. *(No UI code)* | `features/navigation/` (services, algorithms, providers, state) | `features/navigation/` |
| **Surabhi** | **Semantic AI Domain**: Semantic metadata, semantic knowledge graph, SLM interface, intent recognition, entity extraction, structured graph-query generation, validation/fallback. *(No UI code)* | `features/ai/` (services, providers, state) | `features/ai/` |
| **Piyush** | **Map Versioning ONLY**: Snapshot generation, version numbering, version history, graph diffing, rollback, audit trail. *(No UI, auth, mapping, or AI)* | `features/versioning/` (services, providers, state) | `features/versioning/` |

---

## 2. Git Branching Strategy

Development takes place exclusively on dedicated feature branches:

- `main` — Production-ready, stable release branch. Direct commits are forbidden.
- `feature/nishant-mapping-ui` — Nishant's active development branch.
- `feature/pratik-spatial-engine` — Pratik's active development branch.
- `feature/surabhi-semantic-ai` — Surabhi's active development branch.
- `feature/piyush-versioning` — Piyush's active development branch.

---

## 3. The 9 Golden Collaboration Rules

1. **Nobody directly develops on `main`**: All changes must arrive through Pull Requests with approval.
2. **Work strictly inside your feature boundary**: Each member develops within their assigned mobile and backend feature directories.
3. **Do not modify another member's feature folder without agreement**: If cross-feature interaction is required, define an interface or coordinate with the feature owner.
4. **Shared contracts (`contracts/`) are frozen**: Contracts act as the single source of truth. Any schema amendment requires unanimous team consensus.
5. **Use small, atomic commits**: Commits should be focused on one logical unit with descriptive conventional commit messages (e.g., `feat(navigation): implement a-star heuristic`).
6. **Pull / rebase from `main` frequently**: Always rebase on latest `main` before starting significant work or opening a PR to prevent stale divergence.
7. **Complete PR checklists**: Every Pull Request must include:
   - Clear description of the change and rationale.
   - List of touched files.
   - Accompanying unit/integration tests.
   - Screenshots / screen recordings whenever UI is altered.
8. **Avoid large, unrelated commits**: Do not bundle formatting refactors or unrelated files into feature PRs.
9. **Zero-secret tolerance**: Never commit `.env` files, Firebase service account keys, API keys, database credentials, or secret configuration. Keep them in local gitignored environments.

---

## 4. UI Ownership Rule

**Nishant owns 100% of the Flutter UI/UX presentation layer.**
- Pratik, Surabhi, and Piyush provide pure domain models, services, repositories, and Riverpod StateNotifiers in their respective `features/` folders.
- Nishant connects these state providers to screens in `features/mapping/presentation/` and `core/`.
- This eliminates UI conflicts, inconsistent themes, and merge collisions in `main.dart` or router configurations.

---

## 5. Development Verification Before Pushing

Before opening a PR, always ensure:
```bash
# Backend verification
cd backend
npm test

# Mobile verification
cd ../apps/mobile
flutter analyze
flutter test
```
