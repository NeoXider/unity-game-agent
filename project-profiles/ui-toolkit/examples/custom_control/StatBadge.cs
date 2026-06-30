using UnityEngine.UIElements;

namespace Game.UI.Controls
{
    [UxmlElement]
    public partial class StatBadge : VisualElement
    {
        private readonly Label titleLabel;
        private readonly Label valueLabel;
        private int currentValue;
        private int warningBelow = 10;

        [UxmlAttribute]
        public string Title
        {
            get => titleLabel.text;
            set => titleLabel.text = value ?? string.Empty;
        }

        [UxmlAttribute]
        public int Value
        {
            get => currentValue;
            set
            {
                currentValue = value;
                valueLabel.text = value.ToString();
                RefreshState();
            }
        }

        [UxmlAttribute("warning-below")]
        public int WarningBelow
        {
            get => warningBelow;
            set
            {
                warningBelow = value;
                RefreshState();
            }
        }

        public StatBadge()
        {
            AddToClassList("stat-badge");

            titleLabel = new Label { name = "stat-title" };
            titleLabel.AddToClassList("stat-badge__title");

            valueLabel = new Label { name = "stat-value" };
            valueLabel.AddToClassList("stat-badge__value");

            Add(titleLabel);
            Add(valueLabel);

            Title = "Stat";
            Value = 0;
        }

        public void SetValueWithoutWarning(int value)
        {
            currentValue = value;
            valueLabel.text = value.ToString();
            RemoveFromClassList("is-warning");
        }

        private void RefreshState()
        {
            EnableInClassList("is-warning", currentValue <= warningBelow);
        }
    }
}
