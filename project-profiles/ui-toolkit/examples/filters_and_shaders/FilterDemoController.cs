using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Examples
{
    [RequireComponent(typeof(PanelRenderer))]
    public sealed class FilterDemoController : MonoBehaviour
    {
        [SerializeField] private PanelRenderer panelRenderer;

        private VisualElement backdrop;
        private Button toggleButton;
        private bool filtered;

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

            if (toggleButton != null)
                toggleButton.clicked -= Toggle;

            backdrop = null;
            toggleButton = null;
        }

        private void OnUIReload(PanelRenderer renderer, VisualElement root)
        {
            if (toggleButton != null)
                toggleButton.clicked -= Toggle;

            backdrop = root.Q<VisualElement>("backdrop");
            toggleButton = root.Q<Button>("toggle-filter-button");

            if (toggleButton != null)
                toggleButton.clicked += Toggle;
        }

        private void Toggle()
        {
            filtered = !filtered;
            backdrop?.EnableInClassList("is-filtered", filtered);
        }
    }
}
