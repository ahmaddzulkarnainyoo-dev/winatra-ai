const firebaseConfig = {
    apiKey: "AIzaSyCMrV3EJOfcxJa27_wcaXGd7G3HrHaPOl0",
    authDomain: "winatra-ai-de4f8.firebaseapp.com",
    databaseURL: "https://winatra-ai-de4f8-default-rtdb.asia-southeast1.firebasedatabase.app",
    projectId: "winatra-ai-de4f8",
    storageBucket: "winatra-ai-de4f8.firebasestorage.app",
    messagingSenderId: "41894398402",
    appId: "1:41894398402:web:bcc9f6d244ef53cdb12e5b"
};

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();

// Elemen DOM
const authSection = document.getElementById('auth-section');
const adminPanel = document.getElementById('admin-panel');
const loginBtn = document.getElementById('loginBtn');
const logoutBtn = document.getElementById('logoutBtn');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginMessage = document.getElementById('loginMessage');
const userListDiv = document.getElementById('userList');
const searchEmail = document.getElementById('searchEmail');
const filterStatus = document.getElementById('filterStatus');
const applyFilterBtn = document.getElementById('applyFilter');
const resetFilterBtn = document.getElementById('resetFilter');

let allUsers = [];

auth.onAuthStateChanged(async (user) => {
    if (user) {
        if (user.email === 'admin@winatra.ai') {
            showAdminPanel();
            await loadAllUsers();
        } else {
            auth.signOut();
            showLogin('Anda bukan admin.');
        }
    } else {
        showLogin();
    }
});

loginBtn.addEventListener('click', async () => {
    const email = emailInput.value.trim();
    const password = passwordInput.value;
    if (!email || !password) {
        loginMessage.innerText = 'Masukkan email dan password';
        return;
    }
    try {
        await auth.signInWithEmailAndPassword(email, password);
        loginMessage.innerText = '';
    } catch (err) {
        loginMessage.innerText = err.message;
    }
});

logoutBtn.addEventListener('click', () => {
    auth.signOut();
});

function showLogin(msg = '') {
    authSection.style.display = 'block';
    adminPanel.style.display = 'none';
    if (msg) loginMessage.innerText = msg;
}

function showAdminPanel() {
    authSection.style.display = 'none';
    adminPanel.style.display = 'block';
}

async function loadAllUsers() {
    userListDiv.innerHTML = '<p>Memuat data...</p>';
    try {
        const snapshot = await db.collection('users').orderBy('createdAt', 'desc').get();
        allUsers = [];
        snapshot.forEach(doc => {
            allUsers.push({
                uid: doc.id,
                ...doc.data()
            });
        });
        applyFilter();
    } catch (err) {
        userListDiv.innerHTML = `<p class="error">Gagal memuat data: ${err.message}</p>`;
    }
}

function applyFilter() {
    const searchTerm = searchEmail.value.trim().toLowerCase();
    const statusFilter = filterStatus.value;

    let filtered = [...allUsers];

    if (searchTerm) {
        filtered = filtered.filter(user => user.email && user.email.toLowerCase().includes(searchTerm));
    }
    if (statusFilter !== 'all') {
        filtered = filtered.filter(user => (user.status || 'pending') === statusFilter);
    }

    renderUserTable(filtered);
}

function resetFilter() {
    searchEmail.value = '';
    filterStatus.value = 'all';
    applyFilter();
}

function renderUserTable(users) {
    if (!users.length) {
        userListDiv.innerHTML = '<p>Tidak ada pengguna yang sesuai.</p>';
        return;
    }

    let html = '<table><th>Nama</th><th>Email</th><th>Status</th><th>Aksi</th></tr>';
    users.forEach(user => {
        const status = user.status || 'pending';
        let statusClass = '';
        if (status === 'pending') statusClass = 'status-pending';
        else if (status === 'approved') statusClass = 'status-approved';
        else statusClass = 'status-rejected';

        html += `
            <tr>
                <td>${escapeHtml(user.name || '-')}</td>
                <td>${escapeHtml(user.email)}</td>
                <td class="${statusClass}">${status}</td>
                <td>
                    <button class="approve-btn" data-uid="${user.uid}">Approve</button>
                    <button class="reject-btn" data-uid="${user.uid}">Reject</button>
                </td>
            </tr>
        `;
    });
    html += '</table>';
    userListDiv.innerHTML = html;

    document.querySelectorAll('.approve-btn').forEach(btn => {
        btn.addEventListener('click', () => updateStatus(btn.dataset.uid, 'approved'));
    });
    document.querySelectorAll('.reject-btn').forEach(btn => {
        btn.addEventListener('click', () => updateStatus(btn.dataset.uid, 'rejected'));
    });
}

async function updateStatus(uid, newStatus) {
    try {
        await db.collection('users').doc(uid).update({ status: newStatus });
        // Perbarui data lokal
        const userIndex = allUsers.findIndex(u => u.uid === uid);
        if (userIndex !== -1) allUsers[userIndex].status = newStatus;
        applyFilter(); // refresh tampilan
    } catch (err) {
        alert('Gagal update status: ' + err.message);
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/[&<>]/g, function(m) {
        if (m === '&') return '&amp;';
        if (m === '<') return '&lt;';
        if (m === '>') return '&gt;';
        return m;
    });
}

// Event listeners filter
applyFilterBtn.addEventListener('click', applyFilter);
resetFilterBtn.addEventListener('click', resetFilter);
