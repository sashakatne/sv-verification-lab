# LoadBalancer - design intent

A hardware analog of a systems-design load balancer: one upstream request
stream is distributed across `N=4` backend "servers" by a runtime-selectable
policy, honoring per-backend backpressure. The interesting part is not the
datapath (there is none - the payload just passes through) but the *selection*
logic and the invariants that must hold across three policies and a shared
occupancy counter.

## Interface

| Signal | Dir | Meaning |
|--------|-----|---------|
| `policy[1:0]` | in | `00`=round robin, `01`=weighted RR, `10`=least loaded |
| `weight[N*4]` | in | per-backend weight (packed), WRR only; weight 0 = never granted |
| `req_valid` / `req_id` / `req_ready` | in/in/out | upstream request handshake |
| `be_ready[N]` | in | per-backend backpressure (a backend can accept this cycle) |
| `be_valid[N]` / `be_id` | out | one-hot dispatch to the chosen backend |
| `be_done[N]` | in | per-backend completion (decrements occupancy) |
| `occ_flat[N*4]` | out | per-backend outstanding-request counters (packed) |

## Micro-architecture

Selection is **combinational**; state is **registered**. Each cycle the DUT
computes a one-hot `grant` from `policy`, the `be_ready` mask, and the current
registered state; the handshake gates it (`be_valid = grant & {N{req_valid}}`);
state advances on the clock edge. Because `grant` never depends on `req_valid`,
there is no combinational loop and every policy is a pure function of state -
which is what makes the design formally provable.

- **Round robin**: a rotating pointer `rr_ptr` selects the first ready backend
  at or after the pointer; on an accepted dispatch the pointer advances to
  `grant_idx + 1`.
- **Weighted round robin**: each backend has a deficit `credit`. When no ready
  weighted backend has credit left, all credits refill from `weight` in the
  same cycle (`credit_eff`), so a grant always succeeds if any weighted-and-
  ready backend exists. Weight-0 backends are never eligible.
- **Least loaded**: pick the ready backend with minimum `occ`; lowest index
  breaks ties.

Occupancy `occ[i]` increments on dispatch to `i`, decrements on `be_done[i]`,
and saturates in `[0, MAX_OUTSTANDING]` (=12).

## Verification strategy

Two independent views, sharing one golden reference (`lb_ref.svh`):

1. **UVM simulation** (Questa) - a cycle-accurate shadow-model scoreboard keeps
   its own copy of `rr_ptr`/`credit`/`occ`, predicts the grant from `lb_ref`,
   and checks `req_ready`, the one-hot dispatch, and every occupancy counter
   every cycle. Five sequences (one per policy, mixed, backpressure) drive it;
   functional coverage crosses policy x ready-pattern x occupancy and the
   handshake states, closed to 100%.

2. **Formal proof** (VC Formal) - a bound SVA module (`load_balancer_sva.sva`)
   proves the structural invariants: one-hot grant, grant-only-ready, no-drop,
   occupancy bounds, WRR weight-0 exclusion, LL picks-min, and round-robin
   fairness (as a bounded-safety pointer-advance property).

Six `BUG_*` mutations, each mapped to the one property it falsifies, prove the
checks have teeth. See `README.md` for the result tables and `MANIFEST.txt`
for farm provenance.
