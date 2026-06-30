using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Animation
{
    public static class ScheduledTween
    {
        public static IVisualElementScheduledItem TweenOpacity(
            this VisualElement element,
            float from,
            float to,
            int durationMs,
            Action onComplete = null)
        {
            var start = Time.realtimeSinceStartup;
            IVisualElementScheduledItem item = null;

            item = element.schedule.Execute(() =>
            {
                var elapsedMs = (Time.realtimeSinceStartup - start) * 1000f;
                var t = Mathf.Clamp01(elapsedMs / Mathf.Max(1, durationMs));
                var eased = EaseOutCubic(t);

                element.style.opacity = Mathf.Lerp(from, to, eased);

                if (t >= 1f)
                {
                    item.Pause();
                    onComplete?.Invoke();
                }
            }).Every(16);

            return item;
        }

        private static float EaseOutCubic(float t)
        {
            return 1f - Mathf.Pow(1f - t, 3f);
        }
    }
}
