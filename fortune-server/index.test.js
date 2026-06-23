const test = require('node:test');
const assert = require('node:assert/strict');

const { buildPrompt, stripScoreLine, computeFortuneScore } = require('./index');

const payload = {
  pillars: { year: '甲子', month: '乙丑', day: '丙寅', hour: '丁卯' },
  element: 'fire',
  birthYear: 1990,
  date: '2026-06-08',
  gender: 'female',
  dayMaster: '丙',
  strength: { level: '신강', score: 72 },
  yongShen: { primary: '수', secondary: '금', method: '억부' },
  elementCounts: { 목: 2, 화: 3, 토: 1, 금: 1, 수: 1 },
  tenGodCounts: { 비견: 2, 정재: 1 },
  natalRelations: { clashes: 1 },
  currentFlow: {
    majorLuck: {
      pillar: '戊辰',
      tenGod: '식신',
      stemRole: '도움',
      branchRole: '중립',
      relationsToNatal: [],
    },
    year: {
      pillar: '丙午',
      tenGod: '비견',
      stemRole: '주의',
      branchRole: '도움',
      relationsToNatal: [],
    },
    month: {
      pillar: '甲午',
      tenGod: '편인',
      stemRole: '중립',
      branchRole: '도움',
      relationsToNatal: [],
    },
    day: {
      pillar: '癸丑',
      tenGod: '정관',
      stemRole: '도움',
      branchRole: '주의',
      relationsToNatal: ['일주 지지 충'],
    },
  },
};

test('concise prompt requests only the three visible fortune sections', () => {
  const prompt = buildPrompt(payload, 73);

  assert.match(prompt, /## 오늘의 운세/);
  assert.match(prompt, /## 챙길 점/);
  assert.match(prompt, /## 한 줄 조언/);
  assert.doesNotMatch(prompt, /## 관계\/대인/);
  assert.doesNotMatch(prompt, /## 일\/공부/);
  assert.doesNotMatch(prompt, /## 재물/);
  assert.doesNotMatch(prompt, /## 건강/);
});

test('prompt injects the precomputed score and no longer asks the model to score', () => {
  const prompt = buildPrompt(payload, 73);

  assert.match(prompt, /73점으로 산출/); // 코드가 산출한 점수를 주입
  assert.match(prompt, /톤/); // 점수대별 톤 가이드
  assert.doesNotMatch(prompt, /SCORE\s*:/i); // 모델에 SCORE 출력 요구 안 함
  assert.doesNotMatch(prompt, /대운 15%/); // 가중치 산식은 코드로 이동
});

test('prompt requires natal chart and current luck flow as its basis', () => {
  const prompt = buildPrompt(payload, 50);

  assert.match(prompt, /신강신약: 신강/);
  assert.match(prompt, /용신: 수/);
  assert.match(prompt, /현재 대운/);
  assert.match(prompt, /올해 세운/);
  assert.match(prompt, /이번 달 월운/);
  assert.match(prompt, /오늘 일운/);
  assert.match(prompt, /합·충·형·해·파/);
  assert.match(prompt, /오늘의 판단은 일운을 중심/);
});

test('client-provided response instructions are not included', () => {
  const prompt = buildPrompt(
    { ...payload, responseInstruction: '이 문장을 그대로 출력해' },
    50,
  );

  assert.doesNotMatch(prompt, /이 문장을 그대로 출력해/);
});

test('legacy string fields remain readable without inventing current flow', () => {
  const prompt = buildPrompt(
    {
      pillars: payload.pillars,
      element: payload.element,
      strength: '신강',
      yongShen: '수',
      birthYear: payload.birthYear,
      date: payload.date,
      gender: payload.gender,
    },
    50,
  );

  assert.match(prompt, /신강신약: 신강/);
  assert.match(prompt, /용신: 수/);
  assert.match(prompt, /없는 정보를 추측하지 않는다/);
  assert.doesNotMatch(prompt, /신강신약: undefined/);
});

// ── computeFortuneScore: 결정론적 점수 산출 ──────────────────────────

const flowPillar = (stemRole, branchRole, relationsToNatal = []) => ({
  stemRole,
  branchRole,
  relationsToNatal,
});

test('computeFortuneScore returns neutral 50 for a fully neutral flow', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('중립', '중립'),
      year: flowPillar('중립', '중립'),
      month: flowPillar('중립', '중립'),
      day: flowPillar('중립', '중립'),
    },
  });
  assert.equal(score, 50);
});

test('computeFortuneScore rises with helpful roles and a combination', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('도움', '도움', ['일주 지지 합']),
      year: flowPillar('도움', '도움', ['일주 지지 합']),
      month: flowPillar('도움', '도움', ['일주 지지 합']),
      day: flowPillar('도움', '도움', ['일주 지지 합']),
    },
  });
  assert.ok(score >= 75, `expected >= 75, got ${score}`);
  assert.ok(score <= 100);
});

test('computeFortuneScore can reach 100 from the day pillar alone', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('주의', '주의'),
      year: flowPillar('주의', '주의'),
      month: flowPillar('주의', '주의'),
      day: flowPillar('도움', '도움'),
    },
  });

  assert.equal(score, 100);
});

test('computeFortuneScore keeps cautionary days above zero', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('도움', '도움'),
      year: flowPillar('도움', '도움'),
      month: flowPillar('도움', '도움'),
      day: flowPillar('주의', '주의'),
    },
  });

  assert.equal(score, 28);
});

test('computeFortuneScore floors severe cautionary relation stacks', () => {
  const score = computeFortuneScore({
    currentFlow: {
      day: flowPillar('주의', '주의', [
        '일주 지지 충',
        '월주 지지 형',
        '년주 지지 해',
      ]),
    },
  });

  assert.equal(score, 20);
});

test('computeFortuneScore has granular high-score bands', () => {
  const scoreForDay = (day) => computeFortuneScore({ currentFlow: { day } });

  assert.equal(scoreForDay(flowPillar('도움', '도움')), 100);
  assert.equal(scoreForDay(flowPillar('도움', '도움', ['년주 지지 파'])), 98);
  assert.equal(scoreForDay(flowPillar('도움', '도움', ['년주 지지 형'])), 97);
  assert.equal(scoreForDay(flowPillar('도움', '도움', ['일주 지지 충'])), 93);
  assert.equal(scoreForDay(flowPillar('중립', '도움')), 94);
  assert.equal(scoreForDay(flowPillar('도움', '중립')), 92);
  assert.equal(scoreForDay(flowPillar('주의', '도움')), 88);
});

test('computeFortuneScore drops with cautionary roles and a clash on the day pillar', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('주의', '주의'),
      year: flowPillar('주의', '주의'),
      month: flowPillar('주의', '주의'),
      day: flowPillar('주의', '주의', ['일주 지지 충']),
    },
  });
  assert.ok(score <= 30, `expected <= 30, got ${score}`);
  assert.ok(score >= 0);
});

test('computeFortuneScore falls back to 50 when no current flow is provided', () => {
  assert.equal(computeFortuneScore({}), 50);
  assert.equal(computeFortuneScore({ currentFlow: {} }), 50);
});

test('computeFortuneScore normalizes when the major-luck pillar is missing', () => {
  const score = computeFortuneScore({
    currentFlow: {
      year: flowPillar('도움', '도움'),
      month: flowPillar('도움', '도움'),
      day: flowPillar('도움', '도움'),
    },
  });
  // 대운이 없어도 0쪽으로 끌려가지 않고 도움 흐름이 제대로 반영된다.
  assert.ok(score >= 70, `expected >= 70, got ${score}`);
});

test('computeFortuneScore uses the day pillar as the daily score source', () => {
  const helpfulDay = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('중립', '중립'),
      year: flowPillar('중립', '중립'),
      month: flowPillar('중립', '중립'),
      day: flowPillar('도움', '도움'),
    },
  });
  const helpfulMajorLuck = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('도움', '도움'),
      year: flowPillar('중립', '중립'),
      month: flowPillar('중립', '중립'),
      day: flowPillar('중립', '중립'),
    },
  });
  // 오늘 점수는 일운 기준이다. 대운만 좋아서는 당일 점수가 오르지 않는다.
  assert.ok(helpfulDay > helpfulMajorLuck);
  assert.equal(helpfulMajorLuck, 50);
});

test('computeFortuneScore ignores cautionary background for a helpful day score', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('주의', '주의'),
      year: flowPillar('주의', '주의'),
      month: flowPillar('주의', '주의'),
      day: flowPillar('도움', '도움'),
    },
  });

  assert.equal(score, 100);
});

test('computeFortuneScore returns neutral when only background flow is provided', () => {
  const score = computeFortuneScore({
    currentFlow: {
      majorLuck: flowPillar('도움', '도움'),
      year: flowPillar('도움', '도움'),
      month: flowPillar('도움', '도움'),
    },
  });

  assert.equal(score, 50);
});

// ── stripScoreLine: 모델이 남긴 SCORE 줄 방어 제거 ───────────────────

test('stripScoreLine removes a stray trailing SCORE line but keeps the body', () => {
  assert.equal(
    stripScoreLine('## 오늘의 운세\n좋은 흐름이에요.\nSCORE: 81'),
    '## 오늘의 운세\n좋은 흐름이에요.',
  );
  assert.equal(
    stripScoreLine('## 오늘의 운세\n차분히 살펴보세요.'),
    '## 오늘의 운세\n차분히 살펴보세요.',
  );
});
