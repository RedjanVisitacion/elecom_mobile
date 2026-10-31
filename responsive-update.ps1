$ErrorActionPreference = 'Stop'
$webRoot = 'G:\elecom_web\frontend\org_elecom\elecom_admin'
$jsRoot = Join-Path $webRoot 'admin_components\admin_js'
$viewportScript = @'
/* Keep phone layouts readable when a browser requests a desktop viewport. */
(function () {
  const viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) return;
  const original = viewport.content;
  const touch = navigator.maxTouchPoints > 0;
  let lastWidth = null;
  const updateViewport = () => {
    const width = Math.round(window.screen.width);
    const phone = touch && Math.min(screen.width, screen.height) <= 600;
    if (!phone || width <= 0) return;
    if (width === lastWidth) return;
    lastWidth = width;
    // An explicit screen width also handles desktop mode's usual 980px layout.
    // Do not restrict pinch zoom or react to visualViewport/keyboard changes.
    viewport.content = `width=${width}, initial-scale=1, viewport-fit=cover`;
  };
  updateViewport();
  window.addEventListener('orientationchange', () => {
    lastWidth = null;
    updateViewport();
  });
  window.addEventListener('resize', updateViewport);
})();
'@
$viewportScript = $viewportScript.Replace("  const original = viewport.content;`r`n", '').Replace("  const original = viewport.content;`n", '')
[IO.File]::WriteAllText((Join-Path $jsRoot 'admin_viewport.js'), $viewportScript, [Text.UTF8Encoding]::new($false))
$cssPath = Join-Path $webRoot 'admin_components\admin_css\admin_mobile.css'
$rules = @'

/* Shared mobile foundation: the page scrolls, wide data stays in its own region. */
@media screen and (max-width: 992px) {
  html:has(body.admin-framed-shell) { min-width:0; }
  body.admin-framed-shell { min-width:0; -webkit-text-size-adjust:100%; text-size-adjust:100%; }
  body.admin-framed-shell:not(.live-chat-page) .main-content {
    display:block; height:100dvh; min-height:0; margin-left:0;
    overflow-y:auto; overflow-x:clip; padding-bottom:calc(16px + env(safe-area-inset-bottom,0px));
    scroll-padding-top:16px;
  }
  body.admin-framed-shell:not(.live-chat-page) .content-area {
    height:auto; min-height:0; min-width:0; max-width:100%; overflow:visible;
    padding:12px; flex:none;
  }
  body.admin-framed-shell .content-area :is(.card,.card-body,form,fieldset,.row > *) { min-width:0; }
  body.admin-framed-shell .content-area :is(h1,h2,h3,h4,h5,h6,p,.form-label) { overflow-wrap:anywhere; }
  body.admin-framed-shell .content-area :is(input,select,textarea) { max-width:100%; min-width:0; }
  body.admin-framed-shell .content-area :is(.form-control,.form-select) { min-height:44px; font-size:16px !important; }
  body.admin-framed-shell :is(.content-area,.modal) .btn { min-height:44px; white-space:normal; }
  body.admin-framed-shell :is(.table-responsive,.backup-table-wrap,.ledger-table-wrap) {
    min-width:0; max-width:100%; overflow-x:auto; overscroll-behavior-x:contain;
  }
  body.admin-framed-shell .modal-dialog { width:auto; max-width:calc(100% - 16px); margin:8px auto; }
  body.admin-framed-shell .modal-content { max-height:calc(100dvh - 16px); }
  body.admin-framed-shell .modal-body { overflow-y:auto; min-height:0; }
  body.admin-framed-shell .modal-footer { flex-wrap:wrap; gap:8px; }
  body.admin-framed-shell .modal-footer .btn { flex:1 1 auto; }
  body.admin-framed-shell:has(#sidebar.active) .main-content { overflow:hidden; }
  body.admin-framed-shell .elections-shell { height:auto; flex:none; overflow:visible; }
  body.admin-framed-shell .elections-grid { flex:none; }
  body.admin-framed-shell :is(.election-form,.elections-list) { overflow:visible; max-height:none; }
  body.admin-framed-shell .coc-workspace { height:auto; flex:none; overflow:visible; }
  body.admin-framed-shell .coc-split { display:flex; flex-direction:column; flex:none; overflow:visible; gap:16px; }
  body.admin-framed-shell .coc-settings { order:1; width:100%; flex:none; }
  body.admin-framed-shell .coc-previews { order:2; width:100%; flex:none; height:70dvh; min-height:420px; }
  body.admin-framed-shell .coc-settings #chairSignaturePad { flex:none; height:160px; min-height:160px; }
  body.admin-framed-shell .coc-format-controls button { min-width:36px; min-height:36px; }
  body.admin-framed-shell .coc-viewer-controls { flex-wrap:wrap; }
  body.admin-framed-shell.live-chat-page .chat-shell { min-width:0; margin:12px; }
  body.admin-framed-shell.live-chat-page :is(.chat-search-wrap input,.chat-input-bar textarea) { font-size:16px; }
  body.admin-framed-shell.live-chat-page .chat-input-bar :is(button,textarea) { min-height:44px; }
  body.admin-framed-shell .files-control { min-height:44px; }
  body.admin-framed-shell .files-search-wrap { height:44px; }
  body.admin-framed-shell #filesSearch { font-size:16px; }
  body.admin-framed-shell .files-view-toggle .files-icon { width:40px; height:40px; }
  body.admin-framed-shell .search-box { min-width:0; }
  body.admin-framed-shell .candidate-toolbar-actions { flex-wrap:wrap; gap:10px !important; }
}
@media screen and (max-width: 600px) {
  body.admin-framed-shell .election-fields { grid-template-columns:minmax(0,1fr); }
  body.admin-framed-shell .election-fields > * { grid-column:1 !important; }
  body.admin-framed-shell :is(.election-info-grid,.report-format-grid,.report-summary-metrics,.report-summary-grid) { grid-template-columns:minmax(0,1fr); }
  body.admin-framed-shell .report-summary-card.wide { grid-column:auto; }
  body.admin-framed-shell .report-builder-card .card-body { padding:12px; }
  body.admin-framed-shell .candidate-toolbar-container { padding:0; }
  body.admin-framed-shell .candidate-toolbar-actions { width:100%; }
  body.admin-framed-shell .candidate-transfer-actions { display:flex; flex-wrap:wrap; width:100%; gap:8px; }
  body.admin-framed-shell .candidate-transfer-actions .btn { flex:1 1 110px; }
  body.admin-framed-shell .files-grid:not(.files-list) { grid-template-columns:repeat(auto-fit,minmax(min(150px,100%),1fr)); }
  body.admin-framed-shell .files-list .file-tile { grid-template-columns:28px minmax(0,1fr); }
  body.admin-framed-shell .files-list .file-metadata { grid-column:2; flex-wrap:wrap; }
  body.admin-framed-shell .input-group { flex-wrap:wrap; }
  body.admin-framed-shell .input-group > .form-control { flex:1 1 140px; }
  body.admin-framed-shell .input-group > .btn { flex:0 1 auto; }
  body.admin-framed-shell .reg-form-card .card-body { padding:12px !important; }
  body.admin-framed-shell #candidateApplicationsPanel .d-flex { flex-wrap:wrap; gap:8px; }
  body.admin-framed-shell .admin-page-path { font-size:12px; }
  body.admin-framed-shell .admin-frame-title { display:none; }
  body.admin-framed-shell .flatpickr-calendar { max-width:calc(100vw - 16px); }
}
@media screen and (max-width: 380px) {
  body.admin-framed-shell > .top-navbar { gap:4px; padding-inline:6px; }
  body.admin-framed-shell .admin-frame-brand { gap:4px; }
  body.admin-framed-shell .admin-frame-ustp-logo { width:36px; height:40px; flex-basis:36px; }
  body.admin-framed-shell .admin-frame-logo { width:24px; flex-basis:24px; }
  body.admin-framed-shell .top-navbar .top-navbar-actions { gap:0; }
  body.admin-framed-shell .content-area .card-body { padding:12px; }
}
@media (prefers-reduced-motion: reduce) {
  body.admin-framed-shell :is(.main-content,.card,.btn,.nav-link) { transition:none !important; }
}
'@
[IO.File]::AppendAllText($cssPath, $rules, [Text.UTF8Encoding]::new($false))
Get-ChildItem -LiteralPath $webRoot -Filter '*.html' | ForEach-Object {
  $original = [IO.File]::ReadAllText($_.FullName)
  if ($original -notmatch 'admin_mobile.css') { return }
  $updated = $original -replace 'admin_mobile\.css\?v=[^"\s]+', 'admin_mobile.css?v=20261031-all-pages5'
  if ($updated -notmatch 'admin_viewport.js') {
    $updated = [regex]::Replace($updated, '(<meta name="viewport"[^>]*>)', '$1' + "`r`n" + '    <script src="/static/org_elecom/elecom_admin/admin_components/admin_js/admin_viewport.js?v=20261031-phone1"></script>')
  }
  [IO.File]::WriteAllText($_.FullName, $updated, [Text.UTF8Encoding]::new($false))
}
