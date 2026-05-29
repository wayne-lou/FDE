let scene, camera, renderer, initialized = false;
let opsGroup, routeGroup, pulseDots = [];
let lastDashboard = null;

function makeTextSprite(text, color = '#dff3ff', size = 56) {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  ctx.font = `700 ${size}px Arial`;
  const w = Math.max(256, ctx.measureText(text).width + 40);
  canvas.width = w; canvas.height = 96;
  ctx.font = `700 ${size}px Arial`;
  ctx.fillStyle = 'rgba(4,12,24,.72)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = 'rgba(69,213,255,.55)';
  ctx.strokeRect(2, 2, canvas.width - 4, canvas.height - 4);
  ctx.fillStyle = color;
  ctx.fillText(text, 20, 64);
  const tex = new THREE.CanvasTexture(canvas);
  const mat = new THREE.SpriteMaterial({ map: tex, transparent: true });
  const sp = new THREE.Sprite(mat);
  sp.scale.set(w / 160, 0.6, 1);
  return sp;
}

function addBox(name, x, z, w, d, h, color = 0x123b5d) {
  const geo = new THREE.BoxGeometry(w, h, d);
  const mat = new THREE.MeshStandardMaterial({ color, metalness: .15, roughness: .45 });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(x, h / 2, z);
  mesh.userData = { name };
  opsGroup.add(mesh);
  const label = makeTextSprite(name, '#dff3ff', 42);
  label.position.set(x, h + .55, z);
  opsGroup.add(label);
  return mesh;
}

function addLine(x1, z1, x2, z2, color = 0x45d5ff) {
  const mat = new THREE.LineBasicMaterial({ color, transparent: true, opacity: .75 });
  const pts = [new THREE.Vector3(x1, .08, z1), new THREE.Vector3(x2, .08, z2)];
  const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), mat);
  routeGroup.add(line);
  return line;
}

function addStatusDot(label, x, z, risk = 'low', detail = '') {
  const colors = {critical:0xff1744, high:0xff8a00, medium:0xffd600, low:0x52f6ff, normal:0x7cffb2};
  const color = colors[String(risk || '').toLowerCase()] || colors.low;
  const geo = new THREE.SphereGeometry(.34, 32, 32);
  const mat = new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: .85 });
  const dot = new THREE.Mesh(geo, mat);
  dot.position.set(x, 1.25, z);
  dot.userData = { label, risk, detail };
  opsGroup.add(dot);
  pulseDots.push(dot);
  const sp = makeTextSprite(label, risk === 'high' || risk === 'critical' ? '#ffd7d7' : '#dff3ff', 38);
  sp.position.set(x, 2.0, z);
  opsGroup.add(sp);
  return dot;
}

function initThree() {
  const container = document.getElementById('threeCanvas');
  if (!container) return;
  if (typeof THREE === 'undefined') {
    container.innerHTML = '<div class="three-fallback">Three.js was not loaded. Check internet/CDN access or use a local three.min.js file.</div>';
    return;
  }
  container.innerHTML = '';
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x050b14);
  const w = Math.max(container.clientWidth, 400);
  const h = Math.max(container.clientHeight, 360);
  camera = new THREE.PerspectiveCamera(58, w / h, 0.1, 1000);
  camera.position.set(7.5, 8.2, 12.5);
  camera.lookAt(0, 0, 0);
  renderer = new THREE.WebGLRenderer({ antialias:true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(w, h);
  container.appendChild(renderer.domElement);

  scene.add(new THREE.AmbientLight(0x88aadd, .8));
  const light = new THREE.PointLight(0xffffff, 1.3);
  light.position.set(10, 16, 10);
  scene.add(light);

  const grid = new THREE.GridHelper(18, 18, 0x1f6f9e, 0x16324f);
  scene.add(grid);

  opsGroup = new THREE.Group();
  routeGroup = new THREE.Group();
  scene.add(routeGroup);
  scene.add(opsGroup);
  buildOperationsRoom();
  initialized = true;
  animate();
  window.addEventListener('resize', resizeThree);
}

function clearGroup(g) { if (!g) return; while (g.children.length) g.remove(g.children[0]); }

function buildOperationsRoom(dashboard, plan) {
  if (!opsGroup || !routeGroup) return;
  clearGroup(opsGroup); clearGroup(routeGroup); pulseDots = [];

  // Business meaning: Race-weekend operations room, not random decoration.
  addBox('Garage', -3.8, 0, 2.1, 2.0, 1.7, 0x123b5d);
  addBox('Engineering', -1.1, 2.8, 2.2, 1.7, 1.3, 0x153f66);
  addBox('Media', 2.7, 2.5, 2.0, 1.6, 1.2, 0x17314d);
  addBox('Recovery', 3.8, -1.2, 2.3, 1.8, 1.35, 0x104b54);
  addBox('Hotel', .6, -3.4, 2.4, 1.8, 1.45, 0x142c4a);
  addBox('Transport', -3.2, -3.0, 2.0, 1.4, 1.05, 0x183450);

  // Default operational routes.
  addLine(-3.8, 0, -1.1, 2.8, 0x2b8cbe);
  addLine(-1.1, 2.8, 2.7, 2.5, 0x2b8cbe);
  addLine(2.7, 2.5, 3.8, -1.2, 0x2b8cbe);
  addLine(3.8, -1.2, .6, -3.4, 0x2b8cbe);
  addLine(.6, -3.4, -3.2, -3.0, 0x2b8cbe);
  addLine(-3.2, -3.0, -3.8, 0, 0x2b8cbe);

  const fatigue = (dashboard && dashboard.fatigue) || [];
  if (fatigue.length) {
    fatigue.slice(0, 2).forEach((f, i) => {
      const risk = String(f.risk_level || 'low').toLowerCase();
      const x = i === 0 ? -3.8 : -2.4;
      const z = i === 0 ? 1.65 : -1.55;
      addStatusDot(`${f.driver_name}: ${f.fatigue_score}`, x, z, risk, f.assessment_summary || '');
    });
  } else {
    addStatusDot('Driver A', -3.8, 1.65, 'medium');
    addStatusDot('Driver B', -2.4, -1.55, 'low');
  }

  // Agent plan should change the 3D picture: highlight affected operational route.
  if (plan) {
    const title = String(plan.answer_title || plan.summary || '').toLowerCase();
    let route = ['Garage', 'Recovery', 'Hotel'];
    let coords = [[-3.8,0],[3.8,-1.2],[.6,-3.4]];
    if (title.includes('meeting') || title.includes('briefing')) { route = ['Garage','Engineering','Recovery']; coords = [[-3.8,0],[-1.1,2.8],[3.8,-1.2]]; }
    if (title.includes('media')) { route = ['Garage','Media','Recovery']; coords = [[-3.8,0],[2.7,2.5],[3.8,-1.2]]; }
    if (title.includes('logistics') || title.includes('travel') || title.includes('hotel')) { route = ['Garage','Transport','Hotel','Recovery']; coords = [[-3.8,0],[-3.2,-3.0],[.6,-3.4],[3.8,-1.2]]; }
    for (let i=0;i<coords.length-1;i++) addLine(coords[i][0], coords[i][1], coords[i+1][0], coords[i+1][1], 0x55ffbb);
    coords.forEach((c, i) => addStatusDot(i === 0 ? 'Agent Start' : route[i], c[0], c[1], i === 0 ? (plan.risk_level || 'high') : 'normal'));
    const banner = makeTextSprite('AI workflow: ' + route.join(' → '), '#7cffb2', 34);
    banner.position.set(0, 3.1, -5.0);
    opsGroup.add(banner);
  } else {
    const banner = makeTextSprite('DriverOps Digital Twin: driver risk + schedule + recovery workflow', '#7cffb2', 30);
    banner.position.set(0, 3.1, -5.0);
    opsGroup.add(banner);
  }
}

function resizeThree() {
  const container = document.getElementById('threeCanvas');
  if (!container || !renderer || !camera) return;
  const w = Math.max(container.clientWidth, 400);
  const h = Math.max(container.clientHeight, 360);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h);
}

function renderDeviceScene(fatigue, readings) {
  lastDashboard = { fatigue: fatigue || [], recent_readings: readings || [] };
  if (!initialized) initThree();
  buildOperationsRoom(lastDashboard, null);
}

function renderAgentPlanScene(plan) {
  if (!initialized) initThree();
  buildOperationsRoom(lastDashboard || {}, plan);
}

function animate() {
  requestAnimationFrame(animate);
  if (!scene || !renderer || !camera) return;
  const t = Date.now() * 0.004;
  pulseDots.forEach((d, i) => {
    const s = 1 + Math.sin(t + i) * .18;
    d.scale.set(s, s, s);
  });
  scene.rotation.y = Math.sin(Date.now() * 0.00035) * 0.08;
  renderer.render(scene, camera);
}

window.renderDeviceScene = renderDeviceScene;
window.renderAgentPlanScene = renderAgentPlanScene;
