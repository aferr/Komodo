include "sec_prop.s.dfy"
include "pagedb.s.dfy"
include "entry.s.dfy"

//-----------------------------------------------------------------------------
// Confidentiality, Enclaves are NI with other Enclaves 
//-----------------------------------------------------------------------------
predicate ni_reqs(s1: state, d1: PageDb, s1': state, d1': PageDb,
                  s2: state, d2: PageDb, s2': state, d2': PageDb,
                  atkr: PageNr)
{
    SaneState(s1) && validPageDb(d1) && SaneState(s1') && validPageDb(d1') &&
    SaneState(s2) && validPageDb(d2) && SaneState(s2') && validPageDb(d2') &&
    pageDbCorresponds(s1.m, d1) && pageDbCorresponds(s1'.m, d1') &&
    pageDbCorresponds(s2.m, d2) && pageDbCorresponds(s2'.m, d2') &&
    valAddrPage(d1, atkr) && valAddrPage(d2, atkr) &&
    // This is a slight weakening of the security property...
    (forall n : PageNr :: d1[n].PageDbEntryFree? <==> d2[n].PageDbEntryFree?)
}

predicate ni_reqs_(d1: PageDb, d1': PageDb, d2: PageDb, d2': PageDb, atkr: PageNr)
{
    validPageDb(d1) && validPageDb(d1') &&
    validPageDb(d2) && validPageDb(d2') &&
    valAddrPage(d1, atkr) && valAddrPage(d2, atkr) &&
    // This is a slight weakening of the security property...
    (forall n : PageNr :: d1[n].PageDbEntryFree? <==> d2[n].PageDbEntryFree?)
}

predicate same_call_args(s1:state, s2: state)
    requires SaneState(s1) && SaneState(s2)
{
    reveal_ValidRegState();
    reveal_ValidSRegState();
    OperandContents(s1, OReg(R0))  == OperandContents(s2, OReg(R0)) &&
    OperandContents(s1, OReg(R1))  == OperandContents(s2, OReg(R1)) &&
    OperandContents(s1, OReg(R2))  == OperandContents(s2, OReg(R2)) &&
    OperandContents(s1, OReg(R3))  == OperandContents(s2, OReg(R3)) &&
    OperandContents(s1, OReg(R4))  == OperandContents(s2, OReg(R4))
}

predicate entering_atkr(d1: PageDb, d2: PageDb, disp: word, atkr: PageNr, is_resume:bool)
    requires validPageDb(d1) && validPageDb(d2)
    requires valAddrPage(d1, atkr) && valAddrPage(d2, atkr)
{
    validPageNr(disp) &&
    d1[disp].PageDbEntryTyped? && d1[disp].entry.Dispatcher? &&
    d2[disp].PageDbEntryTyped? && d2[disp].entry.Dispatcher? &&
    d1[disp].addrspace == atkr && d2[disp].addrspace == atkr &&
    smc_enter_err(d1, atkr, is_resume) == KOM_ERR_SUCCESS &&
    smc_enter_err(d2, atkr, is_resume) == KOM_ERR_SUCCESS
}

lemma lemma_enc_conf_ni(s1: state, d1: PageDb, s1': state, d1': PageDb,
                      s2: state, d2: PageDb, s2': state, d2': PageDb,
                      atkr: PageNr)
    requires ni_reqs(s1, d1, s1', d1', s2, d2, s2', d2', atkr)
    requires same_call_args(s1, s2)
    // If smchandler(s1, d1) => (s1', d1')
    requires smchandler(s1, d1, s1', d1')
    // and smchandler(s2, d2) => (s2', d2')
    requires smchandler(s2, d2, s2', d2')
    // s.t. (s1, d1) =_{atkr} (s2, d2)
    requires enc_conf_eqpdb(d1, d2, atkr)
    requires (var callno := s1.regs[R0]; var dispPage := s1.regs[R1];
        (callno == KOM_SMC_ENTER  && entering_atkr(d1, d2, dispPage, atkr, false))
                ==> enc_conf_eq_entry(s1, s2, d1, d2, atkr))
    requires (var callno := s1.regs[R0]; var dispPage := s1.regs[R1];
        (callno == KOM_SMC_RESUME  && entering_atkr(d1, d2, dispPage, atkr, true))
                ==> enc_conf_eq_entry(s1, s2, d1, d2, atkr))
    // then (s1', d1') =_{atkr} (s2', d2')
    ensures (!(var callno := s1.regs[R0]; var asp := s1.regs[R1];
        callno == KOM_SMC_STOP && asp == atkr) ==>
        enc_conf_eqpdb(d1', d2', atkr))
    ensures (
        var callno := s1.regs[R0]; var dispPage := s1.regs[R1];
        (callno == KOM_SMC_ENTER && entering_atkr(d1, d2, dispPage, atkr, false))
            // in the following line enc_start_equiv(s1, s2) is not a typo
            ==> (enc_conf_eq_entry(s1', s2', d1', d2', atkr) && enc_start_equiv(s1, s2))
    )
    ensures (
        var callno := s1.regs[R0]; var dispPage := s1.regs[R1];
        (callno == KOM_SMC_RESUME && entering_atkr(d1, d2, dispPage, atkr, true))
            ==> (enc_conf_eq_entry(s1', s2', d1', d2', atkr) && enc_start_equiv(s1, s2))
    )
{
    reveal_ValidRegState();
    var callno, arg1, arg2, arg3, arg4
        := s1.regs[R0], s1.regs[R1], s1.regs[R2], s1.regs[R3], s1.regs[R4];
    var e1', e2' := s1'.regs[R0], s2'.regs[R0];

    if(callno == KOM_SMC_QUERY || callno == KOM_SMC_GETPHYSPAGES){
        assert d1' == d1;
        assert d2' == d2;
    }
    else if(callno == KOM_SMC_INIT_ADDRSPACE){
        lemma_initAddrspace_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, arg2, atkr);
    }
    else if(callno == KOM_SMC_INIT_DISPATCHER){
        lemma_initDispatcher_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, arg2, arg3, atkr);
    }
    else if(callno == KOM_SMC_INIT_L2PTABLE){
        lemma_initL2PTable_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, arg2, arg3, atkr);
    }
    else if(callno == KOM_SMC_MAP_SECURE){
        var c1 := maybeContentsOfPhysPage(s1, arg4);
        var c2 := maybeContentsOfPhysPage(s2, arg4);
        lemma_mapSecure_enc_conf_ni(d1, c1, d1', e1', d2, c2, d2', e2', arg1, arg2, arg3, arg4, atkr);
    }
    else if(callno == KOM_SMC_MAP_INSECURE){
        lemma_mapInsecure_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, arg2, arg3, atkr);
    }
    else if(callno == KOM_SMC_REMOVE){
        lemma_remove_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, atkr);
    }
    else if(callno == KOM_SMC_FINALISE){
        lemma_finalise_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, atkr);
    }
    else if(callno == KOM_SMC_ENTER){
        lemma_enter_enc_conf_ni(s1, d1, s1', d1', s2, d2, s2', d2', arg1, arg2, arg3, arg4, atkr);
    }
    else if(callno == KOM_SMC_RESUME){
        lemma_resume_enc_conf_ni(s1, d1, s1', d1', s2, d2, s2', d2', arg1, atkr);
    }
    else if(callno == KOM_SMC_STOP){
        lemma_stop_enc_conf_ni(d1, d1', e1', d2, d2', e2', arg1, atkr);
    }
    else {
        assert e1' == KOM_ERR_INVALID;
        assert e2' == KOM_ERR_INVALID;
        assert d1' == d1;
        assert d2' == d2;
    }
}


lemma lemma_enter_enc_conf_ni(s1: state, d1: PageDb, s1':state, d1': PageDb,
                        s2: state, d2: PageDb, s2':state, d2': PageDb,
                        dispPage: word, arg1: word, arg2: word, arg3: word,
                        atkr: PageNr)
    requires ni_reqs(s1, d1, s1', d1', s2, d2, s2', d2', atkr)
    requires smc_enter(s1, d1, s1', d1', dispPage, arg1, arg2, arg3)
    requires smc_enter(s2, d2, s2', d2', dispPage, arg1, arg2, arg3)
    requires enc_conf_eqpdb(d1, d2, atkr)
    requires entering_atkr(d1, d2, dispPage, atkr, false) ==>
        enc_conf_eq_entry(s1, s2, d1, d2, atkr)
    ensures enc_conf_eqpdb(d1', d2', atkr)
    ensures entering_atkr(d1, d2, dispPage, atkr, false) ==>
        (enc_conf_eq_entry(s1', s2', d1', d2', atkr) &&
        enc_start_equiv(s1, s2))
{
    // TODO proveme
    assume false;
}

lemma lemma_resume_enc_conf_ni(s1: state, d1: PageDb, s1':state, d1': PageDb,
                            s2: state, d2: PageDb, s2':state, d2': PageDb,
                            dispPage: word,
                            atkr: PageNr)
    requires ni_reqs(s1, d1, s1', d1', s2, d2, s2', d2', atkr)
    requires smc_resume(s1, d1, s1', d1', dispPage)
    requires smc_resume(s2, d2, s2', d2', dispPage)
    requires enc_conf_eqpdb(d1, d2, atkr)
    requires entering_atkr(d1, d2, dispPage, atkr, true) ==>
        enc_conf_eq_entry(s1, s2, d1, d2, atkr)
    ensures enc_conf_eqpdb(d1', d2', atkr)
    ensures entering_atkr(d1, d2, dispPage, atkr, true) ==>
        (enc_conf_eq_entry(s1', s2', d1', d2', atkr) &&
        enc_start_equiv(s1, s2))
{
    // TODO proveme
    assume false;
}

lemma lemma_initAddrspace_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                                    d2: PageDb, d2': PageDb, e2':word,
                                    addrspacePage:word, l1PTPage:word,
                                    atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_initAddrspace(d1, addrspacePage, l1PTPage) == (d1', e1')
    requires smc_initAddrspace(d2, addrspacePage, l1PTPage) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures  enc_conf_eqpdb(d1', d2', atkr) 
{
    //var atkr_asp := d1[atkr].addrspace;
    if( atkr == addrspacePage ) {
        assert enc_conf_eqpdb(d1', d2', atkr);
        assert e1' == e2';
    } else {
        forall(n : PageNr)
            ensures pgInAddrSpc(d1', n, atkr) <==>
                pgInAddrSpc(d2', n, atkr)
        {
            if(e1' == KOM_ERR_SUCCESS) {
                assert !pgInAddrSpc(d1', addrspacePage, atkr);
                assert !pgInAddrSpc(d1', l1PTPage, atkr);
                assert !pgInAddrSpc(d2', addrspacePage, atkr);
                assert !pgInAddrSpc(d2', l1PTPage, atkr);
                forall( n | validPageNr(n) && n != addrspacePage &&
                    n != l1PTPage && !pgInAddrSpc(d1, n, atkr))
                    ensures !pgInAddrSpc(d1', n, atkr) { }
                forall( n | validPageNr(n) && n != addrspacePage &&
                    n != l1PTPage && !pgInAddrSpc(d2, n, atkr))   
                    ensures !pgInAddrSpc(d2', n, atkr) { }
                assert forall n : PageNr :: pgInAddrSpc(d1', n, atkr) <==>
                    pgInAddrSpc(d2', n, atkr);
            }
        }
    }
}

lemma lemma_initDispatcher_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                                     d2: PageDb, d2': PageDb, e2':word,
                                     page:word, addrspacePage:word, entrypoint:word,
                                     atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_initDispatcher(d1, page, addrspacePage, entrypoint) == (d1', e1')
    requires smc_initDispatcher(d2, page, addrspacePage, entrypoint) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures  enc_conf_eqpdb(d1', d2', atkr) 
{
    if( atkr == addrspacePage ) {
        assert valAddrPage(d1', atkr);
        assert valAddrPage(d2', atkr);
        assert valAddrPage(d1', atkr) <==> valAddrPage(d2', atkr);
       
        forall(n : PageNr)
            ensures pgInAddrSpc(d1', n, atkr) <==> pgInAddrSpc(d2', n, atkr)
         {
            if(n == atkr) {
                assert pgInAddrSpc(d1, n, atkr) <==> pgInAddrSpc(d1', n, atkr);
                assert pgInAddrSpc(d2, n, atkr) <==> pgInAddrSpc(d2', n, atkr);
            }
            if(n == page) {
                var as1 := d1[atkr].entry.state;
                assert (pageIsFree(d1, n) && as1 == InitState) ==>
                   pgInAddrSpc(d1', n, atkr);
            }
            if(n != page && n != atkr){
                assert pgInAddrSpc(d1, n, atkr) <==> pgInAddrSpc(d1', n, atkr);
                assert pgInAddrSpc(d2, n, atkr) <==> pgInAddrSpc(d2', n, atkr);
            }
         }
         forall( n : PageNr | pgInAddrSpc(d1', n, atkr)) 
             ensures d1'[n].entry == d2'[n].entry { 
             assume (e1' == KOM_ERR_PAGEINUSE) <==> (e2' == KOM_ERR_PAGEINUSE);
             if(e1' == KOM_ERR_SUCCESS){
                assert d1'[atkr].entry == d2'[atkr].entry;
                assert d1'[page].entry == d2'[page].entry;
                if(n != atkr && n != page) {
                    assert d1'[n].entry == d1[n].entry;
                }
             }
        }
    } else {
        assert valAddrPage(d1, atkr);
        assert valAddrPage(d2, atkr);

        forall(n: PageNr)
            ensures pgInAddrSpc(d1', n, atkr) <==>
                pgInAddrSpc(d2', n, atkr)
        {
            assert pgInAddrSpc(d1, n, atkr) <==> pgInAddrSpc(d1', n, atkr);
            assert pgInAddrSpc(d2, n, atkr) <==> pgInAddrSpc(d2', n, atkr);
            if(n == addrspacePage){
                assert valAddrPage(d1, n) ==> d1[n].addrspace == n;
                assert valAddrPage(d2, n) ==> d2[n].addrspace == n;
            }
            if(validPageNr(addrspacePage) && n == page){
                var a := addrspacePage; 
                if(valAddrPage(d1, a)){
                    var as1 := d1[a].entry.state;
                    assert (pageIsFree(d1, n) && as1 == InitState) ==>
                       !pgInAddrSpc(d1', n, atkr);
                }
            }
        }

    }
}

lemma lemma_initL2PTable_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                                   d2: PageDb, d2': PageDb, e2':word,
                                   page:word, addrspacePage:word, l1index:word,
                                   atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_initL2PTable(d1, page, addrspacePage, l1index) == (d1', e1')
    requires smc_initL2PTable(d2, page, addrspacePage, l1index) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures enc_conf_eqpdb(d1', d2', atkr) 
{
    // PROVEME
    assume false;
}


predicate contentsOk(physPage: word, contents: Maybe<seq<word>>)
{
    (physPage == 0 || physPageIsInsecureRam(physPage) ==> contents.Just?) &&
    (contents.Just? ==> |fromJust(contents)| == PAGESIZE / WORDSIZE)
}

lemma lemma_mapSecure_enc_conf_ni(d1: PageDb, c1: Maybe<seq<word>>, d1': PageDb, e1':word,
                            d2: PageDb, c2: Maybe<seq<word>>, d2': PageDb, e2':word,
                            page:word, addrspacePage:word, mapping:word, 
                            physPage: word, atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires contentsOk(physPage, c1) && contentsOk(physPage, c2)
    requires smc_mapSecure(d1, page, addrspacePage, mapping, physPage, c1) == (d1', e1')
    requires smc_mapSecure(d2, page, addrspacePage, mapping, physPage, c2) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures enc_conf_eqpdb(d1', d2', atkr) 
{
    // PROVEME
    assume false;    
}

lemma lemma_mapInsecure_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                                  d2: PageDb, d2': PageDb, e2':word,
                                  addrspacePage:word, physPage: word, mapping: word,
                                  atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_mapInsecure(d1, addrspacePage, physPage, mapping) == (d1', e1')
    requires smc_mapInsecure(d2, addrspacePage, physPage, mapping) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures enc_conf_eqpdb(d1', d2', atkr) 
{
    // PROVEME
    assume false;
}

lemma lemma_remove_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                             d2: PageDb, d2': PageDb, e2':word,
                             page:word,
                             atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_remove(d1, page) == (d1', e1')
    requires smc_remove(d2, page) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures  enc_conf_eqpdb(d1', d2', atkr) 
{
    // PROVEME
    assume false;
}

lemma lemma_finalise_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                             d2: PageDb, d2': PageDb, e2':word,
                             addrspacePage:word,
                             atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_finalise(d1, addrspacePage) == (d1', e1')
    requires smc_finalise(d2, addrspacePage) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures  enc_conf_eqpdb(d1', d2', atkr) 
{
    // PROVEME
    assume false;
}

lemma lemma_stop_enc_conf_ni(d1: PageDb, d1': PageDb, e1':word,
                       d2: PageDb, d2': PageDb, e2':word,
                       addrspacePage:word,
                       atkr: PageNr)
    requires ni_reqs_(d1, d1', d2, d2', atkr)
    requires smc_stop(d1, addrspacePage) == (d1', e1')
    requires smc_stop(d2, addrspacePage) == (d2', e2')
    requires enc_conf_eqpdb(d1, d2, atkr)
    ensures  addrspacePage != atkr ==> enc_conf_eqpdb(d1', d2', atkr) 
{
    if(atkr == addrspacePage) {
        assert addrspacePage != atkr ==> enc_conf_eqpdb(d1', d2', atkr); 
    } else {
        forall(n : PageNr)
            ensures pgInAddrSpc(d1', n, atkr) <==> pgInAddrSpc(d2', n, atkr)
        {
            assert pgInAddrSpc(d1', n, atkr) <==> pgInAddrSpc(d1, n, atkr);
        }
    }
}

//-----------------------------------------------------------------------------
// Confidentiality, OS is NI with Enclaves 
//-----------------------------------------------------------------------------

predicate os_ni_reqs(s1: state, d1: PageDb, s1': state, d1': PageDb,
                     s2: state, d2: PageDb, s2': state, d2': PageDb)
{
    SaneState(s1) && validPageDb(d1) && SaneState(s1') && validPageDb(d1') &&
    SaneState(s2) && validPageDb(d2) && SaneState(s2') && validPageDb(d2') &&
    pageDbCorresponds(s1.m, d1) && pageDbCorresponds(s1'.m, d1') &&
    pageDbCorresponds(s2.m, d2) && pageDbCorresponds(s2'.m, d2')
}

lemma lemma_os_conf_ni(s1: state, d1: PageDb, s1': state, d1': PageDb,
                 s2: state, d2: PageDb, s2': state, d2': PageDb,
                 atkr: PageNr)
    requires os_ni_reqs(s1, d1, s1', d1', s2, d2, s2', d2')
    // If smchandler(s1, d1) => (s1', d1')
    requires smchandler(s1, d1, s1', d1')
    // and smchandler(s2, d2) => (s2', d2')
    requires smchandler(s2, d2, s2', d2')
    // s.t. (s1, d1) =_{os} (s2, d2)
    requires os_conf_eq(s1, s2)
    // then (s1', d1') =_{os} (s2', d2')
    ensures os_conf_eq(s1', s2')
{
    reveal_ValidRegState();
    var callno, arg1, arg2, arg3, arg4
        := s1.regs[R0], s1.regs[R1], s1.regs[R2], s1.regs[R3], s1.regs[R4];
    var e1', e2' := s1'.regs[R0], s2'.regs[R0];

    if(callno == KOM_SMC_QUERY || callno == KOM_SMC_GETPHYSPAGES){
        assume false;
    }
    else if(callno == KOM_SMC_INIT_ADDRSPACE){
        assume false;
    }
    else if(callno == KOM_SMC_INIT_DISPATCHER){
        assume false;
    }
    else if(callno == KOM_SMC_INIT_L2PTABLE){
        assume false;
    }
    else if(callno == KOM_SMC_MAP_SECURE){
        assume false;
    }
    else if(callno == KOM_SMC_MAP_INSECURE){
        assume false;
    }
    else if(callno == KOM_SMC_REMOVE){
        assume false;
    }
    else if(callno == KOM_SMC_FINALISE){
        assume false;
    }
    else if(callno == KOM_SMC_ENTER){
        assume false;
    }
    else if(callno == KOM_SMC_RESUME){
        assume false;
    }
    else if(callno == KOM_SMC_STOP){
        assume false;
    }
    else {
        assert e1' == KOM_ERR_INVALID;
        assert e2' == KOM_ERR_INVALID;
        assume false;
    }
}

//-----------------------------------------------------------------------------
// Integrity, Enclaves are NI with other Enclaves
//-----------------------------------------------------------------------------

lemma lemma_enter_enc_integ_ni(s1: state, d1: PageDb, s1':state, d1': PageDb,
                         s2: state, d2: PageDb, s2':state, d2': PageDb,
                         dispPage: word, arg1: word, arg2: word, arg3: word,
                         atkr: PageNr)
    requires ni_reqs(s1, d1, s1', d1', s2, d2, s2', d2', atkr)
    requires smc_enter(s1, d1, s1', d1', dispPage, arg1, arg2, arg3)
    requires smc_enter(s2, d2, s2', d2', dispPage, arg1, arg2, arg3)
    requires enc_integ_eqpdb(d1, d2, atkr)
    requires entering_atkr(d1, d2, dispPage, atkr, true) ==>
        enc_integ_eq(s1, s2, d1, d2, atkr)
    ensures enc_integ_eqpdb(d1', d2', atkr)
    ensures entering_atkr(d1, d2, dispPage, atkr, true) ==>
        enc_integ_eq(s1', s2', d1', d2', atkr)
{
    // TODO proveme
    assume false;
}

