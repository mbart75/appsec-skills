// Notes accept a little formatting (bold, lists, links). The HTML is cleaned with DOMPurify before display.
function render(notes) {
  const $list = $('#notes').empty();
  notes.forEach((note) => {
    const clean = DOMPurify.sanitize(note.html);
    $('<article class="note"></article>').html(clean).appendTo($list);
  });
}

function load() {
  $.getJSON('/api/notes', render);
}

$('#new-note').on('submit', (event) => {
  event.preventDefault();
  $.ajax({
    url: '/api/notes',
    method: 'POST',
    contentType: 'application/json',
    data: JSON.stringify({ html: $('#new-note textarea').val() }),
  }).done(load);
});

load();
