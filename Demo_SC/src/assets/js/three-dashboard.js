let scene, camera, renderer, initialized = false, alertGroup, pulseDots = [];

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
  camera = new THREE.PerspectiveCamera(60, w / h, 0.1, 1000);
  camera.position.set(8, 7, 12);
  camera.lookAt(0, 0, 0);
  renderer = new THREE.WebGLRenderer({antialias:true});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(w, h);
  container.appendChild(renderer.domElement);

  scene.add(new THREE.AmbientLight(0x88aadd, .75));
  const light = new THREE.PointLight(0xffffff, 1.2);
  light.position.set(10, 16, 10);
  scene.add(light);

  const grid = new THREE.GridHelper(20, 20, 0x1f6f9e, 0x16324f);
  scene.add(grid);

  // simple smart-city blocks
  for (let i = 0; i < 10; i++) {
    const hgt = 1.2 + (i % 4) * .7;
    const geo = new THREE.BoxGeometry(1.15, hgt, 1.15);
    const mat = new THREE.MeshStandardMaterial({color: 0x123b5d, metalness:.2, roughness:.45});
    const b = new THREE.Mesh(geo, mat);
    b.position.set((i % 5) * 2.2 - 4.4, hgt / 2, Math.floor(i / 5) * 3 - 1.6);
    scene.add(b);
  }

  alertGroup = new THREE.Group();
  scene.add(alertGroup);
  initialized = true;
  animate();
  window.addEventListener('resize', resizeThree);
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

function renderDeviceScene(alerts, readings) {
  if (!initialized) initThree();
  if (!alertGroup) return;
  while (alertGroup.children.length) alertGroup.remove(alertGroup.children[0]);
  pulseDots = [];
  const colors = {critical:0xff1744, high:0xff8a00, medium:0xffd600, low:0x45d5ff};
  const items = (alerts && alerts.length ? alerts : [
    {alert_level:'low'}, {alert_level:'medium'}, {alert_level:'high'}
  ]);
  items.forEach((a, idx) => {
    const color = colors[String(a.alert_level || '').toLowerCase()] || 0x45d5ff;
    const geo = new THREE.SphereGeometry(.28, 24, 24);
    const mat = new THREE.MeshStandardMaterial({color, emissive: color, emissiveIntensity:.85});
    const dot = new THREE.Mesh(geo, mat);
    dot.position.set((idx % 5) * 2.2 - 4.4, 2.2 + (idx % 3) * .6, Math.floor(idx / 5) * 2.5 - 1.2);
    alertGroup.add(dot);
    pulseDots.push(dot);
  });
}

function animate() {
  requestAnimationFrame(animate);
  if (!scene || !renderer || !camera) return;
  const t = Date.now() * 0.004;
  pulseDots.forEach((d, i) => {
    const s = 1 + Math.sin(t + i) * .18;
    d.scale.set(s, s, s);
  });
  scene.rotation.y += 0.001;
  renderer.render(scene, camera);
}

window.renderDeviceScene = renderDeviceScene;
