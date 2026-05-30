namespace skeleton.Models;

public readonly record struct FontFamilyOption(string Value, string Label);

public static class UiFontFamilies
{
    public const string DefaultMain = "Segoe UI";
    public const string SegoeUiStack = "Segoe UI, Segoe UI Variable";
    public const string DefaultMono = "Consolas";

    public static readonly FontFamilyOption[] MainChoices =
    [
        new(DefaultMain, "Segoe UI"),
        new("Arial", "Arial"),
        new("Calibri", "Calibri"),
        new("Tahoma", "Tahoma"),
        new("Verdana", "Verdana"),
        new("Georgia", "Georgia"),
        new("Times New Roman", "Times New Roman"),
    ];

    public static readonly FontFamilyOption[] MonoChoices =
    [
        new(DefaultMono, "Consolas"),
        new("Cascadia Mono", "Cascadia Mono"),
        new("Cascadia Code", "Cascadia Code"),
        new("Courier New", "Courier New"),
        new("Lucida Console", "Lucida Console"),
    ];

    public static string[] MainValues { get; } = MainChoices.Select(c => c.Value).ToArray();
    public static string[] MainLabels { get; } = MainChoices.Select(c => c.Label).ToArray();
    public static string[] MonoValues { get; } = MonoChoices.Select(c => c.Value).ToArray();
    public static string[] MonoLabels { get; } = MonoChoices.Select(c => c.Label).ToArray();

    public static string NormalizeMain(string? value) => Normalize(value, MainChoices, DefaultMain);

    public static string NormalizeMono(string? value) => Normalize(value, MonoChoices, DefaultMono);

    public static int IndexOfMain(string? value) => IndexOf(value, MainChoices, DefaultMain);

    public static int IndexOfMono(string? value) => IndexOf(value, MonoChoices, DefaultMono);

    public static string ResolveMainStack(string name) =>
        string.Equals(name, DefaultMain, StringComparison.OrdinalIgnoreCase)
            ? SegoeUiStack
            : name;

    private static string Normalize(string? value, FontFamilyOption[] choices, string fallback)
    {
        if (string.IsNullOrWhiteSpace(value))
            return fallback;

        foreach (var choice in choices)
        {
            if (string.Equals(choice.Value, value, StringComparison.OrdinalIgnoreCase))
                return choice.Value;
        }

        return fallback;
    }

    private static int IndexOf(string? value, FontFamilyOption[] choices, string fallback)
    {
        var normalized = Normalize(value, choices, fallback);
        for (var i = 0; i < choices.Length; i++)
        {
            if (string.Equals(choices[i].Value, normalized, StringComparison.Ordinal))
                return i;
        }

        return 0;
    }
}
