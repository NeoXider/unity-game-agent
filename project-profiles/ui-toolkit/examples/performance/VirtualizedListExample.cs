using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Examples
{
    [RequireComponent(typeof(PanelRenderer))]
    public sealed class VirtualizedListExample : MonoBehaviour
    {
        [SerializeField] private PanelRenderer panelRenderer;

        private readonly List<ItemViewModel> items = new();
        private ListView listView;

        private void Awake()
        {
            for (var i = 0; i < 1000; i++)
                items.Add(new ItemViewModel($"Item {i + 1}", Random.Range(1, 100)));
        }

        private void OnEnable()
        {
            if (panelRenderer == null)
                panelRenderer = GetComponent<PanelRenderer>();

            panelRenderer.RegisterUIReloadCallback(OnUIReload);
        }

        private void OnDisable()
        {
            if (panelRenderer != null)
                panelRenderer.UnregisterUIReloadCallback(OnUIReload);

            if (listView != null)
                listView.itemsSource = null;

            listView = null;
        }

        private void OnUIReload(PanelRenderer renderer, VisualElement root)
        {
            listView = root.Q<ListView>("inventory-list");
            if (listView == null)
                return;

            listView.itemsSource = items;
            listView.fixedItemHeight = 32;
            listView.makeItem = MakeItem;
            listView.bindItem = BindItem;
        }

        private static VisualElement MakeItem()
        {
            var row = new VisualElement();
            row.AddToClassList("inventory-row");

            var name = new Label { name = "name" };
            name.AddToClassList("inventory-row__name");

            var count = new Label { name = "count" };
            count.AddToClassList("inventory-row__count");

            row.Add(name);
            row.Add(count);
            return row;
        }

        private void BindItem(VisualElement element, int index)
        {
            var item = items[index];
            element.Q<Label>("name").text = item.Name;
            element.Q<Label>("count").text = item.Count.ToString();
        }

        private readonly struct ItemViewModel
        {
            public readonly string Name;
            public readonly int Count;

            public ItemViewModel(string name, int count)
            {
                Name = name;
                Count = count;
            }
        }
    }
}
