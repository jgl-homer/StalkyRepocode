/**
 * STAKLY — Core Application Logic (v2 - Fixed)
 * Ported from Flutter to Web (PWA)
 */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import { 
  getAuth, 
  onAuthStateChanged, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword, 
  signOut, 
  sendEmailVerification, 
  sendPasswordResetEmail,
  reauthenticateWithCredential,
  EmailAuthProvider,
  updatePassword
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import { 
  getFirestore, 
  doc, 
  getDoc, 
  setDoc, 
  addDoc, 
  collection, 
  onSnapshot, 
  query, 
  orderBy, 
  updateDoc, 
  deleteDoc, 
  serverTimestamp,
  Timestamp
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

// ── Firebase Configuration ──────────────────────────────────
const firebaseConfig = {
  apiKey:            "AIzaSyCf9kfwpoXH5yqnr643vm4gQxXK3Sexb_Q",
  authDomain:        "to-do-taskingcheck.firebaseapp.com",
  projectId:         "to-do-taskingcheck",
  storageBucket:     "to-do-taskingcheck.firebasestorage.app",
  messagingSenderId: "540678482428",
  appId:             "1:540678482428:web:824c1ff93834dba0f56a79"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// ── State ────────────────────────────────────────────────────
let currentUser = null;
let userData = null;
let tasks = [];
let activePage = 'home';
let selectedAgendaDate = new Date();
let unsubTasks = null;

const state = {
  category: 'Trabajo',
  date: new Date(),
  time: { hour: 8, minute: 0 },
  priority: 'media',
  subtasks: []
};

// ── App Initialization ───────────────────────────────────────
onAuthStateChanged(auth, async (user) => {
  if (user) {
    currentUser = user;
    if (user.emailVerified) {
      await loadUserData();
      showScreen('appScreen');
      switchPage('home');
      startTasksListener();
    } else {
      showAuthCard('verifyCard');
      showScreen('authScreen');
    }
  } else {
    currentUser = null;
    userData = null;
    stopTasksListener();
    showAuthCard('loginCard');
    showScreen('authScreen');
  }
});

async function loadUserData() {
  try {
    const userDoc = await getDoc(doc(db, "users", currentUser.uid));
    if (userDoc.exists()) {
      userData = userDoc.data();
      document.getElementById('topbarGreeting').textContent = `Hola, ${userData.name?.split(' ')[0] || 'Usuario'}`;
      document.getElementById('homeGreeting').textContent = `Hola, ${userData.name?.split(' ')[0] || 'Usuario'}`;
    }
  } catch (e) { console.error("Error loading user data:", e); }
}

// ── Routing / Screen Management ──────────────────────────────
window.showScreen = (id) => {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById(id).classList.add('active');
};

window.switchPage = (pageId) => {
  activePage = pageId;
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.getElementById(`page${capitalize(pageId)}`).classList.add('active');
  
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById(`nav${capitalize(pageId)}`).classList.add('active');
  
  if (pageId === 'agenda') renderAgenda();
  if (pageId === 'stats') renderStats();
  if (pageId === 'profile') renderProfile();
};

function showAuthCard(id) {
  document.querySelectorAll('.auth-card').forEach(c => c.classList.add('hidden'));
  document.getElementById(id).classList.remove('hidden');
}

window.showLogin = () => showAuthCard('loginCard');
window.showRegister = () => showAuthCard('registerCard');

// ── Auth Logic ───────────────────────────────────────────────
window.doLogin = async () => {
  const email = document.getElementById('loginEmail').value.trim();
  const pass = document.getElementById('loginPassword').value;
  const errBox = document.getElementById('loginError');
  const btn = document.getElementById('loginBtn');

  if (!email || !pass) return showToast("⚠️ Completa todos los campos");

  btn.disabled = true;
  errBox.classList.add('hidden');

  try {
    const cred = await signInWithEmailAndPassword(auth, email, pass);
    await cred.user.reload();
    if (!cred.user.emailVerified) {
      await sendEmailVerification(cred.user);
      showAuthCard('verifyCard');
    }
  } catch (err) {
    errBox.textContent = (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') 
      ? "Credenciales incorrectas" : err.message;
    errBox.classList.remove('hidden');
  } finally {
    btn.disabled = false;
  }
};

window.doRegister = async () => {
  const name = document.getElementById('regName').value.trim();
  const email = document.getElementById('regEmail').value.trim();
  const pass = document.getElementById('regPassword').value;
  const errBox = document.getElementById('registerError');
  const btn = document.getElementById('registerBtn');

  if (!name || !email || !pass) return showToast("⚠️ Completa todos los campos");
  if (pass.length < 6) return showToast("⚠️ Mínimo 6 caracteres");

  btn.disabled = true;
  errBox.classList.add('hidden');

  try {
    const cred = await createUserWithEmailAndPassword(auth, email, pass);
    await setDoc(doc(db, "users", cred.user.uid), { name, email });
    await sendEmailVerification(cred.user);
    showAuthCard('verifyCard');
  } catch (err) {
    errBox.textContent = err.message;
    errBox.classList.remove('hidden');
  } finally {
    btn.disabled = false;
  }
};

window.checkVerification = () => {
  if (!auth.currentUser) return;
  auth.currentUser.reload().then(() => {
    if (auth.currentUser.emailVerified) {
      window.location.reload();
    } else {
      showToast("⚠️ El correo aún no ha sido verificado");
    }
  });
};

window.resendVerification = async () => {
  try {
    await sendEmailVerification(auth.currentUser);
    showToast("📧 Correo de verificación enviado");
  } catch (err) {
    showToast("❌ Error al enviar correo");
  }
};

window.doLogout = () => signOut(auth);

window.resetPassword = async () => {
  const email = document.getElementById('loginEmail').value.trim() || prompt("Ingresa tu correo:");
  if (!email) return;
  try {
    await sendPasswordResetEmail(auth, email);
    showToast("📧 Enlace de recuperación enviado");
  } catch (e) { showToast("❌ Error: " + e.message); }
};

// ── Firestore Logic ──────────────────────────────────────────
function startTasksListener() {
  if (!currentUser) return;
  const q = query(collection(db, "users", currentUser.uid, "tasks"), orderBy("dueDate", "asc"));
  unsubTasks = onSnapshot(q, (snapshot) => {
    tasks = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    renderHome();
    if (activePage === 'agenda') renderAgenda();
    if (activePage === 'stats') renderStats();
  }, (err) => {
    console.error("Firestore listener error:", err);
    if(err.code === 'permission-denied') showToast("🔒 Error de permisos en Firestore");
  });
}

function stopTasksListener() {
  if (unsubTasks) unsubTasks();
}

// ── Task Management ──────────────────────────────────────────
let currentEditingId = null;

window.openAddTask = () => {
  currentEditingId = null;
  document.getElementById('modalTitle').textContent = "Crear Recordatorio";
  document.getElementById('taskTitleInput').value = "";
  document.getElementById('taskDescInput').value = "";
  
  state.category = 'Trabajo';
  state.date = new Date();
  state.time = { hour: new Date().getHours() + 1, minute: 0 };
  state.priority = 'media';
  state.subtasks = [];

  renderCategoryChips();
  renderDatePills();
  renderTimePills();
  renderPriorityChips();
  renderSubtasks();
  document.getElementById('taskModal').classList.remove('hidden');
};

window.editTask = (id) => {
  const task = tasks.find(t => t.id === id);
  if (!task) return;
  currentEditingId = id;
  document.getElementById('modalTitle').textContent = "Editar Recordatorio";
  document.getElementById('taskTitleInput').value = task.title;
  document.getElementById('taskDescInput').value = task.description || "";
  
  state.category = task.materia;
  const d = task.dueDate.toDate();
  state.date = d;
  state.time = { hour: d.getHours(), minute: d.getMinutes() };
  state.priority = task.priority || 'media';
  state.subtasks = task.subtasks || [];
  
  renderCategoryChips();
  renderDatePills();
  renderTimePills();
  renderPriorityChips();
  renderSubtasks();
  document.getElementById('taskModal').classList.remove('hidden');
};

function renderSubtasks() {
  const list = document.getElementById('subtasksList');
  list.innerHTML = state.subtasks.map((s, i) => `
    <div style="display:flex; align-items:center; gap:10px; margin-bottom:8px">
      <div class="task-checkbox-custom ${s.completed ? 'checked' : ''}" style="width:20px;height:20px" onclick="toggleSubtask(${i})"></div>
      <span style="flex:1; font-size:14px; ${s.completed ? 'text-decoration:line-through;color:var(--text-muted)' : ''}">${s.title}</span>
      <button onclick="removeSubtask(${i})" style="background:none;border:none;color:var(--accent-red);cursor:pointer">✕</button>
    </div>
  `).join('');
}

window.addSubtask = () => {
  const input = document.getElementById('newSubtaskInput');
  const title = input.value.trim();
  if (!title) return;
  state.subtasks.push({ title, completed: false });
  input.value = "";
  renderSubtasks();
};

window.toggleSubtask = (index) => {
  state.subtasks[index].completed = !state.subtasks[index].completed;
  renderSubtasks();
};

window.removeSubtask = (index) => {
  state.subtasks.splice(index, 1);
  renderSubtasks();
};

function renderCategoryChips() {
  const cats = ['Escuela', 'Trabajo', 'Pagos', 'Personal', 'General'];
  const row = document.getElementById('categoryChips');
  row.innerHTML = cats.map(c => `
    <div class="chip ${state.category === c ? 'active' : ''}" onclick="setTaskCategory('${c}')">${c}</div>
  `).join('');
}
window.setTaskCategory = (c) => { state.category = c; renderCategoryChips(); };

function renderDatePills() {
  const row = document.getElementById('datePills');
  const days = [];
  for(let i=0; i<7; i++) {
    const d = new Date(); d.setDate(d.getDate() + i);
    days.push(d);
  }
  row.innerHTML = days.map(d => `
    <div class="pill ${isSameDay(d, state.date) ? 'active' : ''}" onclick="setTaskDate(${d.getTime()})">
      <div class="pill-sm">${d.toLocaleDateString('es', {weekday: 'short'})}</div>
      <div class="pill-lg">${d.getDate()}</div>
    </div>
  `).join('');
}
window.setTaskDate = (ts) => { state.date = new Date(ts); renderDatePills(); };

function renderTimePills() {
  const row = document.getElementById('timePills');
  const times = [{h:8, m:0}, {h:10, m:0}, {h:12, m:0}, {h:15, m:0}, {h:18, m:0}, {h:20, m:0}];
  row.innerHTML = times.map(t => {
    const isSel = state.time.hour === t.h && state.time.minute === t.m;
    return `
      <div class="pill ${isSel ? 'active' : ''}" onclick="setTaskTime(${t.h}, ${t.m})">
        <div class="pill-lg">${t.h}:${t.m === 0 ? '00' : t.m}</div>
        <div class="pill-sm">${t.h >= 12 ? 'PM' : 'AM'}</div>
      </div>
    `;
  }).join('');
}
window.setTaskTime = (h, m) => { state.time = {hour:h, minute:m}; renderTimePills(); };

function renderPriorityChips() {
  const priorities = ['baja', 'media', 'alta'];
  const row = document.getElementById('priorityChips');
  row.innerHTML = priorities.map(p => `
    <div class="chip ${state.priority === p ? 'active' : ''}" onclick="setTaskPriority('${p}')">${capitalize(p)}</div>
  `).join('');
}
window.setTaskPriority = (p) => { state.priority = p; renderPriorityChips(); };

window.saveTask = async () => {
  const title = document.getElementById('taskTitleInput').value.trim();
  const desc = document.getElementById('taskDescInput').value.trim();
  if (!title) return showToast("⚠️ Escribe un título");

  const dueDate = new Date(state.date);
  dueDate.setHours(state.time.hour, state.time.minute, 0, 0);

  const data = {
    title,
    description: desc,
    materia: state.category,
    priority: state.priority,
    subtasks: state.subtasks,
    dueDate: Timestamp.fromDate(dueDate),
    completed: false,
    updatedAt: serverTimestamp()
  };

  try {
    if (currentEditingId) {
      await updateDoc(doc(db, "users", currentUser.uid, "tasks", currentEditingId), data);
      showToast("✅ Tarea actualizada");
    } else {
      data.createdAt = serverTimestamp();
      await addDoc(collection(db, "users", currentUser.uid, "tasks"), data);
      showToast("✅ Tarea guardada");
    }
    closeModal();
  } catch (err) { showToast("❌ Error al guardar"); }
};

window.toggleTask = async (id, current) => {
  try {
    await updateDoc(doc(db, "users", currentUser.uid, "tasks", id), { completed: !current });
  } catch(e) { console.error(e); }
};

window.deleteTask = async (id) => {
  if (confirm("¿Eliminar esta tarea?")) {
    await deleteDoc(doc(db, "users", currentUser.uid, "tasks", id));
    showToast("🗑️ Tarea eliminada");
  }
};

window.closeModal = () => document.getElementById('taskModal').classList.add('hidden');
window.closeModalOutside = (e) => { if(e.target.id === 'taskModal') closeModal(); };

// ── Rendering Home ───────────────────────────────────────────
function renderHome() {
  const pending = tasks.filter(t => !t.completed);
  document.getElementById('homePendingCount').textContent = `${pending.length} TAREAS PENDIENTES`;
  
  const todayList = document.getElementById('todayList');
  const upcomingList = document.getElementById('upcomingList');
  const empty = document.getElementById('homeEmpty');
  const loading = document.getElementById('homeLoading');
  
  loading.classList.add('hidden');
  
  if (tasks.length === 0) {
    empty.classList.remove('hidden');
    document.getElementById('todaySection').classList.add('hidden');
    document.getElementById('upcomingSection').classList.add('hidden');
    return;
  }
  
  empty.classList.add('hidden');
  
  const todayTasks = tasks.filter(t => !t.completed && isPastOrToday(t.dueDate.toDate()));
  const upcomingTasks = tasks.filter(t => !t.completed && !isPastOrToday(t.dueDate.toDate()));
  
  renderTaskList(todayTasks, todayList);
  renderTaskList(upcomingTasks, upcomingList);
  
  document.getElementById('todaySection').classList.toggle('hidden', todayTasks.length === 0);
  document.getElementById('upcomingSection').classList.toggle('hidden', upcomingTasks.length === 0);
  document.getElementById('todayCount').textContent = todayTasks.length;
  document.getElementById('upcomingCount').textContent = upcomingTasks.length;
}

function renderTaskList(list, container) {
  container.innerHTML = list.map(t => {
    const date = t.dueDate.toDate();
    const timeStr = date.toLocaleTimeString('es', {hour:'2-digit', minute:'2-digit'});
    return `
      <div class="task-card" style="border-left-color: ${getCatColor(t.materia)}">
        <div class="task-checkbox-custom" onclick="toggleTask('${t.id}', false)"></div>
        <div class="task-content" onclick="editTask('${t.id}')">
          <div class="task-title">${t.title}</div>
          ${t.description ? `<div class="task-desc">${t.description}</div>` : ''}
          <div class="task-meta">
            <span>${t.materia}</span> • <span>${timeStr}</span>
            <span class="task-priority-badge badge-${t.priority}">${t.priority.toUpperCase()}</span>
          </div>
        </div>
        <button class="pomo-btn-mini" onclick="event.stopPropagation(); startPomodoro('${t.title}')">⏱️</button>
      </div>
    `;
  }).join('');
}

// ── Rendering Agenda ─────────────────────────────────────────
function renderAgenda() {
  const selector = document.getElementById('daySelector');
  const days = [];
  for(let i=-3; i<=3; i++) {
    const d = new Date(); d.setDate(d.getDate() + i);
    days.push(d);
  }
  
  selector.innerHTML = days.map(d => `
    <div class="day-pill ${isSameDay(d, selectedAgendaDate) ? 'active' : ''}" onclick="setAgendaDate(${d.getTime()})">
      <div class="day-name">${d.toLocaleDateString('es', {weekday: 'short'})}</div>
      <div class="day-num">${d.getDate()}</div>
    </div>
  `).join('');
  
  document.getElementById('selectedDateLabel').textContent = selectedAgendaDate.toLocaleDateString('es', {month:'long', day:'numeric', year:'numeric'});
  
  const list = document.getElementById('agendaList');
  const dayTasks = tasks.filter(t => isSameDay(t.dueDate.toDate(), selectedAgendaDate));
  
  if (dayTasks.length === 0) {
    list.innerHTML = "";
    document.getElementById('agendaEmpty').classList.remove('hidden');
  } else {
    document.getElementById('agendaEmpty').classList.add('hidden');
    list.innerHTML = dayTasks.map(t => {
      const timeStr = t.dueDate.toDate().toLocaleTimeString('es', {hour:'2-digit', minute:'2-digit'});
      return `
        <div class="task-card ${t.completed ? 'completed' : ''}" style="border-left-color: ${getCatColor(t.materia)}">
          <div class="task-content">
            <div style="display:flex; align-items:center; gap:10px">
               <span style="font-weight:800; color:white; min-width:60px">${timeStr}</span>
               <div style="width:1px; height:20px; background:rgba(255,255,255,0.1)"></div>
               <div>
                 <div class="task-title">${t.title}</div>
                 <div class="task-meta">${t.materia}</div>
               </div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }
}
window.setAgendaDate = (ts) => { selectedAgendaDate = new Date(ts); renderAgenda(); };

// ── Rendering Stats ──────────────────────────────────────────
function renderStats() {
  const total = tasks.length;
  const completed = tasks.filter(t => t.completed).length;
  const score = total === 0 ? 0 : Math.round((completed / total) * 100);
  
  document.getElementById('ringScore').textContent = score;
  document.getElementById('statTotal').textContent = total;
  document.getElementById('statDone').textContent = completed;
  document.getElementById('statPending').textContent = total - completed;
  
  const offset = 565.49 - (565.49 * score / 100);
  document.getElementById('ringFill').style.strokeDashoffset = offset;
  
  let label = "Sin completar";
  if(score >= 80) label = "Excelente";
  else if(score >= 60) label = "Bien";
  else if(score >= 40) label = "Regular";
  else if(score > 0) label = "En progreso";
  document.getElementById('ringLabel').textContent = label;
  
  const todayTasks = tasks.filter(t => isSameDay(t.dueDate.toDate(), new Date()));
  const todayDone = todayTasks.filter(t => t.completed).length;
  const todayTotal = todayTasks.length;
  const todayPct = todayTotal === 0 ? 0 : (todayDone / todayTotal) * 100;
  
  document.getElementById('todayProgressLabel').textContent = `${todayDone}/${todayTotal}`;
  document.getElementById('todayProgressBar').style.width = `${todayPct}%`;
  document.getElementById('todayProgressNote').textContent = todayTotal === 0 ? 'No hay tareas para hoy' : (todayDone === todayTotal ? '✅ ¡Todo listo!' : `${todayTotal-todayDone} pendiente(s)`);

  const catStats = {};
  tasks.forEach(t => { catStats[t.materia] = (catStats[t.materia] || 0) + 1; });
  
  const breakdown = document.getElementById('catBreakdown');
  breakdown.innerHTML = '<p class="field-label">Distribución</p>' + Object.entries(catStats).map(([cat, count]) => {
    const catDoneCount = tasks.filter(t => t.materia === cat && t.completed).length;
    const pct = (catDoneCount / count) * 100;
    return `
      <div style="margin-bottom:15px">
        <div style="display:flex; justify-content:space-between; font-size:12px; margin-bottom:5px">
          <span>${cat}</span>
          <span>${catDoneCount}/${count}</span>
        </div>
        <div class="progress-bar-wrap" style="height:8px; background:rgba(255,255,255,0.05); border-radius:4px; overflow:hidden">
          <div class="progress-bar-fill" style="width:${pct}%; background:${getCatColor(cat)}; height:100%"></div>
        </div>
      </div>
    `;
  }).join('');
}

// ── Rendering Profile ────────────────────────────────────────
function renderProfile() {
  document.getElementById('profileName').textContent = userData?.name || 'Usuario';
  document.getElementById('profileEmail').textContent = auth.currentUser.email;
  document.getElementById('profileNameInput').value = userData?.name || '';
}

window.saveProfile = async () => {
  const newName = document.getElementById('profileNameInput').value.trim();
  const currentPw = document.getElementById('profileCurrentPw').value;
  const newPw = document.getElementById('profileNewPw').value;
  const errBox = document.getElementById('profileError');
  
  if (!newName) return showToast("⚠️ El nombre es requerido");
  
  errBox.classList.add('hidden');
  try {
    if (newName !== userData.name) {
      await updateDoc(doc(db, "users", currentUser.uid), { name: newName });
      userData.name = newName;
      showToast("✅ Nombre actualizado");
    }
    
    if (newPw) {
      if (!currentPw) throw new Error("Se requiere contraseña actual");
      const credential = EmailAuthProvider.credential(auth.currentUser.email, currentPw);
      await reauthenticateWithCredential(auth.currentUser, credential);
      await updatePassword(auth.currentUser, newPw);
      showToast("✅ Contraseña actualizada");
    }
    loadUserData();
  } catch (err) {
    errBox.textContent = err.message;
    errBox.classList.remove('hidden');
  }
};

window.confirmDeleteAccount = () => {
  if (confirm("⚠️ ¿ESTÁS SEGURO? Se eliminarán todos tus datos.")) {
    showToast("Función no disponible en demo");
  }
};

// ── Pomodoro Logic ───────────────────────────────────────────
let pomoTimer = null;
let pomoSeconds = 25 * 60;
let pomoActive = false;
let pomoState = 'CONCENTRACIÓN';
const FOCUS_TIME = 25 * 60;
const BREAK_TIME = 5 * 60;

window.startPomodoro = (taskTitle) => {
  document.getElementById('pomoTask').textContent = taskTitle;
  pomoSeconds = FOCUS_TIME;
  pomoState = 'CONCENTRACIÓN';
  updatePomoUI();
  document.getElementById('pomodoroModal').classList.remove('hidden');
};

window.togglePomodoro = () => {
  if (pomoActive) {
    clearInterval(pomoTimer);
    pomoActive = false;
    document.getElementById('pomoPlayBtn').textContent = '▶';
  } else {
    pomoActive = true;
    document.getElementById('pomoPlayBtn').textContent = 'Ⅱ';
    pomoTimer = setInterval(() => {
      pomoSeconds--;
      if (pomoSeconds <= 0) {
        clearInterval(pomoTimer);
        pomoActive = false;
        playAlarm();
        skipPomodoro();
      }
      updatePomoUI();
    }, 1000);
  }
};

window.resetPomodoro = () => {
  clearInterval(pomoTimer);
  pomoActive = false;
  pomoSeconds = pomoState === 'CONCENTRACIÓN' ? FOCUS_TIME : BREAK_TIME;
  document.getElementById('pomoPlayBtn').textContent = '▶';
  updatePomoUI();
};

window.skipPomodoro = () => {
  pomoState = pomoState === 'CONCENTRACIÓN' ? 'DESCANSO' : 'CONCENTRACIÓN';
  pomoSeconds = pomoState === 'CONCENTRACIÓN' ? FOCUS_TIME : BREAK_TIME;
  updatePomoUI();
};

function updatePomoUI() {
  const m = Math.floor(pomoSeconds / 60);
  const s = pomoSeconds % 60;
  document.getElementById('pomoTime').textContent = `${m}:${s < 10 ? '0'+s : s}`;
  document.getElementById('pomoState').textContent = pomoState;
  
  const total = pomoState === 'CONCENTRACIÓN' ? FOCUS_TIME : BREAK_TIME;
  const offset = 691.15 * (1 - pomoSeconds / total);
  document.getElementById('pomoFill').style.strokeDashoffset = offset;
  document.getElementById('pomoFill').style.stroke = pomoState === 'CONCENTRACIÓN' ? '#00ffff' : '#D4AF37';
}

window.closePomodoro = () => {
  clearInterval(pomoTimer);
  pomoActive = false;
  document.getElementById('pomodoroModal').classList.add('hidden');
};
window.closePomodoroOutside = (e) => { if(e.target.id === 'pomodoroModal') closePomodoro(); };

function playAlarm() {
  try {
    const audio = new Audio('https://actions.google.com/sounds/v1/alarms/beep_short.ogg');
    audio.play();
  } catch(e) {}
}

// ── Helpers ──────────────────────────────────────────────────
function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
function isSameDay(d1, d2) {
  return d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate();
}
function isPastOrToday(d) {
  const today = new Date(); today.setHours(0,0,0,0);
  const date = new Date(d); date.setHours(0,0,0,0);
  return date <= today;
}
function getCatColor(cat) {
  const c = cat.toLowerCase();
  if (c.includes('escuela')) return '#4d94ff';
  if (c.includes('trabajo')) return '#ff944d';
  if (c.includes('pagos')) return '#ff4d4d';
  if (c.includes('personal')) return '#4dff88';
  return '#D4AF37';
}

window.showToast = (msg) => {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.remove('hidden');
  t.classList.add('show');
  setTimeout(() => {
    t.classList.remove('show');
    setTimeout(() => t.classList.add('hidden'), 400);
  }, 3000);
};

// ── PWA Service Worker ───────────────────────────────────────
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js');
}
