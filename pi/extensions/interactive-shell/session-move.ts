import { mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";

// Keep the source intact until the replacement runtime has loaded the copy.
export function prepareSessionMove(source: string, targetDir: string, cwd: string) {
	const original = readFileSync(source, "utf8");
	const newline = original.indexOf("\n");
	if (newline < 0) throw new Error("Session file has no complete header.");
	const header = JSON.parse(original.slice(0, newline));
	if (header.type !== "session" || typeof header.id !== "string") {
		throw new Error("Session file has an invalid header.");
	}
	const target = join(targetDir, basename(source));
	if (resolve(target) === resolve(source)) throw new Error("Session destination is unchanged.");
	mkdirSync(targetDir, { recursive: true });
	writeFileSync(target, `${JSON.stringify({ ...header, cwd })}${original.slice(newline)}`, {
		flag: "wx",
		mode: 0o600,
	});
	return {
		target,
		cancel() {
			unlinkSync(target);
		},
		complete() {
			if (readFileSync(source, "utf8") !== original) {
				throw new Error("Original session changed during the switch. Both files were kept.");
			}
			unlinkSync(source);
		},
	};
}
