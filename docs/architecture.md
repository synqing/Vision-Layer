# Vision Layer Architecture

```mermaid
flowchart LR
  subgraph Intake[Task Intake]
    SPEC[Structured Issue Spec]
  end

  subgraph OA[Orchestrator (n8n)]
    POL[Policies & Gates]
  end

  subgraph CI[CI]
    PIO[PlatformIO Build]
    CHK[Static Checks/Size]
  end

  subgraph HIL[HIL Rig]
    FLASH[Flash FW]
    SENS[Serial/Logic/Camera]
    METRICS[FPS/Drop/Sync]
  end

  subgraph Vision[Vision Layer]
    subgraph SW[visiond-swift]
      SCK[ScreenCaptureKit]
      AX[Accessibility (AX)]
    end
    subgraph DOM[dom-bridge]
      PW[Playwright Locators]
    end
    subgraph PY[parserd]
      PARSE[Deterministic Parsers]
      PATCH[RFC-6902 JSON Patch]
      JSEQ[RFC-7464 JSON-Seq]
    end
  end

  SPEC --> OA
  OA -- fan-out / wait --> CI
  OA -- fan-out / wait --> HIL
  OA <-- facts / deltas --> Vision
  CI <-- read panes --> Vision
  HIL <-- read panes --> Vision

  SW <--> DOM
  SW --> PY
  DOM --> PY
  PY --> PATCH
  PY --> JSEQ
```

## Data Path (Per Pane)

```mermaid
sequenceDiagram
  participant AX as AX / DOM
  participant SCK as ScreenCaptureKit
  participant MAP as Geometry Map
  participant OCR as Vision OCR (fallback)
  participant PAR as Parser (regex/state)
  participant OA as Orchestrator

  AX->>AX: Locate element (role/test-id)
  AX-->>MAP: bbox (CSS px) or kAXFrame
  SCK-->>MAP: {ContentRect, ScaleFactor, ContentScale}
  MAP-->>PAR: crop rect (pixels, per-frame)
  PAR->>PAR: parse structured text
  PAR->>OCR: [only if needed] recognize text
  OCR-->>PAR: tokens + confidences
  PAR-->>OA: facts + RFC-6902 patch (JSON-Seq stream when watching)
```

## Mapping Math

Given viewport size `{Wv, Hv}`, visible rect in pixels `{Vx, Vy, Vw, Vh}`, and DOM bbox in CSS px `{x, y, w, h}`:

- `sx = Vw / Wv`, `sy = Vh / Hv`
- `crop.x = Vx + x * sx`, `crop.y = Vy + y * sy`
- `crop.w = w * sx`, `crop.h = h * sy`

Attachments come from ScreenCaptureKit per frame:

- ContentRect (points) → multiply by ScaleFactor → visible rect (pixels)
- ContentScale → backing content size (retina aware)

## Emission Semantics

- Emit typed facts for each pane (e.g., `ci.status`, `pr.mergeable`) only when values change.
- Deltas conform to RFC-6902 JSON Patch; streaming uses RFC-7464 JSON Text Sequences.

