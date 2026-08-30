import {
  getSupportedThinkingLevels,
  type Api,
  type Model,
} from "@earendil-works/pi-ai";
import {
  DynamicBorder,
  type ExtensionAPI,
  type ExtensionUIContext,
} from "@earendil-works/pi-coding-agent";
import {
  Container,
  fuzzyFilter,
  Input,
  Spacer,
  Text,
  truncateToWidth,
  type Focusable,
  type KeybindingsManager,
  type TUI,
} from "@earendil-works/pi-tui";

type ThinkingLevel = Parameters<ExtensionAPI["setThinkingLevel"]>[0];

const MODEL_SELECTOR_SHORTCUT = "ctrl+shift+m" as const;

const THINKING_DESCRIPTIONS: Record<ThinkingLevel, string> = {
  off: "No reasoning",
  minimal: "Very brief reasoning (~1k tokens)",
  low: "Light reasoning (~2k tokens)",
  medium: "Moderate reasoning (~8k tokens)",
  high: "Deep reasoning (~16k tokens)",
  xhigh: "Extra-high reasoning (~32k tokens)",
  max: "Maximum reasoning",
};

type PiModel = Model<Api>;
type PiTheme = ExtensionUIContext["theme"];

class SearchableModelSelector extends Container implements Focusable {
  private readonly tui: TUI;
  private readonly theme: PiTheme;
  private readonly keybindings: KeybindingsManager;
  private readonly allModels: PiModel[];
  private filteredModels: PiModel[];
  private selectedIndex: number;
  private readonly searchInput: Input;
  private readonly listContainer: Container;
  private _focused = false;

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.searchInput.focused = value;
  }

  constructor(
    tui: TUI,
    theme: PiTheme,
    keybindings: KeybindingsManager,
    models: PiModel[],
    currentModel: PiModel | undefined,
    onSelect: (model: PiModel) => void,
    onCancel: () => void,
  ) {
    super();
    this.tui = tui;
    this.theme = theme;
    this.keybindings = keybindings;
    this.onSelect = onSelect;
    this.onCancel = onCancel;
    this.allModels = [...models];
    this.filteredModels = this.allModels;
    const currentIndex = this.allModels.findIndex(
      (model) =>
        model.provider === currentModel?.provider &&
        model.id === currentModel?.id,
    );
    this.selectedIndex = currentIndex >= 0 ? currentIndex : 0;

    this.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
    this.addChild(new Spacer(1));
    this.addChild(
      new Text(theme.fg("accent", theme.bold("Search model")), 1, 0),
    );
    this.addChild(new Text(theme.fg("muted", "Type to filter models"), 1, 0));
    this.addChild(new Spacer(1));

    this.searchInput = new Input();
    this.addChild(this.searchInput);
    this.addChild(new Spacer(1));

    this.listContainer = new Container();
    this.addChild(this.listContainer);
    this.addChild(new Spacer(1));
    this.addChild(
      new Text(
        theme.fg(
          "dim",
          `↑↓ navigate  ${keybindings.getKeys("tui.select.confirm")[0] ?? "enter"} select  ${keybindings.getKeys("tui.select.cancel")[0] ?? "esc"} cancel`,
        ),
        1,
        0,
      ),
    );
    this.addChild(new Spacer(1));
    this.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
    this.updateList();

    this.searchInput.onSubmit = () => {
      this.confirmSelection();
    };
    this.searchInput.onEscape = onCancel;
  }

  private getModelSearchText(model: PiModel): string {
    return `${model.id} ${model.provider} ${model.name ?? ""}`;
  }

  private getModelLabel(model: PiModel): string {
    const name =
      model.name && model.name !== model.id ? ` — ${model.name}` : "";
    return `${model.id} [${model.provider}]${name}`;
  }

  private updateList(): void {
    const query = this.searchInput.getValue();
    this.filteredModels = query.trim()
      ? fuzzyFilter(this.allModels, query, (model) =>
          this.getModelSearchText(model),
        )
      : this.allModels;
    this.selectedIndex = query.trim()
      ? 0
      : Math.min(
          this.selectedIndex,
          Math.max(0, this.filteredModels.length - 1),
        );

    this.listContainer.clear();
    for (const [index, model] of this.filteredModels.entries()) {
      const label = this.getModelLabel(model);
      const line =
        index === this.selectedIndex
          ? this.theme.fg("accent", `→ ${label}`)
          : `  ${this.theme.fg("text", label)}`;
      this.listContainer.addChild(new Text(line, 1, 0));
    }
    if (this.filteredModels.length === 0) {
      this.listContainer.addChild(
        new Text(this.theme.fg("muted", "No matching models"), 1, 0),
      );
    }
  }

  private confirmSelection(): void {
    const selectedModel = this.filteredModels[this.selectedIndex];
    if (selectedModel) this.onSelect?.(selectedModel);
  }

  handleInput(data: string): void {
    if (this.keybindings.matches(data, "tui.select.up")) {
      if (this.filteredModels.length > 0) {
        this.selectedIndex =
          this.selectedIndex === 0
            ? this.filteredModels.length - 1
            : this.selectedIndex - 1;
        this.tui.requestRender();
      }
      return;
    }
    if (this.keybindings.matches(data, "tui.select.down")) {
      if (this.filteredModels.length > 0) {
        this.selectedIndex =
          this.selectedIndex === this.filteredModels.length - 1
            ? 0
            : this.selectedIndex + 1;
        this.tui.requestRender();
      }
      return;
    }
    if (this.keybindings.matches(data, "tui.select.confirm") || data === "\n") {
      const selectedModel = this.filteredModels[this.selectedIndex];
      if (selectedModel) this.onSelect?.(selectedModel);
      return;
    }
    if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.onCancel?.();
      return;
    }

    this.searchInput.handleInput(data);
    this.updateList();
    this.tui.requestRender();
  }

  private onSelect?: (model: PiModel) => void;
  private onCancel?: () => void;
}

export default function (pi: ExtensionAPI) {
  pi.registerShortcut(MODEL_SELECTOR_SHORTCUT, {
    description: "Select model and reasoning level",
    handler: async (ctx) => {
      if (!ctx.hasUI) return;

      const scopedModels = ctx.scopedModels.map(({ model }) => model);
      const models = [
        ...(scopedModels.length > 0
          ? scopedModels
          : ctx.modelRegistry.getAvailable()),
      ].sort((a, b) => {
        const providerOrder = a.provider.localeCompare(b.provider);
        if (providerOrder !== 0) return providerOrder;

        const aIsCurrent =
          a.provider === ctx.model?.provider && a.id === ctx.model?.id;
        const bIsCurrent =
          b.provider === ctx.model?.provider && b.id === ctx.model?.id;
        if (aIsCurrent !== bIsCurrent) return aIsCurrent ? -1 : 1;
        return a.id.localeCompare(b.id);
      });

      if (models.length === 0) {
        ctx.ui.notify(
          "No models are available. Use /login to add a provider.",
          "warning",
        );
        return;
      }

      const selectedModel = await ctx.ui.custom<PiModel | undefined>(
        (tui, theme, keybindings, done) =>
          new SearchableModelSelector(
            tui,
            theme,
            keybindings,
            models,
            ctx.model,
            (model) => done(model),
            () => done(undefined),
          ),
      );
      if (!selectedModel) return;

      const selected = await pi.setModel(selectedModel);
      if (!selected) {
        ctx.ui.notify(
          `No API key is available for ${selectedModel.provider}.`,
          "error",
        );
        return;
      }

      const levels: ThinkingLevel[] = selectedModel.reasoning
        ? getSupportedThinkingLevels(selectedModel)
        : ["off"];
      const selectedLevel = await ctx.ui.custom<ThinkingLevel | undefined>(
        (tui, theme, keybindings, done) => {
          let selectedIndex = Math.floor(levels.length / 2);

          const render = (width: number) => {
            const lines = [
              theme.fg(
                "accent",
                theme.bold(`Select reasoning for ${selectedModel.id}`),
              ),
              "",
              ...levels.map((level, index) => {
                const label = `${level} — ${THINKING_DESCRIPTIONS[level]}`;
                return index === selectedIndex
                  ? theme.fg("accent", `→ ${label}`)
                  : `  ${theme.fg("text", label)}`;
              }),
              "",
              theme.fg(
                "dim",
                "↑↓ navigate  " +
                  keybindings.getKeys("tui.select.confirm")[0] +
                  " select  " +
                  keybindings.getKeys("tui.select.cancel")[0] +
                  " cancel",
              ),
            ];
            return lines.map((line) => truncateToWidth(line, width));
          };

          return {
            render,
            invalidate: () => undefined,
            handleInput: (data: string) => {
              if (keybindings.matches(data, "tui.select.up") || data === "k") {
                selectedIndex = Math.max(0, selectedIndex - 1);
              } else if (
                keybindings.matches(data, "tui.select.down") ||
                data === "j"
              ) {
                selectedIndex = Math.min(levels.length - 1, selectedIndex + 1);
              } else if (keybindings.matches(data, "tui.select.confirm")) {
                done(levels[selectedIndex]);
                return;
              } else if (keybindings.matches(data, "tui.select.cancel")) {
                done(undefined);
                return;
              } else {
                return;
              }
              tui.requestRender();
            },
          };
        },
      );
      if (!selectedLevel) {
        ctx.ui.notify(`Model: ${selectedModel.id}`, "info");
        return;
      }
      pi.setThinkingLevel(selectedLevel);
      ctx.ui.notify(
        `Model: ${selectedModel.id} · Reasoning: ${selectedLevel}`,
        "info",
      );
    },
  });
}
