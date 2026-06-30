using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Examples
{
    [RequireComponent(typeof(PanelRenderer))]
    public sealed class ToastPresenter : MonoBehaviour
    {
        [SerializeField] private PanelRenderer panelRenderer;
        [SerializeField] private int autoHideMs = 1800;

        private VisualElement toast;
        private Label messageLabel;
        private IVisualElementScheduledItem hideTask;

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

            hideTask?.Pause();
            hideTask = null;
            toast = null;
            messageLabel = null;
        }

        private void OnUIReload(PanelRenderer renderer, VisualElement root)
        {
            hideTask?.Pause();
            toast = root.Q<VisualElement>("toast");
            messageLabel = root.Q<Label>("message");
        }

        public void Show(string message)
        {
            if (toast == null || messageLabel == null)
                return;

            hideTask?.Pause();
            messageLabel.text = message;

            // Important: schedule class add to let UITK compute previous style first.
            toast.RemoveFromClassList("is-visible");
            toast.schedule.Execute(() => toast.AddToClassList("is-visible"));

            hideTask = toast.schedule.Execute(Hide).StartingIn(autoHideMs);
        }

        public void Hide()
        {
            hideTask?.Pause();
            hideTask = null;
            toast?.RemoveFromClassList("is-visible");
        }
    }
}
