# 로컬 전환 가이드

이 프로젝트를 본인 컴퓨터로 옮겨 계속하는 방법입니다.

**전환 시점이 좋습니다.** Phase 0 조사 두 건이 방금 끝났는데, **두 에이전트가
독립적으로 같은 결론에 도달**했습니다 — *"돈 쓰기 전에 차단되지 않은 기기에서
직접 확인하라."* 이 환경의 한계가 지금 프로젝트의 병목입니다.

---

## 1. 여기서 막혔던 것 / 로컬에서 풀리는 것

| 항목 | 이 환경 | 로컬 |
|---|---|---|
| YouTube 열람 | **403 차단** | ✅ |
| 원본 영상 다운로드 (`yt-dlp`) | 불가 | ✅ |
| 영상 조립 (`ffmpeg`) | **미설치** | ✅ 설치하면 |
| Reddit 1차 소스 | **크롤러 차단** | ✅ |
| Substack 비평문 | **403** | ✅ |
| Google Trends | 데이터 미확보 | ✅ |
| Wikipedia 등 일반 페이지 | 에이전트에게 차단됨 | ✅ |

두 조사 보고서 모두 **자체 한계를 명시**하고 있습니다. 포화도 지도는
"방향성으로만" 쓰라고 되어 있고, 채널 수·구독자·조회수 직접 데이터는
**전무**합니다. 로컬에서 브라우저 한 시간이면 그 구멍이 메워집니다.

---

## 2. 파일 가져오기

### 방법 A — git clone (권장)

작업물 전체가 브랜치에 푸시되어 있습니다.

```bash
git clone https://github.com/StevenSSAhn/linux-surface.git
cd linux-surface
git checkout claude/youtube-video-ai-recreation-e03977
ls ai-shorts/
```

### 방법 B — 압축 파일

채팅으로 보내드린 `ai-shorts.tar.gz` 를 받아서 풀면 됩니다.

```bash
tar -xzf ai-shorts.tar.gz
```

---

## 3. 별도 저장소로 분리하세요 (중요)

현재 이 자료는 **`linux-surface` 포크 안에 들어가 있습니다.** 리눅스 커널
패치 저장소이고, 숏폼 기획 문서가 있을 자리가 아닙니다. 세션 환경이 그
저장소에 묶여 있어서 그렇게 된 것뿐입니다.

로컬에서는 독립 저장소로 떼어내세요:

```bash
mkdir ~/shorts-channel && cd ~/shorts-channel
cp -r /path/to/linux-surface/ai-shorts/* .
git init && git add . && git commit -m "Initial import from planning session"
```

앞으로의 작업(에셋, 대본, 생성물, 지표 로그)은 커널 저장소가 아니라 여기에
쌓는 게 맞습니다.

---

## 4. 로컬 준비물

| 도구 | 용도 | 설치 |
|---|---|---|
| **ffmpeg** | 영상 조립, 자막 번인, 트리밍 | `brew install ffmpeg` / `apt install ffmpeg` |
| **yt-dlp** | 레퍼런스 영상 받기 | `pip install yt-dlp` 또는 `brew install yt-dlp` |
| **Claude Code** | 작업 이어가기 | `npm i -g @anthropic-ai/claude-code` |
| 브라우저 | Phase 0 직접 관찰 | — |
| VPN (선택) | 미국 피드 확인 | — |

Higgsfield로 생성까지 하려면 로컬 Claude Code에 해당 MCP 서버를 연결하세요.
(워크스페이스는 free 플랜 / 크레딧 0 상태 그대로입니다.)

---

## 5. 작업 이어가기

폴더를 열고 Claude Code를 실행하면 됩니다:

```bash
cd ~/shorts-channel
claude
```

첫 마디로 이 정도만 주면 문맥이 복원됩니다:

> `PROPOSAL.md`, `research/` 두 보고서, `phase0-field-guide.md` 를 읽고
> Phase 0을 이어서 진행해줘. 게이트 0 판정이 목표야.

**이 세션의 대화 자체는 넘어가지 않습니다.** 문서에 다 적어뒀으니 문서가
인계 자료입니다.

---

## 6. 로컬에서 먼저 할 것 (우선순위)

두 조사 보고서가 각각 "확인하라"고 남긴 항목을 병합한 목록입니다.
**위 셋이 나머지 전부보다 중요합니다.**

### 최우선 — 돈 쓰기 전 반드시

1. **YouTube 비진정성 정책 페이지 직접 읽기.** 요약 말고 원문.
   `support.google.com/youtube/answer/1311392`
   *"업로더가 원저작하지 않은 자료의 낭독"* 조항이 인용 기반 지혜 포맷을
   정면으로 겨눕니다. **채널이 수익화 가능한지 자체가 여기 달렸습니다.**
2. **혜민 독자층이 지금 숏폼 어디에 있는지 확인.** "Haemin Sunim",
   "Korean Buddhism", "burnout philosophy" 검색.
   - 아무 데도 없다 → 공백 확인, 진행
   - 이미 열 개 채널이 서비스 중 → **니치 권고 전체를 재검토해야 합니다**
3. **`phase0-field-guide.md` 관찰 1~3 수행.** 특히 **훅 30~50개 받아쓰기.**

### 그다음

4. Reddit 1차 소스 — r/Stoicism, r/Buddhism, r/taoism 피로 관련 스레드
5. Google Trends 5년 곡선 — "stoicism", "burnout", "Korean Buddhism", "ikigai"
6. AI 슬롭 시청자 평가 프롬프트가 테스트를 넘어 출시됐는지
7. Galloway 33억 조회수 연구 원문 (특히 길이/AVD 결과)

### 선택 — 원본 영상 재확인

이 세션에서 두 번 분석한 원본을 직접 받아 대조할 수 있습니다:

```bash
yt-dlp -f "best[height<=720]" "https://youtube.com/shorts/6FxfsPN0uss"
```

`happiness-en/source-analysis.md` 의 *"Where the passes disagree"* 절에 두
분석이 어긋난 지점이 정리돼 있습니다. 특히 **씬 2/9 여성과 8/11 남성이 같은
사람인지** 확인하면 판정이 끝납니다.

다만 솔직히 말하면 — 니치와 포맷 방향이 크게 바뀌었으므로 **이 원본 리메이크는
더 이상 1번 영상 후보가 아닙니다.** 우선순위 낮게 두세요.

---

## 7. 파일 안내

```
ai-shorts/
├── PROPOSAL.md                     ← 채널 기획 제안서. 여기부터 읽기
├── phase0-field-guide.md           ← 직접 관찰 프로토콜 (사람만 가능)
├── LOCAL-SETUP.md                  ← 이 문서
├── research/
│   ├── niche-gap-analysis.md       ← 니치 조사. PROPOSAL의 권고를 뒤집음
│   └── stylized-format-research.md ← 포맷·스타일·훅·제작 현실 조사
└── happiness-en/                   ← 원본 리메이크 팩 (참고용, 우선순위 낮음)
    ├── README.md
    ├── source-analysis.md
    ├── script-en.md
    ├── subtitles.srt
    └── production-runbook.md
```

**읽는 순서:** `PROPOSAL.md` → `research/niche-gap-analysis.md` (제안서
2장을 뒤집으므로 반드시 함께) → `research/stylized-format-research.md` →
`phase0-field-guide.md`.

---

## 8. 인계 시점의 미결 사항

- **니치 축 미확정.** 제안서는 "동양 고전 × 영어권"을 권고했으나 조사가
  이를 **소싱 우위로 강등**하고 제4안(소진 영역 × 조용한 어조 × 출처 명시)을
  제시. **판정은 로컬 정찰 후**
- **비주얼 스타일 미확정.** 애니메이션/스타일화까지는 확정. 조사는 **수묵 또는
  목판/리놀컷**을 미개척 사분면으로 지목 — 프리미엄으로 읽히고, 일관성이
  구조적으로 싸고, 이 니치에서 비어 있음. 회화풍/지브리풍은 **AI 슬롭의 시각적
  서명이므로 회피**
- **게이트 0 미통과.** 채널 한 문장 정의가 아직 안 나옴
- **크레딧 0.** 생성 관련 결정은 전부 보류 상태
