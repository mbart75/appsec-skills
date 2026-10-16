const { supabaseUrl, supabaseKey } = window.TINYSHOP_CONFIG;
const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);

async function loadProducts() {
  const { data } = await supabase.from('products').select('id, name, price_cents').order('name');
  const list = document.getElementById('products');
  for (const p of data) {
    const item = document.createElement('li');
    const link = document.createElement('a');
    link.href = '#';
    link.dataset.id = p.id;
    link.textContent = p.name;
    item.append(link, ` ${(p.price_cents / 100).toFixed(2)} €`);
    list.append(item);
  }
}

async function loadReviews(productId) {
  const res = await fetch(`/api/products/${productId}/reviews`);
  const reviews = await res.json();
  document.getElementById('reviews').innerHTML = reviews
    .map((r) => `<li><strong>${r.author}</strong>: ${r.body}</li>`)
    .join('');
}

async function loadMyProfile() {
  const { data } = await supabase.from('profiles').select('full_name, phone, address');
  return data[0];
}

async function adminPanel() {
  if (localStorage.getItem('isAdmin') !== 'true') return;
  const res = await fetch('/api/admin/users', { headers: { 'X-Admin': 'true' } });
  const users = await res.json();
  const panel = document.getElementById('admin');
  panel.textContent = `${users.length} users`;
  panel.hidden = false;
}

document.getElementById('products').addEventListener('click', (event) => {
  const id = event.target.dataset.id;
  if (id) loadReviews(id);
});

loadProducts();
loadMyProfile();
adminPanel();
