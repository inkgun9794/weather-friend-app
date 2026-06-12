const functions = require('@google-cloud/functions-framework');

const GEMINI_MODEL = 'gemini-2.5-flash';
const MAX_RETRIES = 3;
const PROMPT_VERSION = 'concise-weather-v5';

functions.http('fortune', async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-App-Secret');

  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');

  if (process.env.APP_SECRET) {
    const provided = req.get('X-App-Secret');
    if (provided !== process.env.APP_SECRET) {
      return res.status(401).send('Unauthorized');
    }
  }

  const body = req.body;
  if (!body || typeof body !== 'object') {
    return res.status(400).send('Bad JSON');
  }

  const score = computeFortuneScore(body);
  const prompt = buildPrompt(body, score);
  const geminiRes = await callGeminiWithRetry(prompt);

  if (!geminiRes.ok) {
    const errText = await geminiRes.text();
    return res.status(502).send(`Gemini error: ${errText}`);
  }

  const data = await geminiRes.json();
  const parts = data.candidates?.[0]?.content?.parts ?? [];
  const raw = parts
    .filter((part) => !part.thought)
    .map((part) => part.text ?? '')
    .join('');

  // 점수는 코드 산출값을 권위값으로 사용. 본문에 혹시 남은 SCORE 줄만 제거.
  const text = stripScoreLine(raw);
  console.log(
    JSON.stringify({
      event: 'fortune_generated',
      promptVersion: PROMPT_VERSION,
      score,
    }),
  );

  res.json({ text, score, promptVersion: PROMPT_VERSION });
});

async function callGeminiWithRetry(prompt) {
  let lastResponse = null;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${process.env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1024,
            thinkingConfig: { thinkingBudget: 0 },
          },
        }),
      },
    );

    if (response.ok) return response;
    lastResponse = response;
    if (response.status !== 503 || attempt === MAX_RETRIES) return response;

    await new Promise((resolve) => setTimeout(resolve, 200 * attempt));
  }

  return lastResponse;
}

function buildPrompt(body, score) {
  const age = new Date(body.date).getFullYear() - body.birthYear;
  const elementKo = {
    wood: '나무',
    fire: '불',
    earth: '흙',
    metal: '쇠',
    water: '물',
  }[body.element] || body.element;
  const strength =
    typeof body.strength === 'object'
      ? body.strength
      : { level: body.strength };
  const yongShen =
    typeof body.yongShen === 'object'
      ? body.yongShen
      : { primary: body.yongShen };
  const currentFlow = body.currentFlow ?? {};
  const hasDetailedFlow = Object.keys(currentFlow).length > 0;

  return `[역할]
너는 날씨 앱 안에서 오늘의 운세를 짧고 편안하게 알려주는 안내자다.
운세는 가볍게 참고하는 보조 콘텐츠이며 불안이나 단정을 조장하지 않는다.

[사주 원국과 명리 분석값 - 판단에 반드시 사용하고 본문에는 직접 노출하지 않는다]
- 사주 4기둥: ${body.pillars.year} ${body.pillars.month} ${body.pillars.day} ${body.pillars.hour}
- 일간: ${body.dayMaster}, 일간 오행: ${elementKo}
- 신강신약: ${strength.level}, 강약 점수: ${strength.score}
- 용신: ${yongShen.primary}, 희신: ${yongShen.secondary ?? '없음'}
- 용신 판단법: ${yongShen.method}, 조후 보정: ${yongShen.johuAdjustment ?? '없음'}
- 원국 오행 분포: ${JSON.stringify(body.elementCounts ?? {})}
- 원국 십성 분포: ${JSON.stringify(body.tenGodCounts ?? {})}
- 원국 내부 합충형해파 개수: ${JSON.stringify(body.natalRelations ?? {})}
- 나이: 약 ${age}세
- 오늘 날짜: ${body.date}
- 성별: ${body.gender === 'male' ? '남' : '여'}

[현재 운의 흐름 - 원국과 함께 판단에 반드시 사용한다]
${hasDetailedFlow
    ? `- 현재 대운: ${JSON.stringify(currentFlow.majorLuck ?? {})}
- 올해 세운: ${JSON.stringify(currentFlow.year ?? {})}
- 이번 달 월운: ${JSON.stringify(currentFlow.month ?? {})}
- 오늘 일운: ${JSON.stringify(currentFlow.day ?? {})}`
    : '- 현재 앱 버전에서는 세부 운 흐름이 제공되지 않았다. 원국·신강신약·용신과 오늘 날짜만 사용하고 없는 정보를 추측하지 않는다.'}

[내부 판단 순서 - 생각에만 사용하고 출력하지 않는다]
1. 원국의 일간, 오행 분포, 신강신약과 용신·희신으로 기본 균형을 잡는다.
2. 세부 운 흐름이 제공된 경우에만 대운을 장기 배경, 세운을 연간 방향, 월운을 당월 분위기, 일운을 오늘의 직접 자극으로 본다.
3. 각 운의 십성, 오행의 도움·주의 역할, 원국과의 합·충·형·해·파를 함께 비교한다.
4. 도움 요인과 주의 요인을 모두 반영해 오늘의 흐름과 실천 행동을 도출한다.
5. 근거 없는 일반론을 만들지 말고, 제공된 명리 분석값과 현재 운의 흐름에 근거한다.
6. 오늘의 점수는 이미 ${score}점으로 산출되어 있다(0~100, 50이 평이). 이 점수가 나타내는
   흐름과 본문의 톤·내용을 어긋나지 않게 맞춘다.
   - 70점 이상: 가볍게 긍정적이고 활기 있는 톤
   - 40~69점: 담담하고 무난한 톤
   - 40점 미만: 조심스럽고 차분히 살피는 톤

[작성 원칙]
1. 관계, 일/공부, 재물, 건강처럼 영역을 세분화하지 않는다.
2. 사주 원국, 오행, 용신, 점수 및 전문 명리 용어를 본문에 쓰지 않는다.
3. 한자, 공포를 유발하는 표현, 미래를 확정하는 표현을 쓰지 않는다.
4. "~예요", "~해보세요"처럼 친근하고 담백한 존댓말을 사용한다.
5. 같은 내용을 반복하거나 모호한 일반론으로 분량을 늘리지 않는다.
6. 아래 세 섹션 외에는 제목, 인사말, 해설을 추가하지 않는다.

[출력 형식 - 제목과 순서를 정확히 지킨다]
## 오늘의 운세
원국과 대운·세운·월운·일운을 종합한 오늘의 흐름을 2~3문장, 100자 이내로 작성한다.

## 챙길 점
오늘의 주의 요인에서 도출한 실제 행동 한 가지를 1~2문장, 60자 이내로 작성한다.

## 한 줄 조언
오늘의 균형을 돕는 조언 한 문장을 35자 이내로 작성한다.

세 섹션만 작성하고, 점수나 숫자는 본문에 쓰지 않는다.`;
}

// 점수는 computeFortuneScore가 결정한다. 모델이 혹시 마지막 줄에 SCORE를 남겨도
// 본문에서만 제거하는 방어용 헬퍼.
function stripScoreLine(raw) {
  return raw.replace(/SCORE\s*:\s*\d{1,3}\s*$/i, '').trim();
}

const FLOW_WEIGHTS = { majorLuck: 0.15, year: 0.2, month: 0.25, day: 0.4 };
const NATAL_INTENSITY = { 일주: 1.5, 월주: 1.2, 년주: 0.8, 시주: 0.8 };
const RELATION_DELTA = { 합: 0.6, 충: -0.6, 형: -0.5, 해: -0.4, 파: -0.3 };
// 분포 보정 노브 — 50k일 시뮬레이션으로 평균≈50, 5개 밴드 모두 도달하도록 맞춤.
const RELATION_SCALE = 0.15; // 관계가 역할(용신/기신)보다 과하게 점수를 흔들지 않게 축소
const SCORE_SPREAD = 40; // normalized([-1.5,1.5]) → 점수 폭. 클수록 상·하위 밴드 도달 쉬움

function roleSign(role) {
  if (role === '도움') return 1;
  if (role === '주의') return -1;
  return 0;
}

// 한 운(대운/세운/월운/일운) 기둥이 오늘 점수에 더하는 기여도. 범위 [-1.5, +1.5].
// 천간·지지가 용신·희신에 도움이면 +, 기신이면 -. 원국과의 합은 가점, 충·형·해·파는
// 어느 원국 기둥과 부딪히는지(일주가 가장 큼)에 따라 강도를 달리해 감점한다.
function flowContribution(flow) {
  if (!flow || typeof flow !== 'object') return 0;
  let c = roleSign(flow.stemRole) * 0.45 + roleSign(flow.branchRole) * 0.55;

  const relations = Array.isArray(flow.relationsToNatal)
    ? flow.relationsToNatal
    : [];
  for (const relation of relations) {
    const natal = ['일주', '월주', '년주', '시주'].find((p) =>
      relation.includes(p),
    );
    const intensity = NATAL_INTENSITY[natal] ?? 1.0;
    for (const [kind, delta] of Object.entries(RELATION_DELTA)) {
      if (relation.includes(kind)) c += delta * intensity * RELATION_SCALE;
    }
  }

  return Math.max(-1.5, Math.min(1.5, c));
}

// 원국·현재 운 흐름으로 오늘의 0~100 점수를 결정론적으로 산출한다.
// 프롬프트가 명세하던 비중(대운15/세운20/월운25/일운40)을 실제 가중합으로 적용하고,
// 존재하는 운만으로 정규화한다. 신강신약 점수는 매일 불변이라 의도적으로 쓰지 않는다.
function computeFortuneScore(body) {
  const flow = (body && body.currentFlow) || {};
  let weighted = 0;
  let totalWeight = 0;
  for (const [key, weight] of Object.entries(FLOW_WEIGHTS)) {
    if (flow[key]) {
      weighted += flowContribution(flow[key]) * weight;
      totalWeight += weight;
    }
  }
  if (totalWeight === 0) return 50; // 운 흐름 미제공(레거시) → 평이

  const normalized = weighted / totalWeight; // ≈ [-1.5, +1.5]
  return Math.max(0, Math.min(100, Math.round(50 + normalized * SCORE_SPREAD)));
}

module.exports = { buildPrompt, stripScoreLine, computeFortuneScore };
