import uvm_pkg::*;
`include "uvm_macros.svh"
import load_balancer_pkg::*;

// Cycle-accurate shadow-model scoreboard.
//
// Maintains an independent copy of the DUT's decision state (rr_ptr, WRR
// credits, per-backend occupancy). For each monitored cycle it:
//   1. predicts the granted backend from the shadow state via lb_ref,
//   2. checks req_ready, the one-hot be_valid dispatch, and every occupancy
//      counter against the DUT,
//   3. advances the shadow state by its own prediction so it stays independent
//      of the DUT output (the first divergence is flagged, not masked).
//
// The advance mirrors load_balancer.sv exactly: rr_ptr moves only on a
// round-robin accept, credits update only under WRR, occupancy saturates in
// [0, MAX_OUTSTANDING].
`uvm_analysis_imp_decl(_port)

class lb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(lb_scoreboard)

    uvm_analysis_imp_port #(lb_transaction, lb_scoreboard) scoreboard_port;
    lb_transaction tx_stack[$];

    // shadow decision state (2-state to match lb_ref.svh unpacked-array args)
    int                    sh_rr_ptr;
    bit [WEIGHT_WIDTH-1:0] sh_credit [N];
    bit [OCC_WIDTH-1:0]    sh_occ    [N];

    // stats for the final report
    longint unsigned checks;
    longint unsigned dispatches;
    longint unsigned mismatches;      // scoreboard-detected errors (per-test snapshot)
    longint unsigned grant_count [N];

    function new(string name = "lb_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard_port = new("scoreboard_port", this);
        sh_rr_ptr = 0;
        for (int i = 0; i < N; i++) begin
            sh_credit[i]   = '0;
            sh_occ[i]      = '0;
            grant_count[i] = 0;
        end
        checks     = 0;
        dispatches = 0;
        mismatches = 0;
    endfunction : build_phase

    // zero the per-test mismatch counter between sequences so each policy's
    // transcript "TEST" line reports its own independent result. The shadow
    // decision state is NOT reset: the DUT runs continuously across sequences
    // (never re-reset mid-sim), so the shadow must track it continuously too.
    function longint unsigned snapshot_mismatches();
        return mismatches;
    endfunction : snapshot_mismatches

    function void clear_mismatches();
        mismatches = 0;
    endfunction : clear_mismatches

    function void check_cycle(lb_transaction tx);
        int    pred_idx;
        bit    pred_ready;
        bit    pred_dispatch;
        logic [N-1:0] exp_be_valid;
        bit [WEIGHT_WIDTH-1:0] ce [N];

        checks++;

        // ---- predict from shadow state ----
        pred_idx      = lb_predict_index(tx.policy, tx.be_ready, sh_rr_ptr,
                                         tx.weight, sh_credit, sh_occ);
        pred_ready    = (pred_idx >= 0);
        pred_dispatch = pred_ready && tx.req_valid;
        exp_be_valid  = '0;
        if (pred_dispatch)
            exp_be_valid[pred_idx] = 1'b1;

        // ---- check response ----
        if (tx.req_ready !== pred_ready) begin
            mismatches++;
            `uvm_error("SCOREBOARD", $sformatf("req_ready mismatch: %s | expected=%b got=%b",
                                               tx.convert2string(), pred_ready, tx.req_ready))
        end

        if (tx.be_valid !== exp_be_valid) begin
            mismatches++;
            `uvm_error("SCOREBOARD", $sformatf("be_valid mismatch: %s | expected=%b got=%b (pred_idx=%0d)",
                                               tx.convert2string(), exp_be_valid, tx.be_valid, pred_idx))
        end

        // one-hot safety on the observed grant (redundant with SVA, cheap here)
        if ($countones(tx.be_valid) > 1) begin
            mismatches++;
            `uvm_error("SCOREBOARD", $sformatf("be_valid not one-hot: %b", tx.be_valid))
        end

        // occupancy: shadow must equal the DUT's registered counters this cycle
        for (int i = 0; i < N; i++)
            if (tx.occ[i] !== sh_occ[i]) begin
                mismatches++;
                `uvm_error("SCOREBOARD", $sformatf("occ[%0d] mismatch: expected=%0d got=%0d",
                                                   i, sh_occ[i], tx.occ[i]))
            end

        // ---- advance shadow (mirror load_balancer.sv) ----
        if (pred_dispatch) begin
            dispatches++;
            grant_count[pred_idx]++;
        end

        // rr pointer: only on a round-robin accept
        if (pred_dispatch && (tx.policy == POLICY_RR))
            sh_rr_ptr = (pred_idx + 1) % N;

        // WRR credits: mirror the RTL exactly. The RTL derives credit_eff[] for
        // ALL backends from the registered credit snapshot in one always_comb,
        // then spends in always_ff. So we must snapshot the effective credit for
        // every backend from the UNMODIFIED sh_credit first (pass 1), then apply
        // the spend (pass 2). Computing and writing in a single loop would let a
        // later backend see an already-updated sh_credit and re-decide replenish.
        if (tx.policy == POLICY_WRR) begin
            for (int i = 0; i < N; i++)               // pass 1: snapshot
                ce[i] = lb_credit_eff_i(i, tx.be_ready, tx.weight, sh_credit);
            for (int i = 0; i < N; i++) begin         // pass 2: spend + write
                if (pred_dispatch && (pred_idx == i))
                    sh_credit[i] = ce[i] - 1'b1;
                else
                    sh_credit[i] = ce[i];
            end
        end

        // occupancy: +1 on dispatch, -1 on done, saturating
        for (int i = 0; i < N; i++) begin
            bit inc, dec;
            inc = exp_be_valid[i];
            dec = tx.be_done[i];
            if (inc && !dec)
                sh_occ[i] = (sh_occ[i] >= OCC_WIDTH'(MAX_OUTSTANDING))
                          ? OCC_WIDTH'(MAX_OUTSTANDING) : sh_occ[i] + 1'b1;
            else if (dec && !inc)
                sh_occ[i] = (sh_occ[i] == '0) ? '0 : sh_occ[i] - 1'b1;
        end
    endfunction : check_cycle

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            lb_transaction current_tx;
            wait (tx_stack.size() > 0);
            current_tx = tx_stack.pop_front();
            check_cycle(current_tx);
        end
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf("checked %0d cycles, %0d dispatches", checks, dispatches), UVM_LOW)
        for (int i = 0; i < N; i++)
            `uvm_info("SCOREBOARD", $sformatf("backend %0d granted %0d times", i, grant_count[i]), UVM_LOW)
    endfunction : report_phase

    function void write_port(lb_transaction mon_tx);
        tx_stack.push_back(mon_tx);
    endfunction : write_port

endclass : lb_scoreboard
