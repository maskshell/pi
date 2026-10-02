import { afterEach, describe, expect, it } from "vitest";
import { getModel } from "../src/compat.ts";
import { findEnvKeys, getEnvApiKey } from "../src/env-api-keys.ts";
import { MODELS } from "../src/models.generated.ts";

const originalTogetherApiKey = process.env.TOGETHER_API_KEY;

afterEach(() => {
	if (originalTogetherApiKey === undefined) {
		delete process.env.TOGETHER_API_KEY;
	} else {
		process.env.TOGETHER_API_KEY = originalTogetherApiKey;
	}
});

describe("Together models", () => {
	it("registers the default Kimi K3 model via OpenAI-compatible Chat Completions API", () => {
		const model = getModel("together", "moonshotai/Kimi-K3");

		expect(model).toBeDefined();
		expect(model.api).toBe("openai-completions");
		expect(model.provider).toBe("together");
		expect(model.baseUrl).toBe("https://api.together.ai/v1");
		expect(model.reasoning).toBe(true);
		expect(model.thinkingLevelMap).toEqual({ minimal: null, low: null, medium: null });
		expect(model.input).toEqual(["text", "image"]);
		expect(model.contextWindow).toBe(1048576);
		expect(model.maxTokens).toBe(131072);
		expect(model.cost).toEqual({
			input: 3,
			output: 15,
			cacheRead: 0.3,
			cacheWrite: 0,
		});
		expect(model.compat).toEqual({
			supportsStore: false,
			supportsDeveloperRole: false,
			supportsReasoningEffort: false,
			maxTokensField: "max_tokens",
			thinkingFormat: "together",
			supportsStrictMode: false,
			supportsLongCacheRetention: false,
		});
	});

	it("models Together reasoning controls from the Together API surface", () => {
		// The Together catalog churns with upstream releases (models.dev is fetched at
		// build time), so sample each request-shaping tier dynamically instead of
		// pinning model IDs. The tiers map to the reasoning branches in
		// src/api/openai-completions.ts: OpenAI-style reasoning_effort, the
		// Together-native reasoning toggle, and reasoning without controllable effort.
		const chatModels = Object.values(MODELS.together);

		// OpenAI-style effort: reasoning_effort carries a mapped thinking level.
		const openaiEffort = chatModels.find(
			(m) => m.reasoning && m.compat?.thinkingFormat === "openai" && m.compat.supportsReasoningEffort === true,
		);
		expect(openaiEffort, "Together catalog has an OpenAI-effort reasoning model").toBeDefined();

		// Together-native toggle: reasoning is enabled as a boolean, without effort passthrough.
		const togetherReasoning = chatModels.find((m) => m.reasoning && m.compat?.thinkingFormat === "together");
		expect(togetherReasoning, "Together catalog has a together-format reasoning model").toBeDefined();

		// Reasoning without controllable effort: no reasoning parameters are sent.
		const uncontrolled = chatModels.find(
			(m) => m.reasoning && !m.compat?.thinkingFormat && m.compat?.supportsReasoningEffort !== true,
		);
		expect(uncontrolled, "Together catalog has a reasoning model without effort controls").toBeDefined();

		for (const model of [openaiEffort, togetherReasoning, uncontrolled]) {
			const resolved = getModel("together", model!.id);
			expect(resolved, `getModel resolves ${model!.id}`).toBeDefined();
			expect(resolved.reasoning).toBe(true);
			expect(resolved.compat?.thinkingFormat).toBe(model!.compat?.thinkingFormat);
			expect(resolved.compat?.supportsReasoningEffort).toBe(model!.compat?.supportsReasoningEffort);
		}
	});

	it("resolves TOGETHER_API_KEY from the environment", () => {
		process.env.TOGETHER_API_KEY = "test-together-key";

		expect(findEnvKeys("together")).toEqual(["TOGETHER_API_KEY"]);
		expect(getEnvApiKey("together")).toBe("test-together-key");
	});
});
