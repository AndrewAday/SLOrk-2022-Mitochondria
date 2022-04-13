// taiko drummer 
TaikoDrummer td;
JCRev rev => Gain drummerGain => dac;
.05 => rev.mix;
.5 => drummerGain.gain;

LiSa A[9];
LiSa B[4];

td.load_and_patch_taiko_samps(A, "A", rev);
td.load_and_patch_taiko_samps(B, "B", rev);

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

spork ~ generativeMode(A, gt.LZ, qt_note);
spork ~ generativeMode(B, gt.RZ, (2.0/3.0)*qt_note);

// button selects mode
while( true )
{
    if( !gt.buttonToggle ){
        manualMode();
    }
    10::ms => now;
}


fun void generativeMode(LiSa lisas[], int z_idx, dur beat_dur) {
    while (true) {
        if (!gt.buttonToggle) {
            beat_dur => now;
            continue; // manual mode, don't execute
        }

        gt.curAxis[z_idx] => float z;

        <<< z >>>;

        if (z < TIER_1) {
            <<< "tier 1" >>>;
            Util.remap(0.0, TIER_1, 0.0, 1.0, z) => float hit_prob;
            <<< "hit prob: ", hit_prob >>>;
            if (Math.randomf() < hit_prob) {
                <<< "hit" >>>;
                td.play_oneshot( lisas[Math.random2(0,lisas.size()-1)] );
            }
            beat_dur => now;
        } else if (z >= TIER_1 && z < TIER_2) {
            <<< "tier 2" >>>;
            Util.remap(TIER_1, TIER_2, 0, 1, z) => float hit_prob;
            if (Math.randomf() < hit_prob) { // double hit
                lisas[Math.random2(0,lisas.size()-1)] @=> LiSa @ lisa;
                td.play_oneshot( lisa );
                (beat_dur / 2.0) => now;
                td.play_oneshot( lisa );
                (beat_dur / 2.0) => now;
            } else {
                td.play_oneshot( lisas[Math.random2(0,lisas.size()-1)] );
                beat_dur => now;
            }
        } else {
            <<< "tier 3" >>>;
            lisas[Math.random2(0,lisas.size()-1)] @=> LiSa @ lisa;
            td.play_oneshot( lisa );
            (beat_dur / 2.0) => now;
            td.play_oneshot( lisa );
            (beat_dur / 2.0) => now;
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


