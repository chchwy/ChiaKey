using System;
using System.Drawing;
using System.Windows.Forms;
using System.Windows.Forms.Layout;

namespace ChiaKey.Settings
{
    // Shared metrics for the Windows preference pages. Sections grow with their
    // contents; only the page scrolls when the available work area is too small.
    //
    // Pages, sections and rows measure each control once per pass. Nested auto-sized
    // TableLayoutPanels measured every level again for each level above it, which made
    // opening the window take seconds and each page switch most of a second.
    internal static class PreferenceLayout
    {
        // Lays its children out top to bottom across its full width.
        private sealed class StackPanel : Panel
        {
            private static readonly LayoutEngine Engine = new StackEngine();
            private bool arranging;

            internal StackPanel()
            {
                Margin = Padding.Empty;
                Padding = Padding.Empty;
                // Finish resumes it once the page is built
                SuspendLayout();
            }

            public override LayoutEngine LayoutEngine { get { return Engine; } }

            public override Size GetPreferredSize(Size proposedSize)
            {
                return new Size(proposedSize.Width, Arrange(proposedSize.Width, false));
            }

            // Every child is laid out, shown or not: a hidden page hides them all.
            private int Arrange(int width, bool apply)
            {
                int y = 0;
                foreach (Control child in Controls)
                {
                    Padding margin = child.Margin;
                    Size size = Measure(child, width - margin.Horizontal);
                    if (apply) child.SetBounds(margin.Left, y + margin.Top, size.Width, size.Height);
                    y += margin.Vertical + size.Height;
                }
                return y;
            }

            private sealed class StackEngine : LayoutEngine
            {
                public override bool Layout(object container, LayoutEventArgs layoutEventArgs)
                {
                    StackPanel stack = (StackPanel)container;
                    // measuring wraps text, which asks this stack to lay out again
                    if (stack.arranging || stack.ClientSize.Width <= 0) return false;
                    stack.arranging = true;
                    try
                    {
                        int height = stack.Arrange(stack.ClientSize.Width, true);
                        if (stack.Dock == DockStyle.Top)
                        {
                            if (stack.Height != height) stack.Height = height;
                        }
                        else if (stack.ClientSize.Height != height)
                        {
                            // a section's rows changed height; the page sizes the section
                            Control page = stack.Parent == null ? null : stack.Parent.Parent;
                            if (page != null) page.PerformLayout();
                        }
                    }
                    finally { stack.arranging = false; }
                    return false;
                }
            }
        }

        private sealed class SectionBox : GroupBox
        {
            internal readonly StackPanel Rows = new StackPanel { Dock = DockStyle.Fill };

            internal SectionBox()
            {
                Controls.Add(Rows);
            }

            public override Size GetPreferredSize(Size proposedSize)
            {
                Size chrome = Size - DisplayRectangle.Size;
                Size rows = Rows.GetPreferredSize(
                    new Size(Math.Max(1, proposedSize.Width - chrome.Width), 0));
                return new Size(proposedSize.Width, rows.Height + chrome.Height);
            }
        }

        // Shares its width between controls side by side, as the columns of a table.
        private sealed class ColumnsPanel : Panel
        {
            private static readonly LayoutEngine Engine = new RowEngine();
            private readonly Control[] controls;
            private readonly float[] fractions;
            private readonly bool image;

            internal ColumnsPanel(Control[] controls)
            {
                this.controls = controls;
                bool caption = controls.Length == 2 && controls[0] is Label;
                image = controls.Length == 2 && controls[0] is PictureBox;
                fractions = new float[controls.Length];
                for (int i = 0; i < controls.Length; ++i)
                    fractions[i] = caption ? (i == 0 ? 0.34F : 0.66F) : 1F / controls.Length;
                Controls.AddRange(controls);
            }

            public override LayoutEngine LayoutEngine { get { return Engine; } }

            public override Size GetPreferredSize(Size proposedSize)
            {
                return new Size(proposedSize.Width, Arrange(proposedSize.Width, false));
            }

            private int Arrange(int width, bool apply)
            {
                int x = 0, height = 0;
                for (int i = 0; i < controls.Length; ++i)
                {
                    Control control = controls[i];
                    Padding margin = control.Margin;
                    int column = image ? (i == 0 ? control.Width + margin.Horizontal : width - x)
                                       : (int)(width * fractions[i]);
                    if (i + 1 == controls.Length) column = width - x;
                    Size size = image && i == 0 ? control.Size : Measure(control, column - margin.Horizontal);
                    if (apply) control.SetBounds(x + margin.Left, margin.Top, size.Width, size.Height);
                    height = Math.Max(height, margin.Vertical + size.Height);
                    x += column;
                }
                return height;
            }

            private sealed class RowEngine : LayoutEngine
            {
                public override bool Layout(object container, LayoutEventArgs layoutEventArgs)
                {
                    ColumnsPanel row = (ColumnsPanel)container;
                    if (row.ClientSize.Width > 0) row.Arrange(row.ClientSize.Width, true);
                    return false;
                }
            }
        }

        // Auto-sized controls keep their own size, with text wrapped to the width;
        // the others fill the width.
        private static Size Measure(Control control, int width)
        {
            width = Math.Max(1, width);
            if (control is Label || control is CheckBox || control is RadioButton)
            {
                // Constrain text before measuring its height: translated labels and
                // checkboxes must wrap instead of forcing a horizontal scrollbar.
                Size maximum = new Size(width, 0);
                if (control.MaximumSize != maximum) control.MaximumSize = maximum;
            }
            if (control is StackPanel || control is SectionBox || control is ColumnsPanel)
                return new Size(width, control.GetPreferredSize(new Size(width, 0)).Height);
            if (!control.AutoSize) return new Size(width, control.Height);
            Size preferred = control.GetPreferredSize(new Size(width, 0));
            return new Size(Math.Min(width, preferred.Width), preferred.Height);
        }

        internal static Panel Page(string title)
        {
            Panel page = new Panel { AutoScroll = true, Padding = new Padding(20, 16, 20, 16),
                Size = new Size(700, 600), BackColor = Color.White };
            page.SuspendLayout();
            StackPanel stack = new StackPanel { Dock = DockStyle.Top };
            page.Tag = stack;
            page.Controls.Add(stack);
            Label heading = new Label { Text = title, AutoSize = true,
                Font = new Font("Microsoft JhengHei UI", 11F, FontStyle.Bold),
                Margin = new Padding(0, 0, 0, 14) };
            stack.Controls.Add(heading);
            return page;
        }

        internal static GroupBox Section(Control page, string title)
        {
            SectionBox section = new SectionBox { Text = title,
                Padding = new Padding(14, 8, 14, 10), Margin = new Padding(0, 0, 0, 12) };
            section.SuspendLayout();
            section.Tag = section.Rows;
            ((Control)page.Tag).Controls.Add(section);
            return section;
        }

        internal static void Row(Control parent, params Control[] controls)
        {
            Control rows = (Control)parent.Tag;
            if (controls.Length == 1)
            {
                // the margins a one-column row and its cell gave the control
                controls[0].Margin = new Padding(0, 3, 0, 3);
                rows.Controls.Add(controls[0]);
                return;
            }
            for (int i = 0; i < controls.Length; ++i)
                controls[i].Margin = new Padding(0, 2, i + 1 == controls.Length ? 0 : 12, 2);
            rows.Controls.Add(new ColumnsPanel(controls) { Margin = new Padding(0, 1, 0, 1) });
        }

        // only the containers built here; resuming any other control asks the form to scale it again
        internal static void Finish(Control control)
        {
            if (!(control is Panel || control is GroupBox || control is TableLayoutPanel)) return;
            foreach (Control child in control.Controls) Finish(child);
            control.ResumeLayout(false);
        }

        internal static Label Label(string text)
        {
            return new Label { Text = text, AutoSize = true };
        }

        internal static void Hint(Control parent, string text)
        {
            Label hint = Label(text);
            hint.ForeColor = SystemColors.GrayText;
            Row(parent, hint);
        }

        internal static TableLayoutPanel Inline(params Control[] controls)
        {
            TableLayoutPanel flow = new TableLayoutPanel { AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                ColumnCount = controls.Length, RowCount = 1,
                Margin = Padding.Empty, Padding = Padding.Empty };
            flow.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            flow.SuspendLayout();
            for (int i = 0; i < controls.Length; ++i)
            {
                Control control = controls[i];
                flow.ColumnStyles.Add(i + 1 == controls.Length
                    ? new ColumnStyle(SizeType.Percent, 100)
                    : new ColumnStyle(SizeType.AutoSize));
                control.Margin = new Padding(0, 0, 10, 4);
                control.Anchor = AnchorStyles.Top | AnchorStyles.Left;
                flow.Controls.Add(control, i, 0);
            }
            return flow;
        }

        internal static Button Button(string text)
        {
            return new Button { Text = text, AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink, MinimumSize = new Size(96, 28),
                Padding = new Padding(8, 2, 8, 2), UseVisualStyleBackColor = true };
        }
    }
}
