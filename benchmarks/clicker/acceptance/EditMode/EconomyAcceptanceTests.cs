using System;
using Clicker.Core;
using NUnit.Framework;

namespace Clicker.Acceptance
{
    // The economy rules from brief.md, checked through the contract only.
    public class EconomyAcceptanceTests
    {
        static ClickerEconomy Rich(int clicks)
        {
            var economy = new ClickerEconomy();
            for (var i = 0; i < clicks; i++) economy.Click();
            return economy;
        }

        [Test]
        public void NewGameStartsEmpty()
        {
            var economy = new ClickerEconomy();
            Assert.AreEqual(0, economy.Coins);
            Assert.AreEqual(1, economy.CoinsPerClick);
            Assert.AreEqual(0, economy.CoinsPerSecond);
            foreach (UpgradeId id in Enum.GetValues(typeof(UpgradeId))) Assert.AreEqual(0, economy.Level(id), id.ToString());
        }

        [Test]
        public void BaseCosts()
        {
            var economy = new ClickerEconomy();
            Assert.AreEqual(10, economy.Cost(UpgradeId.StrongerClick));
            Assert.AreEqual(25, economy.Cost(UpgradeId.AutoClicker));
        }

        [Test]
        public void ClickAddsCoinsPerClick()
        {
            Assert.AreEqual(7, Rich(7).Coins);
        }

        [Test]
        public void BuyingTakesTheCostAndRaisesCostAndClickPower()
        {
            var economy = Rich(10);
            Assert.IsTrue(economy.CanBuy(UpgradeId.StrongerClick));
            Assert.IsTrue(economy.TryBuy(UpgradeId.StrongerClick));
            Assert.AreEqual(0, economy.Coins);
            Assert.AreEqual(1, economy.Level(UpgradeId.StrongerClick));
            Assert.AreEqual(11, economy.Cost(UpgradeId.StrongerClick)); // floor(10 * 1.15)
            Assert.AreEqual(2, economy.CoinsPerClick);
        }

        [Test]
        public void BuyingWithoutCoinsChangesNothing()
        {
            var economy = Rich(9);
            Assert.IsFalse(economy.CanBuy(UpgradeId.StrongerClick));
            Assert.IsFalse(economy.TryBuy(UpgradeId.StrongerClick));
            Assert.AreEqual(9, economy.Coins);
            Assert.AreEqual(0, economy.Level(UpgradeId.StrongerClick));
        }

        [Test]
        public void CostGrowsBy15PercentRoundedDown()
        {
            var economy = Rich(1000);
            for (var i = 0; i < 5; i++) Assert.IsTrue(economy.TryBuy(UpgradeId.AutoClicker));
            Assert.AreEqual(Math.Floor(25 * Math.Pow(1.15, 5)), economy.Cost(UpgradeId.AutoClicker));
        }

        [Test]
        public void AutoClickerPaysPerSecond()
        {
            var economy = Rich(60);
            Assert.IsTrue(economy.TryBuy(UpgradeId.AutoClicker)); // 25
            Assert.IsTrue(economy.TryBuy(UpgradeId.AutoClicker)); // 28
            var before = economy.Coins;
            Assert.AreEqual(2, economy.CoinsPerSecond);
            economy.Tick(2.5);
            Assert.AreEqual(before + 5, economy.Coins, 1e-6);
        }

        [Test]
        public void SaveAndLoadRoundTrip()
        {
            var economy = Rich(40);
            Assert.IsTrue(economy.TryBuy(UpgradeId.StrongerClick));
            Assert.IsTrue(economy.TryBuy(UpgradeId.AutoClicker));
            var loaded = ClickerEconomy.FromJson(economy.ToJson());
            Assert.AreEqual(economy.Coins, loaded.Coins, 1e-6);
            Assert.AreEqual(1, loaded.Level(UpgradeId.StrongerClick));
            Assert.AreEqual(1, loaded.Level(UpgradeId.AutoClicker));
        }

        [Test]
        public void BadSaveDataStartsANewGame()
        {
            foreach (var json in new[] { null, "", "not json {" })
            {
                var economy = ClickerEconomy.FromJson(json);
                Assert.IsNotNull(economy, "FromJson(" + (json ?? "null") + ")");
                Assert.AreEqual(0, economy.Coins);
            }
        }

        [Test]
        public void ChangedFiresOnClickAndPurchaseOnly()
        {
            var economy = Rich(10);
            var count = 0;
            economy.Changed += () => count++;
            economy.Click();
            Assert.AreEqual(1, count, "Click");
            Assert.IsTrue(economy.TryBuy(UpgradeId.StrongerClick));
            Assert.AreEqual(2, count, "TryBuy");
            economy.TryBuy(UpgradeId.AutoClicker);
            Assert.AreEqual(2, count, "a failed TryBuy must not fire Changed");
        }
    }
}
