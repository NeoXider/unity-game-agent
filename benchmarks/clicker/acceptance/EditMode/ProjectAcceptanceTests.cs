using System.Linq;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace Clicker.Acceptance
{
    // The prefab and scene contract from brief.md, read from the assets on disk.
    public class ProjectAcceptanceTests
    {
        const string PrefabPath = "Assets/Clicker/UI/ClickerCanvas.prefab";
        const string ScenePath = "Assets/Scenes/Main.unity";

        static readonly string[] Buttons = { "ClickButton", "Upgrade_StrongerClick", "Upgrade_AutoClicker" };
        static readonly string[] Texts = { "CoinsText", "IncomeText" };

        static GameObject Prefab()
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);
            Assert.IsNotNull(prefab, PrefabPath + " is missing");
            return prefab;
        }

        static Transform Child(GameObject root, string name)
        {
            return root.GetComponentsInChildren<Transform>(true).FirstOrDefault(t => t.name == name);
        }

        [Test]
        public void MainIsTheOnlySceneInBuildSettings()
        {
            var scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
            CollectionAssert.AreEqual(new[] { ScenePath }, scenes);
        }

        [Test]
        public void PrefabIsAnOverlayCanvasWithThePresenter()
        {
            var prefab = Prefab();
            var canvas = prefab.GetComponent<Canvas>();
            Assert.IsNotNull(canvas, "Canvas on the prefab root");
            Assert.AreEqual(RenderMode.ScreenSpaceOverlay, canvas.renderMode);
            Assert.IsTrue(prefab.GetComponentsInChildren<MonoBehaviour>(true).Any(m => m != null && m.GetType().Name == "ClickerPresenter"),
                "ClickerPresenter on the prefab");
        }

        [Test]
        public void PrefabHasTheNamedButtonsAndTexts()
        {
            var prefab = Prefab();
            foreach (var name in Buttons)
            {
                var child = Child(prefab, name);
                Assert.IsNotNull(child, name + " is missing");
                Assert.IsNotNull(child.GetComponent<Button>(), name + " has no Button");
            }
            foreach (var name in Texts)
            {
                var child = Child(prefab, name);
                Assert.IsNotNull(child, name + " is missing");
                Assert.IsTrue(child.GetComponents<Component>().Any(c => c != null && (c.GetType().Name == "Text" || c.GetType().Name == "TextMeshProUGUI")),
                    name + " has no Text or TextMeshProUGUI");
            }
        }
    }
}
