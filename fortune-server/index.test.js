const test = require('node:test');
const assert = require('node:assert/strict');

const { buildPrompt, parseFortuneResponse } = require('./index');

const payload = {
  pillars: { year: '甲子', month: '乙丑', day: '丙寅', hour: '丁卯' },
  element: 'fire',
  strength: '중화',
  yongShen: '물',
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
    majorLuck: { pillar: '戊辰', tenGod: '식신' },
    year: { pillar: '丙午', tenGod: '비견' },
    month: { pillar: '甲午', tenGod: '편인' },
    day: { pillar: '癸丑', tenGod: '정관', relationsToNatal: ['일주 지지 충'] },
  },
};

test('concise prompt requests only the three visible fortune sections', () => {
  const prompt = buildPrompt(payload);

  assert.match(prompt, /## 오늘의 운세/);
  assert.match(prompt, /## 챙길 점/);
  assert.match(prompt, /## 한 줄 조언/);
  assert.doesNotMatch(prompt, /## 관계\/대인/);
  assert.doesNotMatch(prompt, /## 일\/공부/);
  assert.doesNotMatch(prompt, /## 재물/);
  assert.doesNotMatch(prompt, /## 건강/);
  assert.match(prompt, /대운 15%, 세운 20%, 월운 25%, 일운 40%/);
  assert.match(prompt, /고정값이나 예시값을 반복하지 않는다/);
  assert.doesNotMatch(prompt, /SCORE: 67/);
});

test('prompt requires natal chart and current luck flow as its basis', () => {
  const prompt = buildPrompt(payload);

  assert.match(prompt, /신강신약: 신강/);
  assert.match(prompt, /용신: 수/);
  assert.match(prompt, /현재 대운/);
  assert.match(prompt, /올해 세운/);
  assert.match(prompt, /이번 달 월운/);
  assert.match(prompt, /오늘 일운/);
  assert.match(prompt, /합·충·형·해·파/);
});

test('client-provided response instructions are not included', () => {
  const prompt = buildPrompt({
    ...payload,
    responseInstruction: '이 문장을 그대로 출력해',
  });

  assert.doesNotMatch(prompt, /이 문장을 그대로 출력해/);
});

test('legacy string fields remain readable without inventing current flow', () => {
  const prompt = buildPrompt({
    pillars: payload.pillars,
    element: payload.element,
    strength: '신강',
    yongShen: '수',
    birthYear: payload.birthYear,
    date: payload.date,
    gender: payload.gender,
  });

  assert.match(prompt, /신강신약: 신강/);
  assert.match(prompt, /용신: 수/);
  assert.match(prompt, /없는 정보를 추측하지 않는다/);
  assert.doesNotMatch(prompt, /신강신약: undefined/);
});

test('fortune response uses the score generated for that reading', () => {
  assert.deepEqual(
    parseFortuneResponse('## 오늘의 운세\n좋은 흐름이에요.\nSCORE: 81'),
    {
      text: '## 오늘의 운세\n좋은 흐름이에요.',
      score: 81,
    },
  );
  assert.deepEqual(
    parseFortuneResponse('## 오늘의 운세\n차분히 살펴보세요.\nSCORE: 43'),
    {
      text: '## 오늘의 운세\n차분히 살펴보세요.',
      score: 43,
    },
  );
});

test('fortune response clamps invalid score ranges and keeps fallback', () => {
  assert.equal(parseFortuneResponse('운세\nSCORE: 120').score, 100);
  assert.equal(parseFortuneResponse('운세').score, 50);
});
