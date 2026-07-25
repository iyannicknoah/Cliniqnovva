// A hand-rolled, in-memory stand-in for the Firebase Admin Firestore SDK —
// same pattern used to verify Parts 10/11/12/13/16's service logic during
// development, now made permanent for Part 18's integration suite. Supports
// exactly the subset of the real API this codebase actually calls:
// collection/doc/where/orderBy/limit/count/add/set/update/delete/get and
// runTransaction (tx.get/set/update/delete) — nothing more.
//
// Documents are stored in one flat Map keyed by full path
// ("collection/docId" or "collection/docId/subcollection/docId" for
// subcollections like patients/{id}/documents). A "collection" is just the
// set of stored paths that start with "<path>/" and have no further "/"
// after that prefix — so subcollections never leak into their parent
// collection's queries, matching real Firestore.

function matchFilter(data, { field, op, value }) {
  const actual = data ? data[field] : undefined;
  switch (op) {
    case '==':
      return actual === value;
    case '!=':
      return actual !== value;
    case 'in':
      return Array.isArray(value) && value.includes(actual);
    case 'not-in':
      return Array.isArray(value) && !value.includes(actual);
    case '>':
      return actual > value;
    case '>=':
      return actual >= value;
    case '<':
      return actual < value;
    case '<=':
      return actual <= value;
    case 'array-contains':
      return Array.isArray(actual) && actual.includes(value);
    default:
      throw new Error(`mockFirestore: unsupported operator "${op}"`);
  }
}

class MockDocSnapshot {
  constructor(fs, path, id, data) {
    this.id = id;
    this.exists = data !== undefined;
    this._data = data;
    this.ref = new DocRef(fs, path);
  }
  data() {
    return this._data ? { ...this._data } : undefined;
  }
}

class MockQuerySnapshot {
  constructor(docs) {
    this.docs = docs;
    this.empty = docs.length === 0;
    this.size = docs.length;
  }
  forEach(fn) {
    this.docs.forEach(fn);
  }
}

class DocRef {
  constructor(fs, path) {
    this.fs = fs;
    this.path = path;
    this.id = path.split('/').pop();
  }
  collection(name) {
    return new CollectionRef(this.fs, `${this.path}/${name}`);
  }
  async get() {
    const data = this.fs.docs.get(this.path);
    return new MockDocSnapshot(this.fs, this.path, this.id, data);
  }
  async set(data, opts) {
    if (opts && opts.merge) {
      const existing = this.fs.docs.get(this.path) || {};
      this.fs.docs.set(this.path, { ...existing, ...data });
    } else {
      this.fs.docs.set(this.path, { ...data });
    }
  }
  async update(data) {
    const existing = this.fs.docs.get(this.path);
    if (existing === undefined) {
      throw new Error(`mockFirestore: no document to update at ${this.path}`);
    }
    this.fs.docs.set(this.path, { ...existing, ...data });
  }
  async delete() {
    this.fs.docs.delete(this.path);
  }
}

class CollectionRef {
  constructor(fs, path) {
    this.fs = fs;
    this.path = path;
    this._filters = [];
    this._order = null;
    this._limitN = null;
  }
  doc(id) {
    const docId = id || `auto_${++this.fs._counter}`;
    return new DocRef(this.fs, `${this.path}/${docId}`);
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
  where(field, op, value) {
    const q = this._clone();
    q._filters.push({ field, op, value });
    return q;
  }
  orderBy(field, dir = 'asc') {
    const q = this._clone();
    q._order = { field, dir };
    return q;
  }
  limit(n) {
    const q = this._clone();
    q._limitN = n;
    return q;
  }
  count() {
    const self = this;
    return {
      async get() {
        return { data: () => ({ count: self._matchingDocs().length }) };
      },
    };
  }
  _clone() {
    const q = new CollectionRef(this.fs, this.path);
    q._filters = [...this._filters];
    q._order = this._order;
    q._limitN = this._limitN;
    return q;
  }
  _matchingDocs() {
    const prefix = `${this.path}/`;
    const results = [];
    for (const [path, data] of this.fs.docs.entries()) {
      if (!path.startsWith(prefix)) continue;
      const rest = path.slice(prefix.length);
      if (rest.includes('/')) continue; // belongs to a nested subcollection, not this one
      results.push({ id: rest, path, data });
    }
    let filtered = results.filter(({ data }) => this._filters.every((f) => matchFilter(data, f)));
    if (this._order) {
      const { field, dir } = this._order;
      filtered = filtered.sort((a, b) => {
        const av = a.data[field];
        const bv = b.data[field];
        if (av < bv) return dir === 'desc' ? 1 : -1;
        if (av > bv) return dir === 'desc' ? -1 : 1;
        return 0;
      });
    }
    if (this._limitN != null) filtered = filtered.slice(0, this._limitN);
    return filtered;
  }
  async get() {
    const docs = this._matchingDocs().map(({ path, id, data }) => new MockDocSnapshot(this.fs, path, id, data));
    return new MockQuerySnapshot(docs);
  }
}

class Transaction {
  constructor(fs) {
    this.fs = fs;
  }
  async get(refOrQuery) {
    return refOrQuery.get();
  }
  set(ref, data, opts) {
    if (opts && opts.merge) {
      const existing = this.fs.docs.get(ref.path) || {};
      this.fs.docs.set(ref.path, { ...existing, ...data });
    } else {
      this.fs.docs.set(ref.path, { ...data });
    }
  }
  update(ref, data) {
    const existing = this.fs.docs.get(ref.path);
    if (existing === undefined) {
      throw new Error(`mockFirestore: no document to update at ${ref.path}`);
    }
    this.fs.docs.set(ref.path, { ...existing, ...data });
  }
  delete(ref) {
    this.fs.docs.delete(ref.path);
  }
}

class MockFirestore {
  constructor() {
    this.docs = new Map();
    this._counter = 0;
  }
  collection(name) {
    return new CollectionRef(this, name);
  }
  async runTransaction(fn) {
    // Real Firestore retries a transaction if the data it read changes
    // before commit. This mock is single-threaded/synchronous per test, so
    // there's never a real race to retry — one straight-through call is
    // equivalent for everything this suite tests.
    const tx = new Transaction(this);
    return fn(tx);
  }
  // Test helper — not part of the real Firestore API. Seeds a document
  // directly without going through a service function, so tests can set up
  // fixtures without exercising the code under test twice.
  seed(path, data) {
    this.docs.set(path, { ...data });
  }
  // Test helper — read the raw stored fields back out, for assertions.
  peek(path) {
    const data = this.docs.get(path);
    return data ? { ...data } : undefined;
  }
}

module.exports = { MockFirestore };
