using System.Threading;
using System.Windows;

namespace TisaDynamicIsland;

public partial class App : Application
{
    private Mutex? instance;
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        instance = new Mutex(true, "Local\\TisaDynamicIsland.Windows", out var created);
        if (!created) { Shutdown(); return; }
        MainWindow = new MainWindow();
        MainWindow.Show();
        if (e.Args.Length == 2 && e.Args[0] == "--smoke-test")
        {
            var output = Path.GetFullPath(e.Args[1]);
            Directory.CreateDirectory(output);
            try
            {
                await Task.Delay(1500); // Allow the initial Loaded/render cycle to finish.
                await ((MainWindow)MainWindow).RunSmokeTestAsync(output);
                File.WriteAllText(Path.Combine(output, "result.txt"), "PASS: native window, pages, services and collapse behavior");
                ((MainWindow)MainWindow).FinishSmokeTest(0);
            }
            catch (Exception error)
            {
                File.WriteAllText(Path.Combine(output, "result.txt"), error.ToString());
                ((MainWindow)MainWindow).FinishSmokeTest(1);
            }
        }
    }
    protected override void OnExit(ExitEventArgs e)
    {
        instance?.Dispose();
        base.OnExit(e);
    }
}
