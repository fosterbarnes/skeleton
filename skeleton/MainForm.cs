namespace skeleton;

internal sealed class MainForm : Form
{
    public MainForm()
    {
        Text = "skeleton";
        ClientSize = new Size(480, 320);
        StartPosition = FormStartPosition.CenterScreen;

        using Icon? extracted = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        if (extracted != null)
        {
            Icon = (Icon)extracted.Clone();
        }
    }
}
