# PyTorch's run of tests/ai/transformer.zap's training: the same transformer of characters from
# the same starting weights (weights.bin, its tensors in Learnable's order, their shapes in
# shapes.txt), on the same windows of the text (starts.txt, a batch a line): its device and its
# time, then its loss at each step, written to the output file.
#   python -I gpt.py <text> <dir> <context> <heads> <layers> <rate> <out.txt>
import sys
import time

import numpy as np
import torch
import torch.nn.functional as F


def main():
    text, folder, context, heads, layers, rate, out = sys.argv[1:8]
    context, heads, layers, rate = int(context), int(heads), int(layers), float(rate)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.backends.cuda.matmul.allow_tf32 = False
    data = open(text, "rb").read()
    alphabet = sorted(set(data))
    index = {b: i for i, b in enumerate(alphabet)}
    ids = torch.tensor([index[b] for b in data], dtype=torch.int64)
    shapes = [[int(d) for d in line.split()] for line in open(f"{folder}/shapes.txt") if line.strip()]
    flat = np.fromfile(f"{folder}/weights.bin", dtype=np.float32)
    params, at = [], 0
    for s in shapes:
        n = int(np.prod(s)) if s else 1
        params.append(torch.tensor(flat[at:at + n].reshape(s), device=device, requires_grad=True))
        at += n
    tokens, places = params[0], params[1]
    blocks = [params[2 + 12 * l: 14 + 12 * l] for l in range(layers)]
    norm_gain, norm_bias, head = params[2 + 12 * layers:]
    starts = [[int(s) for s in line.split()] for line in open(f"{folder}/starts.txt") if line.strip()]
    mask = torch.triu(torch.ones(context, context, dtype=torch.bool, device=device), diagonal=1)

    def forward(x_ids):
        b, t = x_ids.shape
        x = tokens[x_ids] + places[:t]
        for (g1, b1, wq, wk, wv, wo, g2, b2, up, ub, down, db) in blocks:
            h = F.layer_norm(x, (x.shape[-1],), g1, b1, 1e-5)
            q = (h @ wq).reshape(b, t, heads, -1).transpose(1, 2)
            k = (h @ wk).reshape(b, t, heads, -1).transpose(1, 2)
            v = (h @ wv).reshape(b, t, heads, -1).transpose(1, 2)
            att = (q @ k.transpose(-2, -1)) * (1.0 / np.sqrt(q.shape[-1]))
            att = att.masked_fill(mask[:t, :t], float("-inf")).softmax(-1)
            y = (att @ v).transpose(1, 2).reshape(b, t, -1)
            x = x + y @ wo
            g = F.layer_norm(x, (x.shape[-1],), g2, b2, 1e-5)
            x = x + (F.gelu(g @ up + ub, approximate="tanh") @ down + db)
        return F.layer_norm(x, (x.shape[-1],), norm_gain, norm_bias, 1e-5) @ head

    opt = torch.optim.Adam(params, lr=rate)
    losses = []
    batches = []
    for row in starts:
        xs = torch.stack([ids[s:s + context] for s in row]).to(device)
        ys = torch.stack([ids[s + 1:s + context + 1] for s in row]).to(device)
        batches.append((xs, ys))
    if device == "cuda":
        torch.cuda.synchronize()
    start = time.perf_counter()
    for xs, ys in batches:
        logits = forward(xs)
        loss = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), ys.reshape(-1))
        opt.zero_grad()
        loss.backward()
        opt.step()
        losses.append(loss.detach())
    curve = [l.item() for l in losses]
    seconds = time.perf_counter() - start
    with open(out, "w") as f:
        f.write(f"{device} {seconds}\n")
        for l in curve:
            f.write(f"{l}\n")


main()
