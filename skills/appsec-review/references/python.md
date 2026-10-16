# Python

Sources: Bandit rules, Python documentation security considerations (`subprocess`, `pickle`, `tarfile`, `xml`), OWASP Deserialization Cheat Sheet.

| Check | Flaw | Expected |
|---|---|---|
| Command execution | `subprocess.*(..., shell=True)`, `os.system`, `os.popen` with variables | Argument lists, `shell=False`; validated values; `timeout` |
| Deserialization | `pickle.loads`, `marshal`, `shelve`, `yaml.load` with `Loader=yaml.Loader`/`FullLoader`/`UnsafeLoader`, `jsonpickle` on untrusted data | `json`; `yaml.safe_load`; signed payloads if objects must cross a trust boundary |
| Code evaluation | `eval`, `exec`, `compile` on input | Explicit parsing; `ast.literal_eval` for literals only |
| SQL | f-strings or `%` formatting into queries | Driver parameters (`cursor.execute(sql, params)`), ORM query API |
| Paths | `open(base + name)`, `os.path.join(base, user)` (an absolute `user` replaces `base`) | `Path(base, name).resolve()` then `is_relative_to(base)` |
| Archives | `tarfile.extractall` and `zipfile` without member checks (path traversal, links) | `extractall(filter="data")` (Python 3.12+), or validate members |
| XML | `xml.etree`, `lxml` parsing untrusted XML (entity expansion, XXE) | `defusedxml` |
| Templates | `Template(user_input)` in Jinja2; `render_template_string` with input | Fixed templates, input as variables, autoescape on |
| Web frameworks | Flask `debug=True` or Werkzeug debugger in production; Django `DEBUG = True`, `ALLOWED_HOSTS = ['*']`, hard-coded `SECRET_KEY` | Configuration from environment, debug off |
| HTTP clients | `verify=False`; no timeout; following redirects to internal hosts with user URLs | Verification on; timeouts; SSRF controls from `web-app.md` |
| Randomness | `random` for tokens, passwords, ids | `secrets` |
| Dependencies | Unpinned `requirements.txt` | Pinned versions, ideally with hashes |
