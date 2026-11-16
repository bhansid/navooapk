import { GoogleGenAI } from "@google/genai";
import { getStore } from "@netlify/blobs";
import { COACH_SYSTEM, OUTPUT_RULES } from "./coaching-prompt.mjs";

const PREFERRED = (process.env.NAVOO_MODELS || "gemini-3.5-flash,gemini-flash-latest,gemini-3.5-flash-lite,gemini-flash-lite-latest").split(",").map((m) => m.trim());
let workingModel = null;
let discovered = null;

const CRISIS_WORDS = [
  "suicide", "suicidal", "kill myself", "end my life", "want to die", "self harm", "self-harm",
  "hurt myself", "cut myself", "no reason to live", "better off dead", "take my own life", "overdose",
];

const CRISIS_REPLY =
  "I'm really glad you told me, and I'm taking what you said seriously. This matters more than any goal right now.\n\n" +
  "Please reach out to someone now:\n" +
  "• US: call or text 988 (Suicide & Crisis Lifeline, free, 24/7), or text HOME to 741741. In an emergency, call 911.\n" +
  "• UK: call Samaritans free on 116 123 (24/7), or text SHOUT to 85258. In an emergency, call 999.\n" +
  "• Elsewhere: contact your local emergency services.\n\n" +
  "If you can, let someone close to you know how you're feeling. I'm here to keep talking with you too.";

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*", "access-control-allow-headers": "content-type" },
  });

let ai;
const client = () => (ai ??= new GoogleGenAI({}));

async function discoverModels() {
  if (discovered) return discovered;
  const names = [];
  try {
    const pager = await client().models.list();
    for await (const m of pager) {
      const n = String(m.name || "").replace(/^models\//, "");
      const actions = m.supportedActions || [];
      if (!/flash/.test(n) || /image|tts|live|audio|embedding|vision|thinking-exp/.test(n)) continue;
      if (actions.length && !actions.includes("generateContent")) continue;
      names.push(n);
    }
  } catch (e) {
    console.error("list models failed", e);
  }
  const ver = (n) => parseFloat((n.match(/gemini-(\d+(?:\.\d+)?)/) || [0, 0])[1]);
  names.sort((a, b) => ver(b) - ver(a) || (a.includes("lite") ? 1 : 0) - (b.includes("lite") ? 1 : 0) || a.length - b.length);
  discovered = names.filter((n) => !/preview|exp/.test(n)).concat(names.filter((n) => /preview|exp/.test(n)));
  return discovered;
}

async function callModel(model, system, contents, wantJson) {
  const res = await client().models.generateContent({
    model,
    contents,
    config: { systemInstruction: system, temperature: 0.7, ...(wantJson ? { responseMimeType: "application/json" } : {}) },
  });
  const text = res.text ?? "";
  if (!wantJson) return text;
  try {
    return JSON.parse(text);
  } catch {
    const m = text.match(/\{[\s\S]*\}/);
    if (m) return JSON.parse(m[0]);
    throw new Error("Model did not return JSON");
  }
}

async function generate(system, contents, wantJson = true) {
  const errors = [];
  const tried = new Set();
  const tryList = async (list) => {
    for (const model of list) {
      if (!model || tried.has(model)) continue;
      tried.add(model);
      try {
        const out = await callModel(model, system, contents, wantJson);
        workingModel = model;
        return { out };
      } catch (e) {
        errors.push(`${model}: ${String(e?.message || e).slice(0, 160)}`);
      }
    }
    return null;
  };
  let r = await tryList([workingModel, ...PREFERRED]);
  if (!r) r = await tryList((await discoverModels()).slice(0, 6));
  if (r) return r.out;
  throw new Error(errors.join(" | ").slice(0, 900));
}

// Team knowledge: the Navoo team can teach the coach new rules, examples and facts live,
// from /coach-brain.html, without an app update. Stored in Netlify Blobs; cached for 60s.
let kCache = { at: 0, text: "" };
async function teamKnowledge() {
  if (Date.now() - kCache.at < 60_000) return kCache.text;
  try {
    const v = await getStore("coach-knowledge").get("current", { type: "json" });
    kCache = { at: Date.now(), text: String(v?.text || "").slice(0, 20000) };
  } catch {
    kCache = { at: Date.now(), text: kCache.text };
  }
  return kCache.text;
}
const knowledgeBlock = (t) =>
  t ? `\n\nNAVOO TEAM UPDATES (written by the Navoo team; follow these over the general guidance above, but never over SAFETY):\n${t}\n` : "";

async function knowledgeAdmin(body) {
  const key = process.env.NAVOO_ADMIN_KEY;
  if (!key || body?.adminKey !== key) return json({ ok: false, error: "Wrong admin key" }, 403);
  const store = getStore("coach-knowledge");
  if (body.action === "set") {
    const prev = await store.get("current", { type: "json" });
    if (prev) await store.setJSON(`history/${new Date().toISOString()}`, prev);
    const rec = { text: String(body.text || "").slice(0, 20000), by: String(body.by || "").slice(0, 80), at: new Date().toISOString() };
    await store.setJSON("current", rec);
    kCache = { at: 0, text: "" };
    return json({ ok: true, saved: rec });
  }
  if (body.action === "history") {
    const { blobs } = await store.list({ prefix: "history/" });
    return json({ ok: true, versions: blobs.map((b) => b.key).sort().reverse().slice(0, 30) });
  }
  if (body.action === "feedback") {
    const fb = getStore("satisfaction");
    const { blobs } = await fb.list();
    const items = [];
    for (const b of blobs.slice(-50)) items.push(await fb.get(b.key, { type: "json" }));
    return json({ ok: true, items });
  }
  const cur = await store.get("current", { type: "json" });
  return json({ ok: true, current: cur || { text: "" } });
}

function profileBlock(profile) {
  if (!profile || typeof profile !== "object") return "No profile yet.";
  const s = JSON.stringify(profile, null, 1);
  return s.length > 6000 ? s.slice(0, 6000) : s;
}

async function flagSafety(userId, kind, text) {
  try {
    const store = getStore("safety-flags");
    const key = `${new Date().toISOString()}_${(userId || "anon").replace(/[^a-zA-Z0-9@._-]/g, "")}`;
    await store.setJSON(key, { userId, kind, text: String(text).slice(0, 1000), at: new Date().toISOString() });
    // Email alert via Netlify Forms notifications (configured to go to the Navoo safety lead).
    const site = process.env.URL || "https://navoo-coach-api.netlify.app";
    await fetch(`${site}/`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        "form-name": "safety-alert",
        user: String(userId || "unknown"),
        kind: kind === "crisis-keyword" || kind === "crisis" ? "Possible crisis / self-harm" : kind === "eating_disorder" ? "Possible eating disorder" : String(kind),
        time: new Date().toISOString(),
        message: "Details are in the Navoo safety log (not included in email to protect the user's health information).",
      }).toString(),
    });
  } catch (e) {
    console.error("flag failed", e);
  }
}

async function storeFeedback(userId, data) {
  try {
    const store = getStore("satisfaction");
    await store.setJSON(`${new Date().toISOString()}_${(userId || "anon").replace(/[^a-zA-Z0-9@._-]/g, "")}`, { userId, ...data });
  } catch (e) {
    console.error("feedback failed", e);
  }
}

// Structured helpers used by onboarding, weekly review and home.
const TASKS = {
  vision: (d) => `From the user's answers below, write their Wider Vision in their own words.
Return JSON {"headline": "max 8 words, e.g. 'A healthier, more confident and energetic you.'", "body": "2-3 sentences in second person using their words", "feelings": ["3 single words"], "identity": "short phrase, e.g. 'Someone who takes care of their health.'"}.
Answers: ${JSON.stringify(d)}`,
  focus_options: (d) => `Suggest exactly 3 different 30-Day Focus options for this user.
RULES (all must hold):
1. Every option DIRECTLY serves the main outcome in the user's Vision and wish. For a weight-loss Vision, every option must be something that clearly drives weight loss (eating, snacking, portions, movement). Never offer a loosely related area (e.g. sleep, morning stretches, hydration) unless the user named it.
2. All 3 options are at the SAME broad level: a behaviour area, not a tactic. Good: "Eat healthier weekday meals", "Improve my snacking habits", "Move more during the week". Bad (mixed levels): "Evening weekday meals" next to "Protein snacks for busy afternoons". Specific tactics only come later, once the user names that moment as the barrier.
3. First person, as the user would say it, max 8 words. Never say "plan".
4. If "already_shown" options are given, suggest 3 NEW ones that follow the same rules; never repeat or reword them.
Return JSON {"options": [{"title": "...", "why": "one short sentence linking it to their Vision"}]}.
User data: ${JSON.stringify(d)}`,

  categorise_obstacles: (d) => `Sort what the user said gets in their way into logistical and psychological friction, and write a short summary line.
Return JSON {"logistical": ["short items"], "psychological": ["short items"], "summary": "max 10 words, e.g. 'Evening exhaustion and lack of preparation.'"}.
User said: ${JSON.stringify(d)}`,
  actions: (d) => `Suggest Micro-Actions for the user's 30-Day Focus (default 3, or "how_many" if given).
RULES (all must hold):
1. They BUILD ON EACH OTHER: each one uses the result of the one before. Good: "Find 2 rapid healthy meals" -> "Buy the ingredients for your 2 rapid meals" -> "Cook one of your rapid meals on Tuesday". Bad: "List 2 rapid meal options" -> "Grab staples in next shop" -> "Make your lighter dinner" (not connected).
2. The first is the easiest. Each is concrete and doable in 5-20 minutes. Titles max 7 words, in plain English.
3. Every one clearly serves the 30-Day Focus and the Vision, and works around the stated obstacles.
4. NEVER repeat or reword anything in "all_previous_micro_actions" or "rejected_suggestions". If "fixed_first_micro_actions" are given, continue directly from the last one.
5. Never use the word "plan".
Return JSON {"actions": [{"title": "...", "description": "one short line", "why": "one sentence on why this helps this user", "minutes": number}]}.
User data: ${JSON.stringify(d)}`,

  acknowledge: (d) => `During set-up the user just answered a question. Write ONE short sentence (max 18 words) that reflects back what they said, using their words, so they feel heard. Warm and natural, no hype ("amazing", "great insight"), no question, no advice, don't move the conversation on. If the answer touches something sensitive (e.g. wanting to be thinner), acknowledge it kindly and neutrally.
Return JSON {"line": "..."}.
Question: ${d.question}
Answer: ${d.answer}`,
  brain_cheat_codes: (d) => `Create ideas for the user's Brain Cheat Codes for ONE Micro-Action. The user will draft their own; these are examples they can tap and edit.
FORMAT for every If/Then: "if" is the moment written as "I have finished eating my lunch" (starts with "I", no "if"/"when" word); "then" starts with "I will" (no "then" word). Max 14 words each.
1. moment_ideas: 3 that link the Micro-Action to a moment that already happens in their day, fitting their routine and timing.
2. slip_up_ideas: 3 that plan for a motivation drop or the user's own barrier (use their obstacles), e.g. {"if": "I am too tired to cook when I get home", "then": "I will have the easy back-up from the freezer, not a takeaway"} or {"if": "I am too tired when lunch hits", "then": "I will remind myself of my Vision"}.
3. nudge_ideas: 3 short Physical Nudges (Environment Design): a change to their surroundings that makes the action easy and visible, e.g. "Leave the ingredients on the worktop before work". Max 12 words.
4. reward_suggestion: the item from rewards_menu that best suits this Micro-Action's time of day (or "" if none).
Never use the word "plan".
Return JSON {"moment_ideas": [{"if": "...", "then": "..."}], "slip_up_ideas": [{"if": "...", "then": "..."}], "nudge_ideas": ["..."], "reward_suggestion": "..."}.
Data: ${JSON.stringify(d)}`,
  insights: (d) => `The user just completed a Micro-Action. From this and their profile, write 0-2 NEW short insights about what helps them, in the user's own first-person voice (e.g. "Mornings are when I follow through best", "Leaving ingredients out made cooking easier"). Only include something genuinely supported by the data; skip anything already in learned_about_user. Never "User is...".
Return JSON {"insights": ["..."]}.
Data: ${JSON.stringify(d)}`,
  describe_micro_action: (d) => `The user rewrote a Micro-Action in their own words. Keep their title exactly as written. Write a matching one-line description and a one-sentence "why" that links it to their 30-Day Focus and Vision, and estimate minutes.
Return JSON {"description": "one short line", "why": "one sentence", "minutes": number}.
Data: ${JSON.stringify(d)}`,
  adapt: (d) => `The user tapped "I'm nailing it, make it harder" for their current Micro-Action. Acknowledge it in one short, proportionate sentence, then suggest ONE slightly harder next version that builds directly on it (a small step up, not a leap), still linked to the 30-Day Focus and Vision, never repeating anything in all_previous_micro_actions.
Return JSON {"message": "one or two short sentences to the user", "title": "max 7 words", "description": "one short line", "why": "one sentence", "minutes": number}.
Data: ${JSON.stringify(d)}`,
  improve_ifthen: (d) => `The user drafted an If/Then plan themselves. Keep their words and idea; only tighten it so the IF is a clear cue and the THEN a small, specific action. If it's already good, keep it. Also suggest one environment/setup idea if they gave none.
Return JSON {"if": "...", "then": "...", "backup_if": "...", "backup_then": "...", "setup": "...", "comment": "one short, calm sentence to the user (no hype)"}.
Draft: ${JSON.stringify(d)}`,
  ifthen_suggestions: (d) => `Suggest 3 short, personal If/Then options for the user's action, built from what you know about their routine, energy and obstacles. IF = a moment that already happens in their day (no "if" word). THEN = the small action, starting "I'll" (no "then" word). Max 12 words each. Realistic and kind; avoid times they find hard.
Return JSON {"suggestions": [{"if": "...", "then": "..."}]}.
Data: ${JSON.stringify(d)}`,
  weekly_review: (d) => `Run the end-of-week check-in AFTER the user has answered what went well and what got in the way. Never frame slip-ups as failure and don't over-celebrate them as success; treat them as useful information. Keep the same goal; change the approach. Never use the word "plan".
NEXT MICRO-ACTIONS RULES: exactly 3; they build on what the user has already completed and on each other; each links to the Vision and 30-Day Focus; they address what got in the way; NEVER repeat or reword anything in "all_previous_micro_actions" or "rejected_suggestions" unless the user explicitly asked to repeat it.
Return JSON {"went_well": [{"title": "short", "detail": "one line"}], "noticed": ["1-2 factual observations from the data"], "learned": ["1-3 short learnings in the user's own first-person voice, e.g. 'Cooking from scratch is too much on stressful evenings'"], "factors": ["from: Energy, Time, Environment, Emotional trigger, Preparation, Motivation"], "headline_learning": "one sentence", "next_actions": [{"title": "max 7 words", "description": "one line", "why": "one sentence", "minutes": number}]}.
Week data: ${JSON.stringify(d)}`,

  daily_tip: (d) => `Write today's short coach message for the Home screen: either one reflective question or one practical tip tied to their current action and what you know about them. Max 25 words. Calm, specific, no hype, no "you've got this".
Return JSON {"type": "question" | "tip", "text": "..."}.
User data: ${JSON.stringify(d)}`,
  nudges: (d) => `Write 4 short phone notification nudges (max 14 words each) for the user's current action, one of each type: "own_words" (play back their IF/THEN in their words), "identity", "meta" (a quick self-check question), "friction" (how small the step is). Calm, never bootcamp, never guilt.
Return JSON {"nudges": [{"type": "...", "text": "..."}]}.
User data: ${JSON.stringify(d)}`,
  completion: (d) => `The user has finished a 30-day focus. Write a short, proportionate reflection and suggest 3 options for the next 30-Day Focus under the same Vision.
Return JSON {"summary": "2 sentences on what they did and what helped", "options": [{"title": "...", "why": "..."}]}.
Data: ${JSON.stringify(d)}`,
};

export default async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method === "GET") return json({ ok: true, service: "navoo-coach", model: workingModel, models: new URL(req.url).searchParams.has("models") ? await discoverModels() : undefined });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let body;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad JSON" }, 400);
  }
  const { mode = "chat", userId = "anon", profile = {}, messages = [], task, data } = body || {};

  try {
    if (mode === "feedback") {
      await storeFeedback(userId, data || {});
      return json({ ok: true });
    }

    if (mode === "knowledge") return await knowledgeAdmin(body);

    const team = knowledgeBlock(await teamKnowledge());

    if (mode === "task") {
      const make = TASKS[task];
      if (!make) return json({ error: "Unknown task" }, 400);
      const out = await generate(
        COACH_SYSTEM + team + "\n\nYou are now producing structured content for the app, not chatting. Follow every tone and safety rule.\nUser profile:\n" + profileBlock(profile),
        [{ role: "user", parts: [{ text: make(data ?? {}) }] }],
      );
      return json({ ok: true, result: out });
    }

    // chat
    const trimmed = (Array.isArray(messages) ? messages : []).slice(-24).map((m) => ({
      role: m.role === "assistant" || m.role === "model" ? "model" : "user",
      parts: [{ text: String(m.text ?? m.content ?? "").slice(0, 4000) }],
    })).filter((m) => m.parts[0].text);
    if (!trimmed.length || trimmed[trimmed.length - 1].role !== "user") return json({ error: "Last message must be from the user" }, 400);

    const lastText = trimmed[trimmed.length - 1].parts[0].text.toLowerCase();
    if (CRISIS_WORDS.some((w) => lastText.includes(w))) {
      await flagSafety(userId, "crisis-keyword", lastText);
      return json({ ok: true, reply: CRISIS_REPLY, safety: "crisis", out_of_scope: false, learnings: [] });
    }

    const system = `${COACH_SYSTEM}${team}\n\nWHAT YOU KNOW ABOUT THIS USER (use it, don't make them repeat themselves):\n${profileBlock(profile)}\n${OUTPUT_RULES}`;
    const out = await generate(system, trimmed);
    const safety = ["medical", "eating_disorder", "crisis"].includes(out.safety) ? out.safety : "none";
    if (safety === "crisis" || safety === "eating_disorder") await flagSafety(userId, safety, lastText);
    return json({
      ok: true,
      reply: safety === "crisis" ? CRISIS_REPLY : String(out.reply || "").trim(),
      safety,
      out_of_scope: Boolean(out.out_of_scope),
      learnings: Array.isArray(out.learnings) ? out.learnings.slice(0, 3).map(String) : [],
    });
  } catch (e) {
    console.error(e);
    return json({ ok: false, error: "The coach is unavailable right now. Please try again in a moment.", detail: String(e?.message || e).slice(0, 400) }, 503);
  }
};

export const config = { path: "/api/coach" };
