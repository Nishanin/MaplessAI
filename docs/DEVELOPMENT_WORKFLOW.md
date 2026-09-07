# MapLess AI — Developer Workflow & Onboarding

## 1. Quick Setup Guide

### Prerequisites
- **Flutter SDK**: 3.41+ (Dart 3.11+)
- **Node.js**: v20+ or v24+
- **npm**: 10+
- **Git**: 2.40+

### Monorepo Setup Steps

```powershell
# 1. From the repository root, install backend dependencies
cd backend
npm install

# 2. Install Flutter mobile dependencies
cd ../apps/mobile
flutter pub get

# 3. Verify backend tests pass
cd ../../backend
npm test

# 4. Verify Flutter tests pass
cd ../apps/mobile
flutter test
```

---

## 2. Mock-Driven Independent Development

To allow all four developers to build without waiting for each other, `test_data/vit_floor_1.json` provides a complete, self-contained indoor graph dataset for the VIT Computer Engineering First Floor.

```
                    Lab 101
                       |
                       |
Entrance -- Reception -- Corridor
                       |
                       |
                    Library
                       |
                   Staircase
                       |
                    Exit A
```

### How Each Member Uses the Mock Data

#### Nishant (UI/UX & Mapping)
- Load `test_data/vit_floor_1.json` directly in Flutter using `JsonUtils.loadMockVitFloor1()`.
- Test rendering nodes and edges on the custom `IndoorCanvas` without running a backend server.
- Test visitor location selection and creator path recording UI immediately.

#### Pratik (Spatial Intelligence & Navigation Engine)
- Use `test_data/vit_floor_1.json` as the input fixture for unit testing $A^*$ and Dijkstra algorithms.
- Test routing scenarios:
  - `entrance` $\rightarrow$ `lab-101` (Standard shortest path)
  - `reception` $\rightarrow$ `exit-a` with `accessible: true` (Should avoid `staircase` and route through accessible paths or report obstruction)
  - Simulating blocked corridors and verifying dynamic alternate routing.

#### Surabhi (Semantic AI & Knowledge Graph)
- Use `semanticMetadata` array in `vit_floor_1.json` to test entity matching.
- Test queries:
  - "Find computer lab" $\rightarrow$ Resolves to `lab-101` (via tag "computers").
  - "Where is the fire exit?" $\rightarrow$ Resolves to `exit-a` (via intent `EMERGENCY_EXIT`).
  - "Find quiet study area" $\rightarrow$ Resolves to `library` (via description and tag "quiet").

#### Piyush (Map Versioning)
- Use `vit_floor_1.json` as baseline Version 1 snapshot.
- Create a modified version (e.g., adding a new node `lab-102`) to test `compareVersions()` and graph diffing.
- Verify `rollbackVersion()` restores the exact `vit_floor_1.json` state.

---

## 3. Daily Git Workflow

1. **Start from clean main**:
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Switch to your dedicated branch**:
   - Nishant: `git checkout feature/nishant-mapping-ui`
   - Pratik: `git checkout feature/pratik-spatial-engine`
   - Surabhi: `git checkout feature/surabhi-semantic-ai`
   - Piyush: `git checkout feature/piyush-versioning`
3. **Rebase regularly onto main**:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
4. **Run local verification before committing**:
   ```bash
   # Backend
   cd backend && npm test
   # Flutter
   cd ../apps/mobile && flutter analyze && flutter test
   ```
5. **Open a PR**:
   - Provide a description of domain changes.
   - Include automated tests.
   - Attach UI screenshots if Nishant made presentation modifications.
