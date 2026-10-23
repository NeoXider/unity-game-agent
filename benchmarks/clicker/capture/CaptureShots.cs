using System.Collections;
using System.IO;
using System.Linq;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace Clicker.Capture
{
    // Renders Main.unity to two PNGs for the benchmark write-up: the clicker after a few taps and the
    // upgrades after some purchases. Not part of the acceptance score. The overlay canvas is switched
    // to camera space for the shot, because overlay UI never reaches a camera's render texture.
    public class CaptureShots
    {
        const int Width = 1080;
        const int Height = 1920;

        [UnityTest]
        public IEnumerator Capture()
        {
            PlayerPrefs.DeleteKey("clicker.save");
#if UNITY_EDITOR
            var load = UnityEditor.SceneManagement.EditorSceneManager.LoadSceneAsyncInPlayMode(
                "Assets/Scenes/Main.unity", new LoadSceneParameters(LoadSceneMode.Single));
            while (!load.isDone) yield return null;
#endif
            yield return null;
            var output = System.Environment.GetEnvironmentVariable("CLICKER_SHOTS");
            if (string.IsNullOrEmpty(output)) output = "Docs";
            Directory.CreateDirectory(output);

            yield return Click("ClickButton", 12);
            yield return Shot(Path.Combine(output, "clicker.png"));

            yield return Click("ClickButton", 60);
            yield return Click("Upgrade_StrongerClick", 2);
            yield return Click("Upgrade_AutoClicker", 1);
            yield return new WaitForSeconds(1.2f);
            yield return Shot(Path.Combine(output, "upgrades.png"));
            PlayerPrefs.DeleteKey("clicker.save");
        }

        static IEnumerator Click(string name, int times)
        {
            var target = Object.FindObjectsByType<Transform>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .FirstOrDefault(t => t.name == name);
            Assert.IsNotNull(target, name + " is not in the scene");
            for (var i = 0; i < times; i++)
            {
                ExecuteEvents.Execute(target.gameObject, new PointerEventData(EventSystem.current), ExecuteEvents.pointerClickHandler);
                yield return null;
            }
        }

        static IEnumerator Shot(string path)
        {
            var canvas = Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None).First(c => c.isRootCanvas);
            var camera = Camera.main != null ? Camera.main : new GameObject("ShotCamera").AddComponent<Camera>();
            var texture = new RenderTexture(Width, Height, 24);
            var mode = canvas.renderMode;
            canvas.renderMode = RenderMode.ScreenSpaceCamera;
            canvas.worldCamera = camera;
            canvas.planeDistance = 1f;
            camera.targetTexture = texture;
            yield return null;
            Canvas.ForceUpdateCanvases();
            camera.Render();
            var previous = RenderTexture.active;
            RenderTexture.active = texture;
            var image = new Texture2D(Width, Height, TextureFormat.RGB24, false);
            image.ReadPixels(new Rect(0, 0, Width, Height), 0, 0);
            image.Apply();
            RenderTexture.active = previous;
            camera.targetTexture = null;
            canvas.renderMode = mode;
            File.WriteAllBytes(path, image.EncodeToPNG());
            Object.Destroy(image);
            texture.Release();
        }
    }
}
