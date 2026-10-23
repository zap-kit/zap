// dijkstra: shortest paths from the top left cell of an n by n grid whose edges between
// neighbours cost 1 to 9, over a binary heap of (distance, cell) packed in one u64; prints the
// far corner's distance, the sum of all and how many entries the heap took.
use std::cmp::Reverse;
use std::collections::BinaryHeap;

struct Generator(u64);

impl Generator {
    // the next number, 31 bits
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 33
    }
}

fn main() {
    let n: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(100);
    let mut random = Generator(1);
    // the cost of the edge from a cell to its right and to its lower neighbour
    let mut right = vec![0u8; n * n];
    let mut down = vec![0u8; n * n];
    for i in 0..n * n {
        right[i] = (1 + random.next() % 9) as u8;
        down[i] = (1 + random.next() % 9) as u8;
    }
    let mut dist = vec![u32::MAX; n * n];
    let mut heap = BinaryHeap::new();
    let mut pushes = 1;
    dist[0] = 0;
    heap.push(Reverse(0u64));
    while let Some(Reverse(top)) = heap.pop() {
        let d = top >> 32;
        let cell = top as u32 as usize;
        if d > dist[cell] as u64 {
            continue;
        }
        let (x, y) = (cell % n, cell / n);
        let mut relax = |to: usize, cost: u8| {
            let nd = d + cost as u64;
            if nd < dist[to] as u64 {
                dist[to] = nd as u32;
                heap.push(Reverse(nd << 32 | to as u64));
                pushes += 1;
            }
        };
        if x > 0 {
            relax(cell - 1, right[cell - 1]);
        }
        if x + 1 < n {
            relax(cell + 1, right[cell]);
        }
        if y > 0 {
            relax(cell - n, down[cell - n]);
        }
        if y + 1 < n {
            relax(cell + n, down[cell]);
        }
    }
    let sum: u64 = dist.iter().map(|&d| d as u64).sum();
    println!("corner {}, sum {}, pushes {}", dist[n * n - 1], sum, pushes);
}
