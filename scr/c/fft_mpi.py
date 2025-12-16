from mpi4py import MPI
import numpy as np
import sys

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
P = comm.Get_size()

N = int(sys.argv[1]) if len(sys.argv) > 1 else (1 << 20)
assert N % P == 0
nloc = N // P


idx0 = rank * nloc + np.arange(nloc)
X = np.exp(2j * np.pi * (idx0 % 16) / N).astype(np.complex128)

log2n = int(np.log2(N))

for s in range(1, log2n + 1):
    m = 1 << s
    mh = m >> 1

    if m <= nloc:
        j = np.arange(mh)
        W = np.exp(-2j * np.pi * j / m)
        for k in range(0, nloc, m):
            u = X[k:k + mh]
            v = W * X[k + mh:k + m]
            X[k:k + mh] = u + v
            X[k + mh:k + m] = u - v
    else:
        X_full = None
        if rank == 0:
            X_full = np.empty(N, dtype=np.complex128)

        comm.Gather(X, X_full, root=0)

        if rank == 0:
            j = np.arange(mh)
            W = np.exp(-2j * np.pi * j / m)
            for k in range(0, N, m):
                u = X_full[k:k + mh]
                v = W * X_full[k + mh:k + m]
                X_full[k:k + mh] = u + v
                X_full[k + mh:k + m] = u - v

        comm.Scatter(X_full, X, root=0)

norm2_local = np.vdot(X, X).real
norm2 = comm.reduce(norm2_local, op=MPI.SUM, root=0)

if rank == 0:
    print(f"norm2={norm2:e}")
