// Golden reference for the load_balancer selection policy.
//
// Pure functions, shared by the UVM scoreboard as its shadow model. Given the
// policy, the per-backend ready mask, and the current shadow state (rr_ptr,
// credits, occupancy), predict which backend index the DUT must grant this
// cycle. Returns -1 when no backend is eligible (so no dispatch occurs).
//
// The logic here mirrors load_balancer.sv exactly. Keeping a single reference
// used by the checker (single-golden-reference philosophy) means the RTL and
// the checker cannot silently drift apart: any divergence is a real bug in one
// of them, surfaced as a scoreboard mismatch.
//
// The unpacked-array arguments are 2-state (bit), matching the transaction's
// `rand bit` weight field; Questa requires exact state matching on unpacked
// array function arguments (vlog-7034). The checker asserts no-unknowns, so
// 2-state loses nothing here.

// WRR replenish: credits refill the moment no ready weighted backend has any
// credit left. Mirrors load_balancer.sv `replenish_wrr`.
function automatic bit lb_replenish_wrr(
    input bit   [N-1:0]            be_ready,
    input bit   [WEIGHT_WIDTH-1:0] weight [N],
    input bit   [WEIGHT_WIDTH-1:0] credit [N]
);
    bit any_weighted;
    bit any_live;
    any_weighted = 1'b0;
    any_live     = 1'b0;
    for (int i = 0; i < N; i++) begin
        if (be_ready[i] && (weight[i] != '0))
            any_weighted = 1'b1;
        if (be_ready[i] && (weight[i] != '0) && (credit[i] != '0))
            any_live = 1'b1;
    end
    return any_weighted && !any_live;
endfunction : lb_replenish_wrr

// Predict the granted backend index (-1 = none eligible).
function automatic int lb_predict_index(
    input policy_e               policy,
    input bit   [N-1:0]          be_ready,
    input int                    rr_ptr,
    input bit   [WEIGHT_WIDTH-1:0] weight [N],
    input bit   [WEIGHT_WIDTH-1:0] credit [N],
    input bit   [OCC_WIDTH-1:0]    occ    [N]
);
    bit   [WEIGHT_WIDTH-1:0] credit_eff [N];
    bit                      replenish;
    int                      idx;
    int                      chosen;
    bit   [OCC_WIDTH-1:0]    best;

    chosen    = -1;
    replenish = lb_replenish_wrr(be_ready, weight, credit);
    for (int i = 0; i < N; i++)
        credit_eff[i] = replenish ? weight[i] : credit[i];

    case (policy)
        POLICY_RR: begin
            for (int k = 0; k < N; k++) begin
                idx = (rr_ptr + k) % N;
                if ((chosen < 0) && be_ready[idx])
                    chosen = idx;
            end
        end
        POLICY_WRR: begin
            for (int i = 0; i < N; i++)
                if ((chosen < 0) && be_ready[i] && (weight[i] != '0) && (credit_eff[i] != '0))
                    chosen = i;
        end
        POLICY_LL: begin
            best = '1;
            for (int i = 0; i < N; i++)
                if (be_ready[i] && ((chosen < 0) || (occ[i] < best))) begin
                    chosen = i;
                    best   = occ[i];
                end
        end
        default: chosen = -1;
    endcase
    return chosen;
endfunction : lb_predict_index

// Effective credit after replenish, for advancing the WRR shadow state.
function automatic bit [WEIGHT_WIDTH-1:0] lb_credit_eff_i(
    input int                    i,
    input bit   [N-1:0]          be_ready,
    input bit   [WEIGHT_WIDTH-1:0] weight [N],
    input bit   [WEIGHT_WIDTH-1:0] credit [N]
);
    if (lb_replenish_wrr(be_ready, weight, credit))
        return weight[i];
    return credit[i];
endfunction : lb_credit_eff_i
