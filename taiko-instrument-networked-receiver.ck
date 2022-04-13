// taiko drummer 
TaikoDrummer td;
JCRev rev => Gain drummerGain => dac;
.05 => rev.mix;
.5 => drummerGain.gain;

LiSa A[9];
LiSa B[4];
LiSa C[7]; // sticks
LiSa E[4]; // lowest drums

td.load_and_patch_taiko_samps(A, "A", rev);
td.load_and_patch_taiko_samps(B, "B", rev);
td.load_and_patch_taiko_samps(C, "C", rev);
td.load_and_patch_taiko_samps(E, "E", rev);

td.bpm_to_qt_note(86) => dur qt_note;

// gametrak
GameTrack gt;
gt.init(0);

// enter statement once when otherwise in triggered state
0 => int lastButtonState;
0 => int debounceRZ;
0 => int debounceRR;
0 => int debounceLZ;
0 => int debounceLL;


.3 => float TIER_1;
.6 => float TIER_2;

/* player 1 */
spork ~ generativeMode("/taiko/whole_note", E, gt.LZ, 4 * qt_note);
spork ~ generativeMode("/taiko/qt_note_quintuplet", C, gt.RZ, (2.0/5.0)*qt_note);

/* player 2 */
spork ~ generativeMode("/taiko/qt_note", A, gt.LZ, qt_note);
spork ~ generativeMode("/taiko/qt_note_triplet", B, gt.RZ, (2.0/3.0)*qt_note);

// button selects mode
while( true )
{
    if( !gt.buttonToggle ){
        manualMode();
    }
    10::ms => now;
}


fun void generativeMode(string address, LiSa lisas[], int z_idx, dur beat_dur) {
    // create our OSC receiver
    OscIn oin;
    // create our OSC message
    OscMsg msg;
    // use port 6449 (or whatever)
    6449 => oin.port;
    // create an address in the receiver, expect an int and a float
    // oin.addAddress( "/Taiko/notes, i f" );
    oin.addAddress( address );
    
    while (true) {
        // wait for event to arrive
        oin => now;

        if (!gt.buttonToggle) {  // in manual mode, skip
            continue; // manual mode, don't execute
        }

        gt.curAxis[z_idx] => float z;

        if (z < TIER_1) {
            <<< "tier 1" >>>;
            Util.remap(0.0, TIER_1, 0.0, 1.0, z) => float hit_prob;
            <<< "hit prob: ", hit_prob >>>;
            if (Math.randomf() < hit_prob) {
                <<< "hit" >>>;
                td.play_oneshot( lisas[Math.random2(0,lisas.size()-1)] );
            }
        } else if (z >= TIER_1 && z < TIER_2) {
            <<< "tier 2" >>>;
            Util.remap(TIER_1, TIER_2, 0, 1, z) => float hit_prob;
            if (Math.randomf() < hit_prob) { // double hit
                lisas[Math.random2(0,lisas.size()-1)] @=> LiSa @ lisa;
                td.play_oneshot( lisa );
                (beat_dur / 2.0) => now;
                td.play_oneshot( lisa );
            } else {
                td.play_oneshot( lisas[Math.random2(0,lisas.size()-1)] );
            }
        } else {
            <<< "tier 3" >>>;
            lisas[Math.random2(0,lisas.size()-1)] @=> LiSa @ lisa;
            td.play_oneshot( lisa );
            (beat_dur / 2.0) => now;
            td.play_oneshot( lisa );
        }
    }
}

// default mode is manual one-hit
fun void manualMode(){
    // gt.print();
    if( gt.curAxis[gt.RZ] > .1 )
    {
        // right forward punch
        if( gt.curAxis[gt.RY] > 0.5 && debounceRZ == 0 ) 
        {
            // <<<"BANG!">>>;
            1 => debounceRZ;
            td.play_oneshot( A[Math.random2(0,A.size()-1)] );
        }  
        if( gt.curAxis[gt.RY] < 0.5 ) 
        {
            0 => debounceRZ;
        }
        // right right punch
        if( gt.curAxis[gt.RX] > 0.3 && debounceRR == 0 )
        {
            1 => debounceRR;
            td.play_oneshot( A[Math.random2(0,A.size()-1)] );
        }
        if( gt.curAxis[gt.RX] < 0.3 ) 
        {
            0 => debounceRR;
        }
    }
    if( gt.curAxis[gt.LZ] > .1 )
    {
        // left forward punch
        if( gt.curAxis[gt.LY] > 0.5 && debounceLZ == 0 ) 
        {
            1 => debounceLZ;
            td.play_oneshot( B[Math.random2(0,B.size()-1)] );
        }  
        if( gt.curAxis[gt.LY] < 0.5 ) 
        {
            0 => debounceLZ;
        }
        // left left punch
        if( gt.curAxis[gt.LX] < -0.3 && debounceLL == 0 )
        {
            <<<"BANG!">>>;
            1 => debounceLL;
            td.play_oneshot( B[Math.random2(0,B.size()-1)] );
        }
        if( gt.curAxis[gt.LX] > -0.3 ) 
        {
            0 => debounceLL;
        }
    }   
}


