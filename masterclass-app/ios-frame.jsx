// ios-frame.jsx - frameless full-bleed device wrapper (no bezel / notch / home bar).
// Renders app screen content edge-to-edge. Mobile CSS in index.html makes it fill the viewport.
function IOSDevice(props){
  var children = props && props.children;
  var dark = props && props.dark;
  return (
    <div data-om-starter="ios-frame" style={{
      width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: dark ? '#0e0c0a' : '#F2F2F7',
      fontFamily: '-apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased',
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ flex: 1, minHeight: 0, overflow: 'auto', WebkitOverflowScrolling: 'touch' }}>
        {children}
      </div>
    </div>
  );
}
function IOSStatusBar(){ return null; }
function IOSNavBar(){ return null; }
function IOSGlassPill(p){ return (p && p.children) || null; }
function IOSList(p){ return (p && p.children) || null; }
function IOSListRow(){ return null; }
function IOSKeyboard(){ return null; }
Object.assign(window, { IOSDevice, IOSStatusBar, IOSNavBar, IOSGlassPill, IOSList, IOSListRow, IOSKeyboard });
