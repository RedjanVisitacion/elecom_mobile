# Election Results mobile web reference

The implemented screen is `lib/features/elecom/results/results_screen.dart`.
It uses Flutter `LayoutBuilder` with a `<= 768` logical pixel breakpoint.
The following is an integration reference for a separate HTML web template;
this repository does not render these classes.

Place the compact summary, organization filters, percentage explanation, and
organization accordions in that order. Keep the distribution chart and analytics
inside a labelled dialog opened by the summary's **View Analytics** button.
Use USG, SITE, PAFE, AFPRO for the filter order after All. Preserve the web
application's existing desktop structure above the breakpoint.

```css
@media (max-width: 768px) {
  .results-layout { display: flex; flex-direction: column; gap: 12px; }
  .results-summary { order: 0; display: flex; align-items: center; justify-content: space-between; gap: 8px; }
  .organization-filters { order: 1; display: flex; gap: 8px; overflow-x: auto; }
  .organization-filters > button { flex-shrink: 0; min-height: 44px; }
  .results-percentage-note { order: 2; }
  .organization-accordions { order: 3; }
  .results-layout > .distribution-chart,
  .results-layout > .election-analytics,
  .votes-by-position,
  .position-participation,
  .voting-trend[data-has-data="false"] { display: none; }
  .position-group { padding-bottom: 10px; }
  .position-group > h3 { margin: 0 0 4px; }
  .candidate-row { display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; gap: 4px 8px; margin-bottom: 6px; align-items: center; }
  .candidate-avatar { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; }
  .candidate-stats { text-align: right; font-variant-numeric: tabular-nums; }
  .candidate-progress { grid-column: 2 / -1; width: 100%; height: 3px; }
  .results-analytics-dialog { box-sizing: border-box; width: calc(100% - 24px); max-height: 80dvh; overflow-y: auto; }
}
```

Use a standard person icon for absent or failed avatar images. The dialog should
have a visible close button, an accessible title, focus containment, Escape
support, and focus restoration to its trigger. Empty trend cards stay hidden
inside the mobile dialog too. Do not label organization filters as political
party filters; these filter organizations, while candidates may have party names.
