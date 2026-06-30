using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Examples
{
    [RequireComponent(typeof(PanelRenderer))]
    public sealed class MainMenuPresenter : MonoBehaviour
    {
        [SerializeField] private PanelRenderer panelRenderer;

        private bool wired;
        private VisualElement root;
        private Button playButton;
        private Button settingsButton;
        private Button quitButton;

        private void Reset()
        {
            panelRenderer = GetComponent<PanelRenderer>();
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

            Unwire();
        }

        // This handler's (PanelRenderer, VisualElement) signature selects the 2-arg UIReloadCallback
        // overload (the default). Unity 6.5 also has a 3-arg VersionedUIReloadCallback — see docs/08.
        private void OnUIReload(PanelRenderer renderer, VisualElement newRoot)
        {
            // Always rewire: each reload may hand back a brand-new visual tree, so cached
            // element references and their event subscriptions are stale. Unwire() makes this
            // idempotent (no duplicate handlers) even if the callback fires more than once.
            Unwire();
            root = newRoot;

            playButton = Require<Button>(root, "play-button");
            settingsButton = Require<Button>(root, "settings-button");
            quitButton = Require<Button>(root, "quit-button");

            playButton.clicked += OnPlayClicked;
            settingsButton.clicked += OnSettingsClicked;
            quitButton.clicked += OnQuitClicked;

            wired = true;
        }

        private void Unwire()
        {
            if (playButton != null) playButton.clicked -= OnPlayClicked;
            if (settingsButton != null) settingsButton.clicked -= OnSettingsClicked;
            if (quitButton != null) quitButton.clicked -= OnQuitClicked;

            root = null;
            playButton = null;
            settingsButton = null;
            quitButton = null;
            wired = false;
        }

        private static T Require<T>(VisualElement root, string name) where T : VisualElement
        {
            var element = root.Q<T>(name);
            if (element == null)
                throw new MissingReferenceException($"Missing UI element #{name} of type {typeof(T).Name}");

            return element;
        }

        private void OnPlayClicked()
        {
            Debug.Log("Play");
        }

        private void OnSettingsClicked()
        {
            Debug.Log("Settings");
        }

        private void OnQuitClicked()
        {
            Debug.Log("Quit");
            Application.Quit();
        }
    }
}
