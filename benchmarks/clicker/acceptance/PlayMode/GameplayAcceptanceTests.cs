using System.Collections;
using System.Linq;
using System.Text.RegularExpressions;
using Clicker.Core;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using UnityEngine.UI;

namespace Clicker.Acceptance
{
    // Plays Main.unity the way a player would: clicks go through the EventSystem. Any error logged
    // during a test fails it (Unity Test Framework default).
    public class GameplayAcceptanceTests
    {
        const string SaveKey = "clicker.save";
        const string ScenePath = "Assets/Scenes/Main.unity";

        [UnitySetUp]
        public IEnumerator LoadMain()
        {
            PlayerPrefs.DeleteKey(SaveKey);
            PlayerPrefs.Save();
#if UNITY_EDITOR
            var load = UnityEditor.SceneManagement.EditorSceneManager.LoadSceneAsyncInPlayMode(ScenePath, new LoadSceneParameters(LoadSceneMode.Single));
            Assert.IsNotNull(load, ScenePath + " could not be loaded");
            while (!load.isDone) yield return null;
#endif
            yield return null;
            yield return null;
        }

        [TearDown]
        public void ClearSave()
        {
            PlayerPrefs.DeleteKey(SaveKey);
            PlayerPrefs.Save();
        }

        static GameObject Find(string name)
        {
            var found = Object.FindObjectsByType<Transform>(FindObjectsInactive.Include, FindObjectsSortMode.None).FirstOrDefault(t => t.name == name);
            Assert.IsNotNull(found, name + " is not in the running scene");
            return found.gameObject;
        }

        static string TextOf(string name)
        {
            foreach (var component in Find(name).GetComponents<Component>())
            {
                if (component == null || component is Transform) continue;
                var property = component.GetType().GetProperty("text", typeof(string));
                if (property != null) return (string)property.GetValue(component, null);
            }
            Assert.Fail(name + " has no text component");
            return null;
        }

        static IEnumerator Click(string name, int times = 1)
        {
            Assert.IsNotNull(EventSystem.current, "no EventSystem in Main");
            var target = Find(name);
            for (var i = 0; i < times; i++)
            {
                ExecuteEvents.Execute(target, new PointerEventData(EventSystem.current), ExecuteEvents.pointerClickHandler);
                yield return null;
            }
            yield return null;
            yield return null;
        }

        static void AssertShows(string name, int value)
        {
            var text = TextOf(name);
            Assert.IsTrue(Regex.IsMatch(text, @"(?<![\d.,])" + value + @"(?![\d.,])"), name + " shows '" + text + "', expected " + value);
        }

        [UnityTest]
        public IEnumerator TenClicksShowTenCoins()
        {
            AssertShows("CoinsText", 0);
            yield return Click("ClickButton", 10);
            AssertShows("CoinsText", 10);
        }

        [UnityTest]
        public IEnumerator UpgradeUnlocksWhenAffordableAndRaisesClickPower()
        {
            var upgrade = Find("Upgrade_StrongerClick").GetComponent<Button>();
            Assert.IsFalse(upgrade.interactable, "StrongerClick should be locked with 0 coins");
            yield return Click("ClickButton", 10);
            Assert.IsTrue(upgrade.interactable, "StrongerClick should unlock at 10 coins");
            yield return Click("Upgrade_StrongerClick");
            AssertShows("CoinsText", 0);
            yield return Click("ClickButton");
            AssertShows("CoinsText", 2);
        }

        [UnityTest]
        public IEnumerator PauseSavesProgress()
        {
            yield return Click("ClickButton", 10);
            yield return Click("Upgrade_StrongerClick");
            var presenter = Object.FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None).FirstOrDefault(m => m.GetType().Name == "ClickerPresenter");
            Assert.IsNotNull(presenter, "ClickerPresenter is not in the running scene");
            presenter.SendMessage("OnApplicationPause", true, SendMessageOptions.DontRequireReceiver);
            Assert.IsTrue(PlayerPrefs.HasKey(SaveKey), "nothing saved under " + SaveKey + " on pause");
            var saved = ClickerEconomy.FromJson(PlayerPrefs.GetString(SaveKey));
            Assert.AreEqual(1, saved.Level(UpgradeId.StrongerClick), "saved StrongerClick level");
        }

        [UnityTest]
        public IEnumerator RunsThreeSecondsWithoutErrors()
        {
            var end = Time.realtimeSinceStartup + 3f;
            while (Time.realtimeSinceStartup < end) yield return null;
            LogAssert.NoUnexpectedReceived();
            Assert.IsNotNull(Find("IncomeText"));
        }
    }
}
