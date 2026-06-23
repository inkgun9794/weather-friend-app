const functions = require('@google-cloud/functions-framework');

const GEMINI_MODEL = 'gemini-2.5-flash';
const MAX_RETRIES = 3;
const PROMPT_VERSION = 'concise-weather-v10';

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
2. 세부 운 흐름이 제공된 경우에도 오늘의 판단은 일운을 중심으로 보고, 대운·세운·월운은 장기/연간/월간 배경으로만 참고한다.
3. 각 운의 십성, 오행의 도움·주의 역할, 원국과의 합·충·형·해·파를 함께 비교한다.
4. 도움 요인과 주의 요인을 모두 반영해 오늘의 흐름과 실천 행동을 도출한다.
5. 근거 없는 일반론을 만들지 말고, 제공된 명리 분석값과 현재 운의 흐름에 근거한다.
6. 오늘의 점수는 이미 ${score}점으로 산출되어 있다(20~100, 50이 평이). 이 점수가 나타내는
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
일운을 중심으로 오늘의 흐름을 2~3문장, 100자 이내로 작성한다. 대운·세운·월운은 필요할 때만 배경으로 참고한다.

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

const NATAL_INTENSITY = { 일주: 1.5, 월주: 1.2, 년주: 0.8, 시주: 0.8 };
const RELATION_DELTA = { 합: 0.6, 충: -0.6, 형: -0.5, 해: -0.4, 파: -0.3 };
const RELATION_SCORE_SCALE = 8;
const MIN_DAILY_SCORE = 20;
const ROLE_PAIR_BASE_SCORE = {
  '도움|도움': 100,
  '중립|도움': 94,
  '도움|중립': 92,
  '주의|도움': 88,
  '도움|주의': 82,
  '중립|중립': 50,
  '주의|중립': 42,
  '중립|주의': 40,
  '주의|주의': 28,
};

function normalizedRole(role) {
  return role === '도움' || role === '주의' ? role : '중립';
}

function relationScoreDelta(flow) {
  const relations = Array.isArray(flow.relationsToNatal)
    ? flow.relationsToNatal
    : [];
  let deltaScore = 0;
  for (const relation of relations) {
    const natal = ['일주', '월주', '년주', '시주'].find((p) =>
      relation.includes(p),
    );
    const intensity = NATAL_INTENSITY[natal] ?? 1.0;
    for (const [kind, delta] of Object.entries(RELATION_DELTA)) {
      if (relation.includes(kind)) {
        deltaScore += delta * intensity * RELATION_SCORE_SCALE;
      }
    }
  }
  return deltaScore;
}

function clampScore(score) {
  return Math.max(MIN_DAILY_SCORE, Math.min(100, Math.round(score)));
}

function dailyScore(flow) {
  if (!flow || typeof flow !== 'object') return 50;
  const stemRole = normalizedRole(flow.stemRole);
  const branchRole = normalizedRole(flow.branchRole);
  const base = ROLE_PAIR_BASE_SCORE[`${stemRole}|${branchRole}`];
  return clampScore(base + relationScoreDelta(flow));
}

// 오늘의 20~100 점수를 결정론적으로 산출한다.
// "오늘" 점수이므로 일운만 사용한다. 대운·세운·월운은 본문 생성용 배경으로만 전달한다.
// 신강신약 점수는 매일 불변이라 의도적으로 쓰지 않는다.
function computeFortuneScore(body) {
  const flow = (body && body.currentFlow) || {};
  if (!flow.day) return 50; // 일운 미제공(레거시) → 평이

  return dailyScore(flow.day);
}

module.exports = { buildPrompt, stripScoreLine, computeFortuneScore };
