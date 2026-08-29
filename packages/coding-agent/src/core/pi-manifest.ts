import { readFileSync } from "node:fs";
import { stripBom } from "../utils/text.ts";

export interface PiManifest {
	extensions?: string[];
	skills?: string[];
	prompts?: string[];
	themes?: string[];
	/** Opt-in namespace applied to name-keyed resources loaded from this package. */
	namespace?: string;
}

const RESOURCE_FIELDS = ["extensions", "skills", "prompts", "themes"] as const;

/** The manifest keys whose values are resource-path arrays. */
export type ResourceArrayKey = (typeof RESOURCE_FIELDS)[number];

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function readPiManifest(packageJsonPath: string): PiManifest | null {
	try {
		const pkg: unknown = JSON.parse(stripBom(readFileSync(packageJsonPath, "utf-8")));
		if (!isObject(pkg) || !isObject(pkg.pi)) {
			return null;
		}

		const manifest: PiManifest = {};
		for (const field of RESOURCE_FIELDS) {
			const entries = pkg.pi[field];
			if (Array.isArray(entries) && entries.every((entry) => typeof entry === "string")) {
				manifest[field] = entries;
			}
		}
		if (typeof pkg.pi.namespace === "string") {
			manifest.namespace = pkg.pi.namespace;
		}
		return manifest;
	} catch {
		return null;
	}
}
