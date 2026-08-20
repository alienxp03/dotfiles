import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function formatCwd(cwd: string, home: string | undefined): string {
	if (!home) return cwd;

	const resolvedCwd = resolve(cwd);
	const resolvedHome = resolve(home);
	const relativeToHome = relative(resolvedHome, resolvedCwd);
	const isInsideHome =
		relativeToHome === "" ||
		(relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));

	if (!isInsideHome) return cwd;
	return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function formatWorkspacePath(path: string, home: string | undefined): string {
	if (!home) return path;

	const resolvedPath = resolve(path);
	const workspaceRoot = resolve(home, "workspace");
	const relativeToWorkspace = relative(workspaceRoot, resolvedPath);
	const isInsideWorkspace =
		relativeToWorkspace === "" ||
		(relativeToWorkspace !== ".." &&
			!relativeToWorkspace.startsWith(`..${sep}`) &&
			!isAbsolute(relativeToWorkspace));

	if (!isInsideWorkspace) return formatCwd(path, home);
	return relativeToWorkspace === "" ? "workspace" : relativeToWorkspace;
}

function formatElapsed(milliseconds: number): string {
	const totalSeconds = Math.floor(milliseconds / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	const seconds = totalSeconds % 60;
	return [hours, minutes, seconds].map((value) => String(value).padStart(2, "0")).join(":");
}

type GitLocation = {
	repositoryRoot: string;
	isWorktree: boolean;
};

function findGitLocation(cwd: string): GitLocation | undefined {
	let current = resolve(cwd);

	while (true) {
		const dotGit = join(current, ".git");
		try {
			const gitStat = statSync(dotGit);
			if (gitStat.isDirectory()) {
				return { repositoryRoot: current, isWorktree: false };
			}

			if (gitStat.isFile()) {
				const gitdirLine = readFileSync(dotGit, "utf8").trim();
				const match = gitdirLine.match(/^gitdir:\s*(.+)$/i);
				if (match) {
					const gitDir = resolve(current, match[1]);
					const commondirFile = join(gitDir, "commondir");
					if (existsSync(commondirFile)) {
						const commonGitDir = resolve(gitDir, readFileSync(commondirFile, "utf8").trim());
						return {
							repositoryRoot: dirname(commonGitDir),
							isWorktree: true,
						};
					}
				}
			}
		} catch {
			// Keep walking up when .git is missing or unreadable.
		}

		const parent = dirname(current);
		if (parent === current) return undefined;
		current = parent;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		const startedAt = Date.now();
		const gitLocation = findGitLocation(ctx.sessionManager.getCwd());
		const isWorktree = gitLocation?.isWorktree ?? false;
		const repositoryRoot = gitLocation?.repositoryRoot;

		ctx.ui.setFooter((tui, theme, footerData) => {
			const timer = setInterval(() => tui.requestRender(), 1000);
			timer.unref?.();
			const unsubscribeBranchChange = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose() {
					clearInterval(timer);
					unsubscribeBranchChange();
				},
				invalidate() {},
				render(width: number): string[] {
					const home = process.env.HOME || process.env.USERPROFILE;
					const sessionCwd = ctx.sessionManager.getCwd();
					const branch = footerData.getGitBranch();
					const sessionName = ctx.sessionManager.getSessionName();
					const icon = repositoryRoot ? (isWorktree ? "" : "") : "";
					const locationPath = repositoryRoot
						? isWorktree
							? formatCwd(repositoryRoot, home)
							: formatWorkspacePath(repositoryRoot, home)
						: formatWorkspacePath(sessionCwd, home);
					const location = `${icon} ${locationPath}${branch ? ` · ${branch}` : ""}${sessionName ? ` • ${sessionName}` : ""}`;

					const model = ctx.model?.id ?? "no-model";
					const reasoning = ctx.model?.reasoning ? (ctx.thinkingLevel ?? "off") : "off";
					const context = ctx.getContextUsage();
					const contextWindow = context?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextUsage =
						context?.percent == null
							? `? / ${formatTokens(contextWindow)}`
							: `${context.percent.toFixed(1)}% / ${formatTokens(contextWindow)}`;
					const contextColor: "error" | "warning" | "muted" =
						(context?.percent ?? 0) > 90
							? "error"
							: (context?.percent ?? 0) > 70
								? "warning"
								: "muted";

					const separator = theme.fg("dim", " | ");
					const primaryLine =
						theme.fg("accent", `${model} (${reasoning})`) +
						separator +
						theme.fg(contextColor, contextUsage) +
						separator +
						theme.fg("dim", formatElapsed(Date.now() - startedAt));
					return [
						truncateToWidth(theme.fg("dim", location), width, theme.fg("dim", "...")),
						truncateToWidth(primaryLine, width, ""),
					];
				},
			};
		});
	});
}
