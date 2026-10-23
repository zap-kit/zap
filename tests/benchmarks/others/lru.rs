// lru: an LRU cache of `size` entries through n operations of the programming-language-benchmarks
// suite: each step puts a key of one LCG and gets a key of another; prints the hits and the misses.
// A hash map from key to slot, the slots in a doubly linked list from the oldest to the newest.
use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};

const NONE: u32 = u32::MAX;

// a multiplicative hash of a 32-bit key
#[derive(Default)]
struct Multiplicative(u64);

impl Hasher for Multiplicative {
    fn finish(&self) -> u64 {
        self.0
    }

    fn write(&mut self, bytes: &[u8]) {
        for &b in bytes {
            self.0 = (self.0 ^ b as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15);
        }
    }

    fn write_u32(&mut self, key: u32) {
        self.0 = (key as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15);
    }
}

struct Cache {
    size: u32,
    len: u32,
    head: u32,
    tail: u32,
    key: Vec<u32>,
    value: Vec<u32>,
    prev: Vec<u32>,
    next: Vec<u32>,
    slot: HashMap<u32, u32, BuildHasherDefault<Multiplicative>>,
}

impl Cache {
    fn new(size: u32) -> Self {
        Cache {
            size,
            len: 0,
            head: NONE,
            tail: NONE,
            key: vec![0; size as usize],
            value: vec![0; size as usize],
            prev: vec![0; size as usize],
            next: vec![0; size as usize],
            slot: HashMap::with_capacity_and_hasher(size as usize, Default::default()),
        }
    }

    fn unlink(&mut self, s: u32) {
        let (p, n) = (self.prev[s as usize], self.next[s as usize]);
        if p == NONE { self.head = n } else { self.next[p as usize] = n }
        if n == NONE { self.tail = p } else { self.prev[n as usize] = p }
    }

    fn append(&mut self, s: u32) {
        self.prev[s as usize] = self.tail;
        self.next[s as usize] = NONE;
        if self.tail == NONE { self.head = s } else { self.next[self.tail as usize] = s }
        self.tail = s;
    }

    fn move_to_end(&mut self, s: u32) {
        if s != self.tail {
            self.unlink(s);
            self.append(s);
        }
    }

    fn put(&mut self, key: u32, value: u32) {
        if let Some(&s) = self.slot.get(&key) {
            self.value[s as usize] = value;
            self.move_to_end(s);
            return;
        }
        let s = if self.len == self.size {
            let s = self.head;
            self.slot.remove(&self.key[s as usize]);
            self.unlink(s);
            s
        } else {
            self.len += 1;
            self.len - 1
        };
        self.key[s as usize] = key;
        self.value[s as usize] = value;
        self.slot.insert(key, s);
        self.append(s);
    }

    fn get(&mut self, key: u32) -> bool {
        match self.slot.get(&key) {
            Some(&s) => {
                self.move_to_end(s);
                true
            }
            None => false,
        }
    }
}

// the next number of an LCG: 31 bits
fn lcg(seed: &mut u32) -> u32 {
    *seed = seed.wrapping_mul(1103515245).wrapping_add(12345) & 0x7fff_ffff;
    *seed
}

fn main() {
    let size: u32 = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(100);
    let n: u64 = std::env::args().nth(2).and_then(|a| a.parse().ok()).unwrap_or(10000);
    let modular = size * 10;
    let mut cache = Cache::new(size);
    let (mut seed0, mut seed1) = (0u32, 1u32);
    let (mut hit, mut missed) = (0u64, 0u64);
    for _ in 0..n {
        let k0 = lcg(&mut seed0) % modular;
        cache.put(k0, k0);
        let k1 = lcg(&mut seed1) % modular;
        if cache.get(k1) { hit += 1 } else { missed += 1 }
    }
    println!("{hit}\n{missed}");
}
