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
  const res = await fetch(`/api/products/${encodeURIComponent(productId)}/reviews`);
  const reviews = await res.json();
  const list = document.getElementById('reviews');
  list.replaceChildren();
  for (const r of reviews) {
    const item = document.createElement('li');
    const author = document.createElement('strong');
    author.textContent = r.author;
    item.append(author, `: ${r.body}`);
    list.append(item);
  }
}

async function adminPanel() {
  // The server decides who is an admin; a 403 simply means the panel stays hidden.
  const res = await fetch('/api/admin/users');
  if (!res.ok) return;
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
adminPanel();
