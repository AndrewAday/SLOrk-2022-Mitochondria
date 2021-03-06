/* =============== CONSTANTS =============== */
.10 => float stage1start;
.45 => float stage1end;
.58 => float stage2start;
.99 => float stage2end;

// how long stage 2 needs to be held before forcing stage3
6.5::second => dur stage2holdThreshold;
10::second => dur stage3lerpTime;  // how long to resolve from stage2 --> stage3

0::second => dur stage2consecutiveHold; 

// 1::second => dur stage2holdThreshold;
// 1::second => dur stage3lerpTime;  // how long to resolve from stage2 --> stage3

6 => int NUM_CHANNELS;
// 2 => int NUM_CHANNELS;

//150.0 => float maxDist; // max hand distance = 100%
130.0 => float maxDist; // max hand distance = 100%
.7 => float maxGain;

293.0 => float tonic;  // middle D

// note bank
Util.toChromaticScale(tonic) @=> float scale[];
scale[0] => float D3;
scale[1] => float Eb3;
scale[2] => float E3;
scale[3] => float F3;
scale[4] => float Fs3;
scale[5] => float G3;
scale[6] => float Gs3;
scale[7] => float A3;
scale[8] => float Bb3;
scale[9] => float B3;
scale[10] => float C4;
scale[11] => float Cs4;

// Stage 1 chord
G3 * .5 => float G2;
[
  Cs4, Cs4, Cs4,
  A3,
  Fs3,
  D3,
  B3 * .5,
  G2, G2
] @=> float stage1chord[];

// stage 2 chord
Fs3 * 2 => float Fs4;
D3 * .5 => float D2;
[
  Fs4, Fs4,
  Cs4,
  B3,
  G3,
  E3,
  A3 * .5,
  D2, D2
] @=> float stage2chord[];

// stage 3 chord
[
  Cs4 * 2,
  A3 * 2,
  F3 * 2,    // aug on A 
  Fs3,
  D3,
  Bb3 * .5,    // aug on D
  B3 * .25,
  G3 * .25,
  Eb3 * .25   // aug on G
] @=> float stage3chord[];


[  // big dmin
  D3 * 4,
  A3 * 2, 
  F3 * 2, 
  D3 * 2, 
  D3,
  D3 * .5,
  A3 * .25, 
  F3 * .25, 
  D3 * .25
] @=> float stage4chord[];


/* =============== UTIL =============== */

0. => float pwmDepth;
400 => float fcBase;
.85 => float fcDepth; // wider apart, the less we modulate for fuller sound
fun void pwm(int idx, PulseOsc @ p, LPF @ l, Gain @ g, float wf, float lf, float gf) {
    /* now + fadein => time later; */
  while (true) {

    // mod pulse width
    if (idx % 3 == 0) {  // only do every other, too expensive
      .5 + pwmDepth * Util.lfo(wf) => p.width;
    }
    // .5 + .4 * Util.lfo(wf) => p.width;

    // mod filter cutoff
    fcBase + (fcDepth * fcBase) * Util.lfo(lf) => l.freq;
    /* 4000 => l.freq; */

    // TODO: mod pan?
    /* Math.sin(2*pi*pf*(now/second))=>pan.pan; */

    20::ms => now;
  }
}




/* =============== Setup =============== */
// GameTrak HID
GameTrack gt;
gt.init(0);  // also sporks tracker

// Drummer setup
TaikoDrummer td;
Gain drumGain;

  // TODO: fix signal flow, route drums and voices through single main gain, which branches to dac
patch_to_hemi(drumGain);
0.0 => drumGain.gain;

LiSa heartbeat[1];
LiSa E[4];
td.load_and_patch_taiko_samps(heartbeat, "heartbeat", drumGain);
td.load_and_patch_taiko_samps(E, "E", drumGain);
.7 => heartbeat[0].gain;
for (int i; i < 4; i++) {
  .5 => E[i].gain;
}

fun void patch_to_hemi(UGen @ u) {
  for (int i; i < NUM_CHANNELS; i++) {
    u => dac.chan(i);
  }
}

// connect UGens
stage3chord.size() => int numVoices;
PulseOsc voices[numVoices];
LPF lpfs[numVoices];
Gain gains[numVoices];
/* Chorus chorus => NRev rev => OverDrive drive => dac; */
Chorus chorus => LPF mainLPF => NRev rev => Echo e1 => Echo e2;

patch_to_hemi(rev);


/* Chorus chorus => NRev rev => Fuzz fuzz => dac;  */

/* .0 => fuzz.mix; */  // distortion clips :(
/* .0 => drive.mix; */

400 => mainLPF.freq;
.9 => mainLPF.gain;

.0 => rev.mix;

// chorus settings
.0 => chorus.mix;
.2 => chorus.modFreq;
.07 => chorus.modDepth;

// setup signal flow
for (0 => int i; i < numVoices; i++) {
  voices[i] => lpfs[i] => gains[i] => chorus;

  Math.random2f(1.0/8, 1.0/11) => float wf;  // pulse width mod rate
  Math.random2f(1.0/7, 1.0/5) => float lf;  // low pass cutoff mod rate
  Math.random2f(1.0/7, 1.0/5) => float gf;  // gain mod rate

  spork ~ pwm(i, voices[i], lpfs[i], gains[i], wf, lf, gf);
  /* spork ~ this.pwm(p2, l2, g2, pan2, 1./12, 1./16, 1./14, -1./18); // pan in opposite direction! */

  // set freq
  tonic => voices[i].freq;

  // set voice gain
  .5 / numVoices => voices[i].gain;
  0.0 => gains[i].gain;

  // TODO: add spatialization here?
    // ranomize which channel the voice is playing from
    // OR split each voice into 6 gains, each feeding into a speaker
      // as hands widen, ramp all to full gain
}

// nice_thx();


fun void set_all_voice_gains(float g) {
  for (0 => int i; i < numVoices; i++) {
      g => gains[i].gain;
  }
}

/*==========Phase 1=============*/

// lerp stage 1
false => int inStage1;  // true when inside stage1 chord
false => int inStage2; // true when inside stage2 chord zone
false => int aboveStage1;  // true when position > stage1 end
false => int inStage3;
60.0 => float beat_bpm;
86.0 => float heartbeat_bpm;

// heartbeat pattern
fun void heartbeat_pattern() {
  while (true) {
    if (!inStage2 || inStage3) {
      15::ms => now;
      continue;
    }
    // Math.random2(0, E.cap()-1) => int idx1;
    // Math.random2(0, E.cap()-1) => int idx2;

    // TODO: does this need to be networked synced with other drums?
    // td.play_heartbeat_pattern(td.bpm_to_qt_note(92), E[3], E[3], 1);
    td.play_heartbeat_pattern(td.bpm_to_qt_note(heartbeat_bpm), E[3], E[3], 1);

  }
} spork ~ heartbeat_pattern();

fun void stage1_drum_pattern() {
  while (true) {
    if (inStage1) {
      td.play_oneshot(heartbeat[0]);
      td.bpm_to_qt_note(60) => now;  // does this need to be networked synced with other drums?
    } else if (aboveStage1 && !inStage2) {
      td.play_oneshot(heartbeat[0]);
      td.bpm_to_qt_note(beat_bpm) => now;  // accelerate to 92bpm
    } else {
      15::ms => now;
    }
  }

} spork ~ stage1_drum_pattern();

fun void update_all_voice_params(float percentage) {
  // scale params for all voices
  for (0 => int i; i < numVoices; i++) {
    // voice gain
    percentage * maxGain => gains[i].gain;

    // pwm
    percentage * .40 => pwmDepth;

    // drum gain mod
    percentage * 0.65 => drumGain.gain;

    // lp freq mod
    percentage * (5400) + 400 => fcBase;
    ((1.0 - percentage) * .75) + .10 => fcDepth;  // inverse scale fc mod depth

    // main lp
    // 1.5 * percentage * (5400) + 400 => mainLPF.freq;
    1.5 * percentage * (5400) + 1400 => mainLPF.freq;
    // <<< mainLPF.freq() >>>;


    // effects mod
    percentage * .30 => rev.mix;
    percentage * .75 => chorus.mix;
  }
}

while (true) {
  gt.GetXZPlaneHandDist() => float handDist;
  // <<< "handDist: ", handDist >>>;
  // <<< "height", gt.GetCombinedZ() >>>;
  Util.clamp01(gt.invLerp(0, maxDist, handDist)) => float percentage;
  // <<< "percentage: ", percentage >>>;

  // stage enter/exit events booleans
  if (!(percentage >= stage1end && percentage <= stage2start)) {
    if (inStage1) {
      <<< "exiting stage1 resolution" >>>;
    }
    false => inStage1;
  }
  if (!(percentage >= stage2end)) {
    if (inStage2) <<< "existing stage2 resoltion" >>>;
    false => inStage2;
    // reset stage2 timer
    0::ms => stage2consecutiveHold;
    // <<< "stage2 hold: ", stage2consecutiveHold >>>; 
  }
  if (percentage >= stage2start && percentage <= stage2end) {
    true => aboveStage1;
  } else {
    false => aboveStage1;
    
  }

  // update voice timbres
  update_all_voice_params(percentage * .5);   // clamped to [0, .5]

  // update voice pitch, drum bpm
  if (percentage < stage1start) { // hold tonic

  } else if (percentage >= stage1start && percentage < stage1end) {
    for (0 => int i; i < numVoices; i++) {
      Util.remap(stage1start, stage1end, tonic, stage1chord[i], percentage) => voices[i].freq;
    }
  } else if (percentage >= stage1end && percentage < stage2start) {  // between stages
    if (!inStage1) {
      <<< "entered stage1 resolution!" >>>;
      true => inStage1;
    }
  } else if (percentage >= stage2start && percentage <= stage2end) { // stage 2
    // remap BPM
    Util.remap(stage2start, stage2end, 60.0, 166.0, percentage) => beat_bpm;

    // remap pitch
    Util.invLerp(stage2start, stage2end, percentage) => float t;
    for (0 => int i; i < numVoices; i++) {
      Util.lerp(stage1chord[i], stage2chord[i], t) => voices[i].freq;

      // lerp overdrive
      /* lerp(.0, .5, t) => drive.mix; */
    }
  } else {  // past stage 2
    if (inStage2) {
      20::ms +=> stage2consecutiveHold;
    }
    if (!inStage2) {
      <<< "entered stage2 resolution!" >>>;
      true => inStage2;
    }
  }

  if (stage2consecutiveHold > stage2holdThreshold) {
    break;
  }

  20::ms => now;
}


<<< "entering stage 3" >>>;
now => time startStage3;
1.0 => float maxZHeight;
startStage3 + stage3lerpTime => time enterStage3;
while (true) {
  if (now <= enterStage3) {
    // lerp voice freq
    for (0 => int i; i < numVoices; i++) {
      Util.remap(
        startStage3, enterStage3,
        stage2chord[i], stage3chord[i], 
        now
      ) => voices[i].freq;
    }
    // lerp heartbeat bpm
    Util.remap(
      startStage3, enterStage3,
      86.0, 160.0, 
      now
    ) => heartbeat_bpm;

    // lerp voice timbre, percentage : [.5, .75]
    .5 + (.25 * Util.clamp01(gt.invLerp(startStage3, enterStage3, now))) => float percentage;
    // percentage from [.5, .75]
    update_all_voice_params(percentage);

    Util.printLerpProgress(Util.invLerp(startStage3, enterStage3, now));
  } else {
    if (!inStage3) {
      true => inStage3;
      gt.GetCombinedZ() => maxZHeight;
      <<< "entered stage3" >>>;
    }
    break;
    

  }
  15::ms => now;
}

chout <= "=========stage 4=========" <= IO.newline();
stage4();

fun void stage4() {
  // 1.15 => float resHeight;
  // .95 => float fadeHeight;
  .6 => float resHeight;
  .30 => float fadeHeight;
  while (true) {
    // <<< gt.GetCombinedZ() >>>;
    // lerp height to volume
    // maxGain * Util.clamp01(Util.invLerp(.1, maxZHeight, gt.GetCombinedZ())) => float newGain;

    // remap pitch
    Util.clamp01(Util.invLerp(maxZHeight, resHeight, gt.GetCombinedZ())) => float t;
    // <<< t >>>;
    // <<< gt.GetCombinedZ() >>>;

    Util.printLerpProgress(t);

    // lerp pitch
    for (0 => int i; i < numVoices; i++) {
      Util.lerp(stage3chord[i], stage4chord[i], t) => voices[i].freq;
      // newGain => gains[i].gain;
    }

    // lerp volume, timbre
    .75 + (.25 * t) => float percentage;
    // percentage from [.75, 1.0]
    update_all_voice_params(percentage);
    
    if (gt.GetCombinedZ() < fadeHeight) {
      break;  // exit stage 4
    }

    15::ms => now;
  }

  <<< "releasing stage4 chord" >>>;

  // drop gains to 0
  // .5::second => dur release;
  // now => time relStart;
  // release + now => time relEnd;
  // while (now < relEnd) {
  //   maxGain * Util.remap(relStart, relEnd, 1, 0, now) => float newGain;
  //   for (0 => int i; i < numVoices; i++) {
  //     newGain => gains[i].gain;
  //   }
  //   10::ms => now;
  // }

  // for (0 => int i; i < numVoices; i++) {
  //     0 => gains[i].gain;
  // }

  // play ending drum
  while (true) {
    Util.clamp01(Util.invLerp(.2, fadeHeight, gt.GetCombinedZ())) => float t;
    // lerp gains to 0
    for (0 => int i; i < numVoices; i++) {
      // sustain energy until collapse
      // t * maxGain => gains[i].gain;
    }

    if (gt.GetCombinedZ() < .1) {
        set_all_voice_gains(0);
        td.play_oneshot(heartbeat[0]);
        break;
    }
    10::ms => now;
  }
}

chout <= "=========end phase 1=========" <= IO.newline();

10::second => now;


// phase 2 instrument.

phase2();

false => int final_stage;

// heartbeat pattern
fun void end_heartbeat() {
  while (true) {
    if (!final_stage) {
      10::ms => now;
      continue;
    }

    td.play_heartbeat_pattern(td.bpm_to_qt_note(60.0), E[3], E[3], 1);
  }
}




fun void phase2() {
  chout <= "=========begin phase 2=========" <= IO.newline();
  
  disconnect_thx();

  Gain l_voice_gain => rev; 0 => l_voice_gain.gain;
  Gain r_voice_gain => rev; 0 => r_voice_gain.gain;

  // also try wtx
  // create_granulator("./Samples/Drones/tpl-organ.wav", l_voice_gain) @=> Granulator l_voice;
  // create_granulator("./Samples/Drones/tpl-organ.wav", r_voice_gain) @=> Granulator r_voice;
  create_granulator("./Samples/Drones/wtx-1.wav", l_voice_gain) @=> Granulator l_voice;
  create_granulator("./Samples/Drones/wtx-1.wav", r_voice_gain) @=> Granulator r_voice;

  // set octave lower
  .5 => l_voice.GRAIN_PLAY_RATE;

  /*
  // phase2 presets
    // re-nable filter sweeping
  .85 => fcDepth;
    // set voices gains
  set_all_voice_gains(0.0);
    // set mod effects
  .8 => chorus.mix;
  .5 => rev.mix;  // HIGH reverb 
    // echoes
  500::ms => e1.max => e1.delay;
  1000::ms => e2.max => e2.delay;
  .5 => e1.gain;
  .3 => e2.gain;
    // main LPF
  400 => mainLPF.freq;
  */

  // interaction constants
  .55 => float  MAX_Z;  // everything in final state at this height
  .025 => float GT_Z_DEADZONE;
  
  // patch_to_hemi(e2);  // connect echo to dac

  // <<< "patching nice" >>>;
  // nice_thx();
  // <<< "patched nice" >>>;

  spork ~ end_heartbeat();  // heartbeat listener
  
  // set initial state pitch
  C4 / 8.0 => float C1;
  G3 / 4.0 => float G1;
  C1 * 2.0 => float C2;
  E3 / 2.0 => float E2;
  G1 * 2.0 => float G2;


  // initialize voice freqs
  // set_all_voice_freqs(G1);

  0.0 => float left_percentage;  // tracking z axis progress
  0.0 => float right_percentage;  // tracking z axis progress
  while (true) {
    gt.curAxis[gt.LZ] => float left_z;
    gt.curAxis[gt.RZ] => float right_z;

    if (left_z < GT_Z_DEADZONE) {
        0.0 => left_percentage;
    } else {
        Util.clamp01(gt.invLerp(GT_Z_DEADZONE, MAX_Z, left_z)) => left_percentage;
    }

    if (right_z < GT_Z_DEADZONE) {
        0.0 => right_percentage;
    } else {
        Util.clamp01(gt.invLerp(GT_Z_DEADZONE, MAX_Z, right_z)) => right_percentage;
    }

    // lerp pitch
    // Util.lerp(G1, C1, left_percentage) => float l_freq;
    // set_range_voice_freqs(l_freq, 0, 5);
    // Util.lerp(G1, C2, right_percentage) => float r_freq;
    // set_range_voice_freqs(r_freq, 5, numVoices);

      // nice pitch
    // l_freq => nice_voices[0].freq;
    // r_freq => nice_voices[1].freq;

    // lerp gain
    // Util.lerp(0.0, .6, left_percentage) => float l_gain;
    // Util.lerp(0.0, .6, right_percentage) => float r_gain;
    .5 * left_percentage * left_percentage => float l_gain;
    .5 * right_percentage * right_percentage => float r_gain;
    // set_range_voice_gains(l_gain, 0, 5);
    // set_range_voice_gains(r_gain, 5, numvoices);

    l_gain => l_voice_gain.gain;
    r_gain => r_voice_gain.gain;

    // grain pos (remap to [0,.5] to prevent clipping at edge of sample)
    left_percentage * .5 => l_voice.GRAIN_POSITION; 
    right_percentage * .5 => r_voice.GRAIN_POSITION;

      // evil thx gain
    // set_range_voice_gains(l_gain, 0, 2);
    // set_range_voice_gains(r_gain, 2, 4); 
      // nice gain
    // l_gain => nice_gains[0].gain;
    // r_gain => nice_gains[1].gain;
    
    // lerp FC (maybe not, too aggressive?)
    // Util.lerp(400, 10000, .5 * (left_percentage + right_percentage)) => float lp_cutoff;
    // Util.lerp(10000.0, 400, .5 * (left_percentage + right_percentage)) => float lp_cutoff;
    // lp_cutoff => mainLPF.freq;

    // reintroduce heartbeat
    if (left_percentage >= .99 && right_percentage >= .99) {
      true => final_stage;
    } else {
      false => final_stage;
    }

    20::ms => now;
  }
}

fun void disconnect_thx() {
  mainLPF =< rev;
}

fun void set_all_voice_freqs( float f )  {
  for (0 => int i; i < numVoices; i++) {
      f => voices[i].freq;
  }
}

fun void set_range_voice_freqs(float f, int start, int end) {
  for (start => int i; i < end; i++) {
      f => voices[i].freq;
  }
}

fun void set_range_voice_gains(float g, int start, int end) {
  for (start => int i; i < end; i++) {
      g => gains[i].gain;
  }
}


fun void set_all_voice_gains_random(float g) {
  for (0 => int i; i < numVoices; i++) {
      Math.random2f(g*.7, g*1.3) => gains[i].gain;
  }
}


fun Granulator create_granulator(string filepath, UGen @ out) {
  Granulator drone;
  drone.init(filepath, out);

  spork ~ drone.granulate();

  return drone;
}







// random ideas
 /*
    continuous pitch
      smoothed pitch interpolation?
      different lerp rates for the 9 voices?
    add variable delay, echo?
    vibrato
      - vibrato freq
      - vibrato depth
    tremolo
      - freq
      - depth

    Split into 2 groups, high/right low/left, separated by an octave, each given 4-5 voices
      - allows 2-voice counterpoint melodic line

    gt button to enable saw pump (see minilogue patch, Barwick "In Light") sidechaining mode
      - + gentle kick on the falling edge
      - saw wave pump envelope on gain AND mainLPF cutoff

    quantize z axis into d minor scale, only set a new target when the z is in
    a new zone && the y axis is past a certain threshold
      - upon receiving new target, lerp the voices for that joystick at different rates
      - want to feel like moving two pulsating, entangled balls of energy.
    
    listen to Barwick "Flowers" -- way to add aggressive/dark rhythmic pulse
      - square wave env on pulse width? or filter cutoff?
      - rapid ADSR arpegiattion on/off?
      - apply to base organ voice OR to melodic balls?

    X-axis to roll/spread out voices into fifths/fourths above/below the center pitch?
      - might be too much, keep it simple and preserve the single-line melodic quality 

  */