import { Action, ActionPanel, Clipboard, getPreferenceValues, List, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { generateVariants, type AIBackend, type ReasoningEffort } from "./ai";

interface Preferences {
  backend: AIBackend;
  piPath: string;
  codexPath: string;
  variantCount: string;
  defaultPrompt: string;
  defaultModel: string;
  defaultReasoning: ReasoningEffort;
}

const models = ["gpt-6-astra", "gpt-6-sol", "gpt-6-luna"];
const efforts: ReasoningEffort[] = ["low", "medium", "high", "xhigh"];

export default function Grammar() {
  const preferences = getPreferenceValues<Preferences>();
  const count = clampCount(Number(preferences.variantCount));
  const backend: AIBackend = preferences.backend === "codex" ? "codex" : "pi";
  const model = models.includes(preferences.defaultModel) ? preferences.defaultModel : "gpt-6-sol";
  const reasoning = efforts.includes(preferences.defaultReasoning) ? preferences.defaultReasoning : "low";
  const prompt = preferences.defaultPrompt?.trim() || "Improve the selected text while preserving its meaning and tone. No em dash, or ;";
  const [answers, setAnswers] = useState<string[]>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isCurrent = true;

    async function improveClipboardText() {
      try {
        const clipboardText = await Clipboard.readText();
        if (!clipboardText?.trim()) {
          throw new Error("Copy some text, then run Grammar again.");
        }
        const result = await generateVariants({
          backend,
          clipboardText,
          prompt,
          count,
          model,
          reasoning,
          piPath: preferences.piPath,
          codexPath: preferences.codexPath,
        });
        if (isCurrent) setAnswers(result);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (isCurrent) {
          setErrorMessage(message);
          await showToast({
            style: Toast.Style.Failure,
            title: "Grammar failed",
            message,
          });
        }
      } finally {
        if (isCurrent) setIsLoading(false);
      }
    }

    void improveClipboardText();
    return () => {
      isCurrent = false;
    };
  }, []);

  if (isLoading) {
    return <List isLoading searchBarPlaceholder="" />;
  }

  if (errorMessage || !answers) {
    return (
      <List navigationTitle="Grammar">
        <List.EmptyView title="Could not improve text" description={errorMessage} />
      </List>
    );
  }

  return (
    <List isShowingDetail navigationTitle="Grammar" searchBarPlaceholder="">
      {answers.map((answer, index) => (
        <List.Item
          key={`option-${index + 1}`}
          title={`Option ${index + 1}`}
          detail={<List.Item.Detail markdown={preserveMarkdownLineBreaks(answer)} />}
          actions={
            <ActionPanel>
              <Action
                title="Copy and Paste Answer"
                onAction={async () => {
                  await Clipboard.copy(answer);
                  try {
                    await Clipboard.paste(answer);
                  } catch {
                    // The answer stays on the clipboard for manual paste.
                  }
                }}
              />
              <Action.CopyToClipboard title="Copy Answer" content={answer} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function preserveMarkdownLineBreaks(value: string): string {
  return value.replace(/\r\n?/g, "\n").replace(/([^\n])\n(?=[^\n])/g, "$1\n\n");
}

function clampCount(value: number): number {
  return Number.isFinite(value) ? Math.max(1, Math.min(8, Math.trunc(value))) : 3;
}
