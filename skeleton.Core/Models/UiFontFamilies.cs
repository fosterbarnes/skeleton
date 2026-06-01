namespace skeleton.Models;

public readonly record struct FontFamilyOption(string Value, string Label);

public static class UiFontFamilies
{
    public const string SegoeUi = "Segoe UI";
    public const string SegoeUiStack = "Segoe UI, Segoe UI Variable";
    public const string Consolas = "Consolas";
    public const string Menlo = "Menlo";
    public const string MenloStack = "Menlo, SF Mono, Monaco";

    public static string DefaultMain =>
        OperatingSystem.IsMacOS() ? "Tahoma" : SegoeUi;

    public static string DefaultMono =>
        OperatingSystem.IsMacOS() ? Menlo : Consolas;

    public static readonly FontFamilyOption[] MainChoices =
    [
        new(SegoeUi, SegoeUi),
        new("Arial", "Arial"),
        new("Calibri", "Calibri"),
        new("Tahoma", "Tahoma"),
        new("Verdana", "Verdana"),
        new("Georgia", "Georgia"),
        new("Times New Roman", "Times New Roman"),
    ];

    public static readonly FontFamilyOption[] MonoChoices =
    [
        new(Consolas, Consolas),
        new(Menlo, Menlo),
        new("SF Mono", "SF Mono"),
        new("Monaco", "Monaco"),
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

    public static string NormalizeMono(string? value)
    {
        if (OperatingSystem.IsMacOS()
            && string.Equals(value, Consolas, StringComparison.OrdinalIgnoreCase))
            return DefaultMono;

        return Normalize(value, MonoChoices, DefaultMono);
    }

    public static int IndexOfMain(string? value) => IndexOf(value, MainChoices, DefaultMain);

    public static int IndexOfMono(string? value) => IndexOf(value, MonoChoices, DefaultMono);

    public static string ResolveMainStack(string name) =>
        string.Equals(name, SegoeUi, StringComparison.OrdinalIgnoreCase)
            ? SegoeUiStack
            : name;

    public static string ResolveMonoStack(string name) =>
        string.Equals(name, Menlo, StringComparison.OrdinalIgnoreCase)
            ? MenloStack
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
