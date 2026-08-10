# XowCase — Spec Técnica & Backlog
*(nome provisório, segue o padrão Brick — troca fácil por outro)*

App macOS para gravação de demos de apps (Simulator, device físico, tela) com molduras de device, cena 3D, edição e export. Arquitetura híbrida: Flutter (UI/orquestração) + Swift nativo (captura, render, export).

---

## 1. Visão Geral

**Problema:** criar vídeos/screenshots polidos de apps (App Store, marketing, pitch) exige várias ferramentas soltas (gravação, moldura de device, edição, cena 3D).

**Proposta:** app único no macOS que grava (Simulator/device/tela), aplica moldura, permite editar timeline simples, e exporta em formatos prontos pra App Store/marketing — com opção de cena 3D com profundidade.

**Modelo de negócio:** aberto ainda — open source (core) + freemium (features de render 3D/export avançado pagas) é a linha mais provável, similar ao modelo de ferramentas dev (ex: Tuist, Fastlane com plugins pagos).

---

## 2. Personas

| Persona | Necessidade |
|---|---|
| Dev solo / indie | Screenshot rápido pra App Store, sem sair do Mac |
| Time de marketing de app | Vídeos de demo pra redes sociais / landing page |
| DevRel / palestrante | Gravar demo de app pra apresentação (seu caso de uso mais direto — GDG, talks) |

---

## 3. Requisitos Funcionais

### RF — Captura
- RF01: Gravar iOS Simulator (via `simctl io recordVideo`)
- RF03: Gravar janela específica de app macOS
- RF04: Gravar tela cheia (multi-monitor aware)
- RF05: Capturar cursor (posição, cliques) como dado separado da imagem, pra permitir indicadores de tap/swipe sintéticos depois
- RF06: Selecionar fonte de áudio (opcional, mic) durante gravação

> Fora de escopo por ora: gravação de device físico via USB (Face ID, Dynamic Island). Fica documentado como possível V3 caso surja demanda, mas não entra no roadmap atual.

### RF — Moldura de Device (Device Frame)
- RF07: Aplicar moldura realista (iPhone, iPad, Mac, Watch) sobre gravação/screenshot
- RF08: Escolher cor/modelo do device (ex: iPhone 15 Pro Titânio, iPhone 16, etc.)
- RF09: Fundo customizável atrás do device (cor sólida, gradiente, imagem)
- RF10: (V2) Cena 3D — device posicionado em ambiente 3D com sombra e profundidade de campo

### RF — Edição
- RF11: Timeline com até N tracks de vídeo (MVP: 1 track; V1: múltiplas)
- RF12: Trim / split de clipes
- RF13: Texto animado sobre o vídeo (posição, timing, estilo)
- RF14: Zoom manual (definir região + timing)
- RF15: (V1) Auto Zoom heurístico (segue posição do cursor/toque)
- RF16: Indicadores sintéticos de tap/swipe quando não há dado de cursor real (ex: gravações onde o cursor não foi capturado)

### RF — Transcrição/Legenda
- RF17: (V1) Transcrição local via Whisper (Core ML / whisper.cpp), sem upload de dados
- RF18: Editor de transcript com sincronização ao vídeo

### RF — Export
- RF19: Export de vídeo H.264 / HEVC
- RF20: Export com canal alpha (ProRes 4444 ou similar) — pra sobrepor em outros materiais
- RF21: Export GIF
- RF22: Export de screenshot estático (PNG) com moldura aplicada, em resoluções da App Store
- RF23: Preset de resolução por destino (App Store, Instagram Reels, Twitter/X, etc.)

### RF — Projeto/Persistência
- RF24: Salvar projeto (estado de timeline, clipes, configs) em formato próprio (`.xowcase` ou JSON+assets)
- RF25: Reabrir projeto e continuar edição

---

## 4. Requisitos Não-Funcionais

- RNF01: macOS 14+ (avaliar se dá pra baixar o requisito do Matte, que pede 15+, usando fallback sem `ScreenCaptureKit` mais recente)
- RNF02: Processamento 100% local — nenhuma gravação/áudio sai da máquina sem ação explícita do usuário (importante pro pitch open source/privacy)
- RNF03: Performance de preview em tempo real fluido mesmo com timeline de vários minutos
- RNF04: App nativo assinado e notarizado (distribuição fora da App Store) — ou compatível com sandbox da Mac App Store, a definir
- RNF05: Build reproduzível via CI (GitHub Actions com runner macOS)
- RNF06: Cobertura de testes na camada Swift de captura/export (mais crítica e mais frágil a mudanças de OS)

---

## 5. Especificação Técnica

### 5.1 Arquitetura

```
┌─────────────────────────────────────────┐
│              Flutter (Dart)              │
│  UI: timeline, editor, preview, export   │
│  State: Riverpod/Bloc                    │
└───────────────┬───────────────────────────┘
                │ MethodChannel / Pigeon (codegen)
                │ + FlutterTexture (frames de vídeo/preview nativo)
┌───────────────▼───────────────────────────┐
│           Swift Nativo (macOS)            │
│  - ScreenCaptureKit (captura de tela)     │
│  - AVFoundation (device físico, export)   │
│  - simctl bridge (Simulator)              │
│  - Metal/SceneKit (cena 3D, V2)           │
│  - whisper.cpp / Core ML (transcrição, V1)│
└─────────────────────────────────────────┘
```

**Decisão chave:** usar **Pigeon** (codegen oficial do Flutter) em vez de `MethodChannel` cru — reduz boilerplate e erros de serialização na ponte Dart↔Swift, dado que o volume de chamadas (start/stop capture, progress de export, frames de preview) é considerável.

### 5.2 Captura

- Simulator: shell out pra `xcrun simctl io <udid> recordVideo <path>`, processo gerenciado pelo lado Swift (evita zumbis, captura stdout/stderr, timeout).
- Tela/janela: `ScreenCaptureKit` (`SCStream`, `SCContentFilter`) — API moderna, substitui `CGDisplayStream` deprecado.
### 5.3 Preview em tempo real

- Frames renderizados no lado Swift são expostos ao Flutter via `FlutterTexture` (macOS embedder já suporta isso) — evita serializar frame a frame por MethodChannel, que não aguentaria a taxa de quadros.

### 5.4 Render de moldura/cena

- MVP/V1: composição 2D simples — overlay de PNG de moldura sobre o vídeo, via `AVVideoComposition` (Core Animation layer combinado com `AVFoundation`). Suficiente pra RF07-RF09.
- V2 (cena 3D): `SceneKit` ou `RealityKit` pra posicionar o device num ambiente, com câmera animável e profundidade de campo — renderiza para textura offscreen, depois combina no pipeline de export via `AVFoundation`. Esse é o componente de maior risco técnico e maior esforço.

### 5.5 Export

- Pipeline via `AVAssetExportSession` / `AVAssetWriter` (mais controle de codec) para H.264/HEVC/ProRes.
- Alpha channel exige ProRes 4444 — validar suporte e tamanho de arquivo resultante cedo (pode ser proibitivo pra distribuição/free tier).

### 5.6 Transcrição (V1)

- `whisper.cpp` compilado com Core ML (Apple otimizou modelos Whisper pra Neural Engine) — roda local, sem custo de API, alinhado com RNF02.

### 5.7 Persistência

- Projeto como pasta: `project.json` (metadados/timeline) + pasta de assets (clipes originais, thumbnails cacheados). Formato simples, versionado, fácil de debugar — evita banco embarcado no MVP.

### 5.8 Distribuição / Licenciamento (a decidir, não bloqueia o MVP)

- Se open core: repositório público com captura + moldura 2D + export básico; features V2 (3D, auto zoom, transcrição) como plugin/licença paga.
- Se freemium simples: app fechado, free tier limita export (marca d'água ou resolução) e algumas molduras/cenas.

---

## 6. Backlog

### Épico 1 — Fundações do projeto
- [ ] Setup do repo: Flutter app macOS + módulo Swift nativo separado, com Pigeon configurado
- [ ] Definir formato de projeto (`project.json` + estrutura de pastas)

### Épico 2 — Captura MVP
- [ ] RF01: gravação do Simulator via `simctl`
- [ ] RF04: gravação de tela cheia via `ScreenCaptureKit`
- [ ] RF03: gravação de janela específica
- [ ] Preview ao vivo da gravação via `FlutterTexture`

### Épico 3 — Moldura estática
- [ ] RF07/RF08: aplicar moldura de device sobre vídeo gravado (composição 2D)
- [ ] RF09: fundo customizável
- [ ] RF22: export de screenshot com moldura (PNG, presets de resolução)

### Épico 4 — Editor básico
- [ ] RF11 (single track): timeline simples com um clipe
- [ ] RF12: trim/split
- [ ] RF24/RF25: salvar/abrir projeto

### Épico 5 — Export de vídeo
- [ ] RF19: export H.264/HEVC
- [ ] RF23: presets de resolução por destino
- [ ] RF21: export GIF

**→ Fim do MVP.** Nesse ponto já é usável pra gravar demo do CastBrick/talks do GDG.

### Épico 6 — Edição avançada (V1)
- [ ] RF13: texto animado
- [ ] RF14: zoom manual
- [ ] RF11 (multi-track)
- [ ] RF15: auto zoom heurístico

### Épico 7 — Transcrição (V1)
- [ ] RF17: integração whisper.cpp + Core ML
- [ ] RF18: editor de transcript sincronizado

### Épico 8 — Indicadores sintéticos de interação
- [ ] RF05: captura de cursor (posição/cliques) junto da gravação
- [ ] RF16: indicadores sintéticos de tap/swipe quando não há dado de cursor

### Épico 9 — Cena 3D (V2)
- [ ] Spike: protótipo SceneKit/RealityKit com device + luz + sombra
- [ ] RF10: cena 3D com câmera animável e depth of field
- [ ] Integração da cena 3D no pipeline de export

### Épico 10 — Alpha channel / export avançado (V2)
- [ ] RF20: export ProRes 4444 com alpha
- [ ] Validar tamanho de arquivo / viabilidade pra free tier

---

## 7. Riscos técnicos a validar cedo (spikes antes de comprometer o roadmap)

1. **Performance do preview em tempo real** via `FlutterTexture` com vídeo de alta resolução — testar cedo com clipe real, não só mock.
2. **Tamanho/viabilidade do alpha channel** em ProRes pra distribuição via app pequeno/free tier.
3. **Notarização e distribuição fora da Mac App Store** vs sandbox exigido pela App Store — decide se dá pra usar `ScreenCaptureKit` sem restrição.
4. **Cena 3D (SceneKit/RealityKit)** integrada ao pipeline de export sem gargalo de performance — validar com spike antes de comprometer o Épico 9.

---

## 8. Roadmap sugerido

| Fase | Escopo | Meta |
|---|---|---|
| MVP | Épicos 1-5 | App funcional pra uso pessoal/talks |
| V1 | Épicos 6-8 | Paridade parcial com Matte (sem cena 3D) |
| V2 | Épicos 9-10 | Diferencial visual (3D) + monetização definida |