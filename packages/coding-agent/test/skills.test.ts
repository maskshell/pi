import { homedir } from "os";
import { join, resolve } from "path";
import { describe, expect, it } from "vitest";
import type { ResourceDiagnostic } from "../src/core/diagnostics.ts";
import {
	findSkillByInvocationName,
	formatSkillsForPrompt,
	loadSkills,
	loadSkillsFromDir,
	resolveBareNamespaceSkill,
	type Skill,
	validateNamespaceValue,
} from "../src/core/skills.ts";
import { createSyntheticSourceInfo } from "../src/core/source-info.ts";

const fixturesDir = resolve(__dirname, "fixtures/skills");
const collisionFixturesDir = resolve(__dirname, "fixtures/skills-collision");
const nsPackageDir = join(fixturesDir, "ns-package");
const nsUserDir = join(fixturesDir, "ns-user-dir");

function createTestSkill(options: {
	name: string;
	description: string;
	filePath: string;
	baseDir: string;
	disableModelInvocation?: boolean;
	source?: string;
}): Skill {
	return {
		name: options.name,
		description: options.description,
		filePath: options.filePath,
		baseDir: options.baseDir,
		sourceInfo: createSyntheticSourceInfo(options.filePath, { source: options.source ?? "test" }),
		disableModelInvocation: options.disableModelInvocation ?? false,
	};
}

describe("skills", () => {
	describe("loadSkillsFromDir", () => {
		it("should load a valid skill", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "valid-skill"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("valid-skill");
			expect(skills[0].description).toBe("A valid skill for testing purposes.");
			expect(skills[0].sourceInfo.source).toBe("test");
			expect(diagnostics).toHaveLength(0);
		});

		it("should allow names that don't match parent directory", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "name-mismatch"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("different-name");
			expect(
				diagnostics.some((d: ResourceDiagnostic) => d.message.includes("does not match parent directory")),
			).toBe(false);
		});

		it("should warn when name contains invalid characters", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "invalid-name-chars"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("invalid characters"))).toBe(true);
		});

		it("should warn when name exceeds 64 characters", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "long-name"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("exceeds 64 characters"))).toBe(true);
		});

		it("should warn and skip skill when description is missing", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "missing-description"),
				source: "test",
			});

			expect(skills).toHaveLength(0);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("description is required"))).toBe(true);
		});

		it("should ignore unknown frontmatter fields", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "unknown-field"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(diagnostics).toHaveLength(0);
		});

		it("should load nested skills recursively", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "nested"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("child-skill");
			expect(diagnostics).toHaveLength(0);
		});

		it("should prefer a directory's root SKILL.md over nested SKILL.md files", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "root-skill-preferred"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("root-skill-preferred");
			expect(skills[0].description).toBe("Root skill should win.");
			expect(diagnostics).toHaveLength(0);
		});

		it("should skip files without frontmatter", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "no-frontmatter"),
				source: "test",
			});

			// no-frontmatter has no description, so it should be skipped
			expect(skills).toHaveLength(0);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("description is required"))).toBe(true);
		});

		it("should warn and skip skill when YAML frontmatter is invalid", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "invalid-yaml"),
				source: "test",
			});

			expect(skills).toHaveLength(0);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("at line"))).toBe(true);
		});

		it("should preserve multiline descriptions from YAML", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "multiline-description"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].description).toContain("\n");
			expect(skills[0].description).toContain("This is a multiline description.");
			expect(diagnostics).toHaveLength(0);
		});

		it("should warn when name contains consecutive hyphens", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "consecutive-hyphens"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("consecutive hyphens"))).toBe(true);
		});

		it("should load all skills from fixture directory", () => {
			const { skills } = loadSkillsFromDir({
				dir: fixturesDir,
				source: "test",
			});

			// Should load all skills that have descriptions (even with warnings)
			// valid-skill, name-mismatch, invalid-name-chars, long-name, unknown-field, nested/child-skill, consecutive-hyphens
			// NOT: missing-description, no-frontmatter (both missing descriptions)
			expect(skills.length).toBeGreaterThanOrEqual(6);
		});

		it("should return empty for non-existent directory", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: "/non/existent/path",
				source: "test",
			});

			expect(skills).toHaveLength(0);
			expect(diagnostics).toHaveLength(0);
		});

		it("should use parent directory name when name not in frontmatter", () => {
			// The no-frontmatter fixture has no name in frontmatter, so it should use "no-frontmatter"
			// But it also has no description, so it won't load
			// Let's test with a valid skill that relies on directory name
			const { skills } = loadSkillsFromDir({
				dir: join(fixturesDir, "valid-skill"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("valid-skill");
		});

		it("should parse disable-model-invocation frontmatter field", () => {
			const { skills, diagnostics } = loadSkillsFromDir({
				dir: join(fixturesDir, "disable-model-invocation"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].name).toBe("disable-model-invocation");
			expect(skills[0].disableModelInvocation).toBe(true);
			// Should not warn about unknown field
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("unknown frontmatter field"))).toBe(
				false,
			);
		});

		it("should default disableModelInvocation to false when not specified", () => {
			const { skills } = loadSkillsFromDir({
				dir: join(fixturesDir, "valid-skill"),
				source: "test",
			});

			expect(skills).toHaveLength(1);
			expect(skills[0].disableModelInvocation).toBe(false);
		});
	});

	describe("formatSkillsForPrompt", () => {
		it("should return empty string for no skills", () => {
			const result = formatSkillsForPrompt([]);
			expect(result).toBe("");
		});

		it("should format skills as XML", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "test-skill",
					description: "A test skill.",
					filePath: "/path/to/skill/SKILL.md",
					baseDir: "/path/to/skill",
				}),
			];

			const result = formatSkillsForPrompt(skills);

			expect(result).toContain("<available_skills>");
			expect(result).toContain("</available_skills>");
			expect(result).toContain("<skill>");
			expect(result).toContain("<name>test-skill</name>");
			expect(result).toContain("<description>A test skill.</description>");
			expect(result).toContain("<location>/path/to/skill/SKILL.md</location>");
		});

		it("should include intro text before XML", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "test-skill",
					description: "A test skill.",
					filePath: "/path/to/skill/SKILL.md",
					baseDir: "/path/to/skill",
				}),
			];

			const result = formatSkillsForPrompt(skills);
			const xmlStart = result.indexOf("<available_skills>");
			const introText = result.substring(0, xmlStart);

			expect(introText).toContain("The following skills provide specialized instructions");
			expect(introText).toContain("Use the read tool to load a skill's file");
		});

		it("should escape XML special characters", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "test-skill",
					description: 'A skill with <special> & "characters".',
					filePath: "/path/to/skill/SKILL.md",
					baseDir: "/path/to/skill",
				}),
			];

			const result = formatSkillsForPrompt(skills);

			expect(result).toContain("&lt;special&gt;");
			expect(result).toContain("&amp;");
			expect(result).toContain("&quot;characters&quot;");
		});

		it("should format multiple skills", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "skill-one",
					description: "First skill.",
					filePath: "/path/one/SKILL.md",
					baseDir: "/path/one",
				}),
				createTestSkill({
					name: "skill-two",
					description: "Second skill.",
					filePath: "/path/two/SKILL.md",
					baseDir: "/path/two",
				}),
			];

			const result = formatSkillsForPrompt(skills);

			expect(result).toContain("<name>skill-one</name>");
			expect(result).toContain("<name>skill-two</name>");
			expect((result.match(/<skill>/g) || []).length).toBe(2);
		});

		it("should exclude skills with disableModelInvocation from prompt", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "visible-skill",
					description: "A visible skill.",
					filePath: "/path/visible/SKILL.md",
					baseDir: "/path/visible",
				}),
				createTestSkill({
					name: "hidden-skill",
					description: "A hidden skill.",
					filePath: "/path/hidden/SKILL.md",
					baseDir: "/path/hidden",
					disableModelInvocation: true,
				}),
			];

			const result = formatSkillsForPrompt(skills);

			expect(result).toContain("<name>visible-skill</name>");
			expect(result).not.toContain("<name>hidden-skill</name>");
			expect((result.match(/<skill>/g) || []).length).toBe(1);
		});

		it("should return empty string when all skills have disableModelInvocation", () => {
			const skills: Skill[] = [
				createTestSkill({
					name: "hidden-skill",
					description: "A hidden skill.",
					filePath: "/path/hidden/SKILL.md",
					baseDir: "/path/hidden",
					disableModelInvocation: true,
				}),
			];

			const result = formatSkillsForPrompt(skills);
			expect(result).toBe("");
		});
	});

	describe("loadSkills with options", () => {
		const emptyAgentDir = resolve(__dirname, "fixtures/empty-agent");
		const emptyCwd = resolve(__dirname, "fixtures/empty-cwd");

		it("should load from explicit skillPaths", () => {
			const { skills, diagnostics } = loadSkills({
				agentDir: emptyAgentDir,
				cwd: emptyCwd,
				skillPaths: [join(fixturesDir, "valid-skill")],
				includeDefaults: true,
			});
			expect(skills).toHaveLength(1);
			expect(skills[0].sourceInfo.scope).toBe("temporary");
			expect(diagnostics).toHaveLength(0);
		});

		it("should warn when skill path does not exist", () => {
			const { skills, diagnostics } = loadSkills({
				agentDir: emptyAgentDir,
				cwd: emptyCwd,
				skillPaths: ["/non/existent/path"],
				includeDefaults: true,
			});
			expect(skills).toHaveLength(0);
			expect(diagnostics.some((d: ResourceDiagnostic) => d.message.includes("does not exist"))).toBe(true);
		});

		it("should expand ~ in skillPaths", () => {
			const homeSkillsDir = join(homedir(), ".pi/agent/skills");
			const { skills: withTilde } = loadSkills({
				agentDir: emptyAgentDir,
				cwd: emptyCwd,
				skillPaths: ["~/.pi/agent/skills"],
				includeDefaults: true,
			});
			const { skills: withoutTilde } = loadSkills({
				agentDir: emptyAgentDir,
				cwd: emptyCwd,
				skillPaths: [homeSkillsDir],
				includeDefaults: true,
			});
			expect(withTilde.length).toBe(withoutTilde.length);
		});
	});

	describe("collision handling", () => {
		it("should detect name collisions and keep first skill", () => {
			// Load from first directory
			const first = loadSkillsFromDir({
				dir: join(collisionFixturesDir, "first"),
				source: "first",
			});

			const second = loadSkillsFromDir({
				dir: join(collisionFixturesDir, "second"),
				source: "second",
			});

			// Simulate the collision behavior from loadSkills()
			const skillMap = new Map<string, Skill>();
			const collisionWarnings: Array<{ skillPath: string; message: string }> = [];

			for (const skill of first.skills) {
				skillMap.set(skill.name, skill);
			}

			for (const skill of second.skills) {
				const existing = skillMap.get(skill.name);
				if (existing) {
					collisionWarnings.push({
						skillPath: skill.filePath,
						message: `name collision: "${skill.name}" already loaded from ${existing.filePath}`,
					});
				} else {
					skillMap.set(skill.name, skill);
				}
			}

			expect(skillMap.size).toBe(1);
			expect(skillMap.get("calendar")?.sourceInfo.source).toBe("first");
			expect(collisionWarnings).toHaveLength(1);
			expect(collisionWarnings[0].message).toContain("name collision");
		});
	});
});

describe("package namespaces", () => {
	it("should rename skills under an associated path to ns:name", () => {
		const { skills, diagnostics } = loadSkills({
			cwd: fixturesDir,
			agentDir: fixturesDir,
			skillPaths: [join(nsPackageDir, "ns-one")],
			includeDefaults: false,
			namespaces: [{ path: join(nsPackageDir, "ns-one"), namespace: "solidforge" }],
		});

		expect(skills).toHaveLength(1);
		expect(skills[0].name).toBe("solidforge:cross-source-review");
		expect(skills[0].namespace).toBe("solidforge");
		expect(skills[0].baseName).toBe("cross-source-review");
		expect(diagnostics).toHaveLength(0);
	});

	it("should associate by parent dir of a SKILL.md path", () => {
		const { skills } = loadSkills({
			cwd: fixturesDir,
			agentDir: fixturesDir,
			skillPaths: [join(nsPackageDir, "ns-one", "SKILL.md")],
			includeDefaults: false,
			namespaces: [{ path: join(nsPackageDir, "ns-one"), namespace: "solidforge" }],
		});

		expect(skills[0].name).toBe("solidforge:cross-source-review");
	});

	it("should let a namespaced skill coexist with a same-named bare user skill", () => {
		const { skills, diagnostics } = loadSkills({
			cwd: fixturesDir,
			agentDir: fixturesDir,
			skillPaths: [nsUserDir, join(nsPackageDir, "ns-one")],
			includeDefaults: false,
			namespaces: [{ path: join(nsPackageDir, "ns-one"), namespace: "solidforge" }],
		});

		const names = skills.map((s) => s.name).sort();
		expect(names).toEqual(["cross-source-review", "solidforge:cross-source-review"]);
		expect(diagnostics.filter((d: ResourceDiagnostic) => d.type === "collision")).toHaveLength(0);
	});

	it("should report a collision on the composed name for two same-ns same-base skills", () => {
		const { skills, diagnostics } = loadSkills({
			cwd: fixturesDir,
			agentDir: fixturesDir,
			skillPaths: [join(nsPackageDir, "ns-one"), join(nsPackageDir, "ns-two-dup")],
			includeDefaults: false,
			namespaces: [
				{ path: join(nsPackageDir, "ns-one"), namespace: "solidforge" },
				{ path: join(nsPackageDir, "ns-two-dup"), namespace: "solidforge" },
			],
		});

		expect(skills.filter((s) => s.name === "solidforge:cross-source-review")).toHaveLength(1);
		const collision = diagnostics.find((d: ResourceDiagnostic) => d.type === "collision");
		expect(collision?.collision?.name).toBe("solidforge:cross-source-review");
	});

	it("should namespace skills loaded from a directory resource path", () => {
		const { skills } = loadSkills({
			cwd: fixturesDir,
			agentDir: fixturesDir,
			skillPaths: [nsPackageDir],
			includeDefaults: false,
			namespaces: [{ path: nsPackageDir, namespace: "solidforge" }],
		});

		const names = skills.map((s) => s.name).sort();
		expect(names).toEqual(["solidforge:cross-source-review", "solidforge:other-skill"]);
	});
});

describe("validateNamespaceValue", () => {
	it("should accept valid namespace values", () => {
		expect(validateNamespaceValue("solidforge")).toEqual([]);
		expect(validateNamespaceValue("a")).toEqual([]);
		expect(validateNamespaceValue("ns-2")).toEqual([]);
	});

	it("should reject invalid namespace values", () => {
		expect(validateNamespaceValue("Solidforge").length).toBeGreaterThan(0);
		expect(validateNamespaceValue("a:b").length).toBeGreaterThan(0);
		expect(validateNamespaceValue("-x").length).toBeGreaterThan(0);
		expect(validateNamespaceValue("x-").length).toBeGreaterThan(0);
		expect(validateNamespaceValue("a--b").length).toBeGreaterThan(0);
		expect(validateNamespaceValue("x".repeat(65)).length).toBeGreaterThan(0);
		expect(validateNamespaceValue("").length).toBeGreaterThan(0);
	});
});

describe("findSkillByInvocationName", () => {
	const makeSkill = (name: string): Skill =>
		createTestSkill({
			name,
			description: "d",
			filePath: `/tmp/${name.replace(/[^a-z-]/g, "_")}/SKILL.md`,
			baseDir: `/tmp/${name.replace(/[^a-z-]/g, "_")}`,
		}) as Skill;

	function namespaced(name: string, ns: string): Skill {
		const skill = makeSkill(`${ns}:${name}`);
		skill.namespace = ns;
		skill.baseName = name;
		return skill;
	}

	it("should resolve an exact composed name", () => {
		const skills = [namespaced("cross-source-review", "solidforge")];
		expect(findSkillByInvocationName(skills, "solidforge:cross-source-review")?.name).toBe(
			"solidforge:cross-source-review",
		);
	});

	it("should fall back to a unique namespaced base name", () => {
		const skills = [namespaced("cross-source-review", "solidforge")];
		expect(findSkillByInvocationName(skills, "cross-source-review")?.name).toBe("solidforge:cross-source-review");
	});

	it("should not fall back when the requested name contains a colon", () => {
		const skills = [namespaced("arm-tools", "solidforge")];
		// baseName arm-tools requested with a colon-bearing string that is not the composed name
		expect(findSkillByInvocationName(skills, "other:arm-tools")).toBeUndefined();
	});

	it("should not fall back when two namespaces claim the base name", () => {
		const skills = [namespaced("utils", "a"), namespaced("utils", "b")];
		expect(findSkillByInvocationName(skills, "utils")).toBeUndefined();
	});

	it("should prefer an exact bare owner over a namespaced fallback", () => {
		const skills = [makeSkill("utils"), namespaced("utils", "a")];
		expect(findSkillByInvocationName(skills, "utils")?.namespace).toBeUndefined();
	});

	it("should resolve the exact composed name even when a bare twin exists", () => {
		const skills = [makeSkill("utils"), namespaced("utils", "a")];
		expect(findSkillByInvocationName(skills, "a:utils")?.namespace).toBe("a");
	});
});

describe("resolveBareNamespaceSkill", () => {
	function namespaced(name: string, ns: string): Skill {
		const skill = createTestSkill({
			name: `${ns}:${name}`,
			description: "d",
			filePath: `/tmp/${ns}-${name}/SKILL.md`,
			baseDir: `/tmp/${ns}-${name}`,
		});
		skill.namespace = ns;
		skill.baseName = name;
		return skill;
	}

	const skills = [namespaced("cross-source-review", "myorg"), namespaced("arm-tools", "myorg")];

	it("should resolve a namespaced skill via the bare /ns:name form", () => {
		const resolved = resolveBareNamespaceSkill("/myorg:cross-source-review", skills, []);
		expect(resolved?.skill.name).toBe("myorg:cross-source-review");
		expect(resolved?.args).toBe("");
	});

	it("should carry args", () => {
		const resolved = resolveBareNamespaceSkill("/myorg:arm-tools --with-tools", skills, []);
		expect(resolved?.skill.name).toBe("myorg:arm-tools");
		expect(resolved?.args).toBe("--with-tools");
	});

	it("should yield to a prompt template owning the same name", () => {
		const resolved = resolveBareNamespaceSkill("/myorg:arm-tools", skills, ["myorg:arm-tools"]);
		expect(resolved).toBeUndefined();
	});

	it("should pass through colon-bearing names with no exact skill match", () => {
		expect(resolveBareNamespaceSkill("/myorg:unknown", skills, [])).toBeUndefined();
		expect(resolveBareNamespaceSkill("/other:cross-source-review", skills, [])).toBeUndefined();
	});

	it("should ignore non-colon names and /skill: prefixed text", () => {
		expect(resolveBareNamespaceSkill("/cross-source-review", skills, [])).toBeUndefined();
		expect(resolveBareNamespaceSkill("/skill:myorg:cross-source-review", skills, [])).toBeUndefined();
		expect(resolveBareNamespaceSkill("plain text", skills, [])).toBeUndefined();
	});

	it("should resolve a colon-bearing frontmatter name by exact match", () => {
		const odd = createTestSkill({
			name: "weird:name",
			description: "d",
			filePath: "/tmp/weird/SKILL.md",
			baseDir: "/tmp/weird",
		});
		expect(resolveBareNamespaceSkill("/weird:name", [odd], [])?.skill.name).toBe("weird:name");
	});
});
