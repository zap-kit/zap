# PyTorch's run of tests/ai/mnist.zap's training, from the same starting weights, on the same
# batches in the same order: its device, its time and its test accuracy, then its loss at each
# step, written to the output file.
#   python -I mnist.py <data dir> <weights.bin> <steps> <batch> <rate> <out.txt>
import gzip
import sys
import time

import numpy as np
import torch


def images(path):
    raw = gzip.open(path, "rb").read()
    n = int.from_bytes(raw[4:8], "big")
    return np.frombuffer(raw, dtype=np.uint8, offset=16).reshape(n, 784).astype(np.float32) / 255.0


def labels(path):
    raw = gzip.open(path, "rb").read()
    return np.frombuffer(raw, dtype=np.uint8, offset=8).astype(np.int64)


def main():
    data, weights, steps, batch, rate, out = sys.argv[1:7]
    steps, batch, rate = int(steps), int(batch), float(rate)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.backends.cuda.matmul.allow_tf32 = False
    x = torch.tensor(images(f"{data}/train-images-idx3-ubyte.gz"), device=device)
    y = torch.tensor(labels(f"{data}/train-labels-idx1-ubyte.gz"), device=device)
    w = np.fromfile(weights, dtype=np.float32)
    shapes = [(784, 128), (128,), (128, 10), (10,)]
    params, at = [], 0
    for s in shapes:
        n = int(np.prod(s))
        params.append(torch.tensor(w[at:at + n].reshape(s), device=device, requires_grad=True))
        at += n
    w1, b1, w2, b2 = params
    opt = torch.optim.Adam(params, lr=rate)
    losses = []
    if device == "cuda":
        torch.cuda.synchronize()
    start = time.perf_counter()
    for k in range(steps):
        xb = x[k * batch:(k + 1) * batch]
        yb = y[k * batch:(k + 1) * batch]
        logits = torch.relu(xb @ w1 + b1) @ w2 + b2
        loss = torch.nn.functional.cross_entropy(logits, yb)
        opt.zero_grad()
        loss.backward()
        opt.step()
        losses.append(loss.detach())
    curve = [l.item() for l in losses]
    seconds = time.perf_counter() - start
    tx = torch.tensor(images(f"{data}/t10k-images-idx3-ubyte.gz"), device=device)
    ty = torch.tensor(labels(f"{data}/t10k-labels-idx1-ubyte.gz"), device=device)
    with torch.no_grad():
        right = ((torch.relu(tx @ w1 + b1) @ w2 + b2).argmax(1) == ty).float().mean().item()
    with open(out, "w") as f:
        f.write(f"{device} {seconds} {right}\n")
        for l in curve:
            f.write(f"{l}\n")


main()
