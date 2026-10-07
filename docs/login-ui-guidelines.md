# Mobile login styling

- Navy branding and button text: `#0D1B3E`; yellow primary action: `#FACC15`; blue links and focus outlines: `#1D4ED8`.
- Input text: `#1E293B`, 14 logical pixels, line height 1.5. Placeholder text: opaque `#64748B` on the light page background.
- Inputs use the original underline style: 1.2-pixel `#CBD5E1` idle line and 1.8-pixel gold `#F59E0B` focus line. Errors use red underlines and explanatory text.
- Use placeholders without visible labels above the inputs; retain semantic labels for screen readers. Student ID and lock icons remain visible, and the eye button announces Show/Hide password.
- Buttons and toggles have at least 48-pixel touch targets. The primary action is 52 pixels high and disabled during submission or until terms are accepted.
- Constrain form width to 420 pixels. Let the form scroll for narrow displays, enlarged text, validation messages, and keyboard visibility.
- The bundled USTP/ELECOM logos retain their original aspect ratio. The campus footer is pinned edge to edge at the viewport bottom, outside the bottom SafeArea. Its bottom-aligned replacement cutout has a uniform 8% navy shade that preserves the transparent background, with no top fade. Slate copyright overlays a soft white contrast wash, 12 pixels above the system bottom inset. Reserve footer space in the scrollable form; hide the decorative footer while the keyboard is open.