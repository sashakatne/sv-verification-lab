// Multi-policy request distributor ("load balancer").
//
// One upstream request stream is routed to exactly one of N backend ports.
// The target is chosen combinationally from the current policy, the per-backend
// ready (backpressure) mask, and registered state; the request/grant handshake
// gates the dispatch; state advances on the clock edge.
//
// Policies (selected at runtime by `policy`):
//   POLICY_RR  - round robin: rotate a pointer over ready backends.
//   POLICY_WRR - weighted round robin: deficit credits per backend, refilled
//                from `weight` when exhausted; weight 0 is never granted.
//   POLICY_LL  - least loaded: pick the ready backend with lowest occupancy,
//                lowest index breaks ties.
//
// Occupancy occ[i] tracks outstanding requests per backend: +1 on dispatch to
// i, -1 on be_done[i], saturating in [0, MAX_OUTSTANDING].
//
// The RTL carries no assertions; correctness properties live in
// load_balancer_sva.sva and are bound on from outside (see top.sv / formal/).
// `ifdef BUG_* guards inject deliberate faults for the negative regressions;
// each maps to the one property it is meant to falsify.
module load_balancer #(
    parameter int N            = 4,   // number of backends (fixed at 4 here)
    parameter int ID_WIDTH     = 8,   // request id payload width
    parameter int WEIGHT_WIDTH = 4,   // per-backend weight width (WRR)
    parameter int OCC_WIDTH    = 4    // occupancy counter width
) (
    input  logic                      clk,
    input  logic                      rst_n,

    // configuration
    input  logic [1:0]                policy,   // policy_e: 00 RR, 01 WRR, 10 LL
    input  logic [N*WEIGHT_WIDTH-1:0] weight,   // per-backend weight, packed

    // upstream request channel
    input  logic                      req_valid,
    input  logic [ID_WIDTH-1:0]       req_id,
    output logic                      req_ready,

    // downstream backend channels
    input  logic [N-1:0]              be_ready, // per-backend backpressure
    output logic [N-1:0]              be_valid, // one-hot dispatch
    output logic [ID_WIDTH-1:0]       be_id,    // dispatched id (broadcast)
    input  logic [N-1:0]              be_done,  // per-backend completion

    // status (observation / coverage)
    output logic [N*OCC_WIDTH-1:0]    occ_flat  // occupancy counters, packed
);

    localparam int SEL_WIDTH       = $clog2(N);
    localparam int MAX_OUTSTANDING = 12;                 // < 2^OCC_WIDTH-1 on purpose
    localparam logic [1:0] POLICY_RR  = 2'b00;
    localparam logic [1:0] POLICY_WRR = 2'b01;
    localparam logic [1:0] POLICY_LL  = 2'b10;

    // unpacked views of packed config / state
    logic [WEIGHT_WIDTH-1:0] w          [N];  // per-backend weight
    logic [WEIGHT_WIDTH-1:0] credit      [N];  // WRR credits (registered)
    logic [WEIGHT_WIDTH-1:0] credit_eff  [N];  // WRR credits after replenish
    logic [OCC_WIDTH-1:0]    occ         [N];  // occupancy (registered)
    logic [SEL_WIDTH-1:0]    rr_ptr;            // round-robin pointer (registered)

    logic [N-1:0]            elig;              // eligible backends under policy
    logic [N-1:0]            grant;             // one-hot selection (pre-handshake)
    logic [SEL_WIDTH-1:0]    grant_idx;         // index of granted backend
    logic                    accept;            // a dispatch happens this cycle

    logic                    any_wrr_live;      // ready weighted backend with credit
    logic                    any_wrr_weighted;  // ready backend with weight > 0
    logic                    replenish_wrr;

    // unpack weight, pack occupancy
    genvar gi;
    generate
        for (gi = 0; gi < N; gi++) begin : g_unpack
            assign w[gi] = weight[gi*WEIGHT_WIDTH +: WEIGHT_WIDTH];
            assign occ_flat[gi*OCC_WIDTH +: OCC_WIDTH] = occ[gi];
        end
    endgenerate

    // WRR replenish: refill credits the moment no ready weighted backend has any
    always_comb begin : p_replenish
        any_wrr_live     = 1'b0;
        any_wrr_weighted = 1'b0;
        for (int i = 0; i < N; i++) begin
            if (be_ready[i] && (w[i] != '0))                     any_wrr_weighted = 1'b1;
            if (be_ready[i] && (w[i] != '0) && (credit[i] != '0)) any_wrr_live     = 1'b1;
        end
    end
    assign replenish_wrr = any_wrr_weighted && !any_wrr_live;

    always_comb begin : p_credit_eff
        for (int i = 0; i < N; i++)
            credit_eff[i] = replenish_wrr ? w[i] : credit[i];
    end

    // eligibility + one-hot selection
    always_comb begin : p_select
        logic [SEL_WIDTH-1:0] idx;
        logic [OCC_WIDTH-1:0] best;

        elig      = '0;
        grant     = '0;
        grant_idx = '0;

        for (int i = 0; i < N; i++) begin
            if (policy == POLICY_WRR)
                elig[i] = be_ready[i] && (w[i] != '0) && (credit_eff[i] != '0);
            else
                elig[i] = be_ready[i];
        end

        case (policy)
            POLICY_RR: begin
                // rotate over ready backends starting at rr_ptr (N is a power of 2)
                for (int k = 0; k < N; k++) begin
                    idx = rr_ptr + SEL_WIDTH'(k);
                    if ((grant == '0) && elig[idx]) begin
                        grant[idx] = 1'b1;
                        grant_idx  = idx;
                    end
                end
            end
            POLICY_WRR: begin
                // lowest-index eligible backend wins
                for (int i = 0; i < N; i++)
                    if ((grant == '0) && elig[i]) begin
                        grant[i]  = 1'b1;
                        grant_idx = SEL_WIDTH'(i);
                    end
            end
            POLICY_LL: begin
                // minimum occupancy among ready backends, lowest index breaks ties
                best = '1;
                for (int i = 0; i < N; i++)
                    if (elig[i] && ((grant == '0) || (occ[i] < best))) begin
                        grant     = '0;
                        grant[i]  = 1'b1;
                        grant_idx = SEL_WIDTH'(i);
                        best      = occ[i];
                    end
            end
            default: grant = '0;
        endcase

`ifdef BUG_DOUBLE_GRANT
        // BUG: also light an adjacent backend -> violates p_grant_onehot / p_no_drop
        if (grant != '0)
            grant[(grant_idx + 1'b1)] = 1'b1;
`endif
`ifdef BUG_GRANT_NOTREADY
        // BUG: force-grant backend 0 ignoring be_ready -> violates p_grant_only_ready
        grant      = '0;
        grant[0]   = 1'b1;
        grant_idx  = '0;
`endif
`ifdef BUG_WRR_ZERO
        // BUG: under WRR, drop the weight!=0 exclusion -> may grant a weight-0 backend
        if (policy == POLICY_WRR) begin
            grant     = '0;
            grant_idx = '0;
            for (int i = 0; i < N; i++)
                if ((grant == '0) && be_ready[i]) begin
                    grant[i]  = 1'b1;
                    grant_idx = SEL_WIDTH'(i);
                end
        end
`endif
`ifdef BUG_LL_NOTMIN
        // BUG: under LL, take lowest-index ready instead of min occupancy
        if (policy == POLICY_LL) begin
            grant     = '0;
            grant_idx = '0;
            for (int i = 0; i < N; i++)
                if ((grant == '0) && be_ready[i]) begin
                    grant[i]  = 1'b1;
                    grant_idx = SEL_WIDTH'(i);
                end
        end
`endif
    end

    assign req_ready = |grant;
    assign be_valid  = grant & {N{req_valid}};
    assign be_id     = req_id;
    assign accept    = |be_valid;

    // state update
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rr_ptr <= '0;
            for (int i = 0; i < N; i++) begin
                credit[i] <= '0;
                occ[i]    <= '0;
            end
        end else begin
            // round-robin pointer
`ifdef BUG_RR_STUCK
            // BUG: freeze the pointer -> a backend can starve -> violates p_rr_bounded_fairness
            rr_ptr <= rr_ptr;
`else
            if (accept && (policy == POLICY_RR))
                rr_ptr <= grant_idx + 1'b1;
`endif

            // WRR credits: take the (possibly replenished) effective credit, spend one on grant
            if (policy == POLICY_WRR) begin
                for (int i = 0; i < N; i++) begin
                    if (accept && (grant_idx == SEL_WIDTH'(i)))
                        credit[i] <= credit_eff[i] - 1'b1;
                    else
                        credit[i] <= credit_eff[i];
                end
            end

            // occupancy: +1 on dispatch, -1 on done, saturating in [0, MAX_OUTSTANDING]
            for (int i = 0; i < N; i++) begin
                logic inc, dec;
                inc = be_valid[i];
                dec = be_done[i];
                if (inc && !dec) begin
`ifdef BUG_OCC_OVERFLOW
                    // BUG: no upper clamp -> occ can climb past MAX_OUTSTANDING
                    occ[i] <= occ[i] + 1'b1;
`else
                    occ[i] <= (occ[i] >= OCC_WIDTH'(MAX_OUTSTANDING))
                            ? OCC_WIDTH'(MAX_OUTSTANDING) : occ[i] + 1'b1;
`endif
                end else if (dec && !inc) begin
                    occ[i] <= (occ[i] == '0) ? '0 : occ[i] - 1'b1;
                end
                // inc && dec (net zero) or neither: hold
            end
        end
    end

endmodule : load_balancer
