/* =============== CONSTANTS =============== */
.10 => float stage1start;
.55 => float stage1end;
.68 => float stage2start;
.93 => float stage2end;

// how long stage 2 needs to be held before forcing stage3
5::second => dur stage2holdThreshold;
0::second => dur stage2consecutiveHold; 
10::second => dur stage3lerpTime;  // how long to resolve from stage2 --> stage3

// 6 => int NUM_CHANNELS;
2 => int NUM_CHANNELS;

150.0 => float maxDist; // max hand distance = 100%
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
  F3 * 2, A3 * 2, Cs4 * 2,  // aug on A 
  Bb3 * .5, D3, Fs3,  // aug on D
  Eb3 * .25, G3 * .25, B3 * .25 // aug on G
] @=> float stage3chord[];


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
for (int i; i < NUM_CHANNELS; i++) {
   drumGain => dac.chan(i);
}
0.0 => drumGain.gain;

LiSa heartbeat[1];
LiSa E[4];
td.load_and_patch_taiko_samps(heartbeat, "heartbeat", drumGain);
td.load_and_patch_taiko_samps(E, "E", drumGain);
.7 => heartbeat[0].gain;
for (int i; i < 4; i++) {
  .5 => E[i].gain;
}

// connect UGens
stage3chord.size() => int numVoices;
PulseOsc voices[numVoices];
LPF lpfs[numVoices];
Gain gains[numVoices];
/* Chorus chorus => NRev rev => OverDrive drive => dac; */
Chorus chorus => NRev rev;
for (int i; i < NUM_CHANNELS; i++) {
   rev => dac.chan(i);
}
/* Chorus chorus => NRev rev => Fuzz fuzz => dac;  */

/* .0 => fuzz.mix; */  // distortion clips :(
/* .0 => drive.mix; */
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



// lerp stage 1
false => int inStage1;  // true when inside stage1 chord
false => int inStage2; // true when inside stage2 chord zone
false => int aboveStage1;  // true when position > stage1 end
false => int inStage3;
60.0 => float beat_bpm;


// heartbeat pattern
fun void heartbeat_pattern() {
  while (true) {
    if (!inStage2 || inStage3) {
      15::ms => now;
      continue;
    }
    // Math.random2(0, E.cap()-1) => int idx1;
    // Math.random2(0, E.cap()-1) => int idx2;
    td.play_heartbeat_pattern(td.bpm_to_qt_note(92), E[3], E[3], 1);
    /* <<< "idx1: ", idx1, " idx2: ", idx2 >>>; */
  }
} spork ~ heartbeat_pattern();

fun void stage1_drum_pattern() {
  while (true) {
    if (inStage1) {
      td.play_oneshot(heartbeat[0]);
      td.bpm_to_qt_note(60) => now;
    } else if (aboveStage1 && !inStage2) {
      td.play_oneshot(heartbeat[0]);
      td.bpm_to_qt_note(beat_bpm) => now;  // accelerate to 92bpm
    } else {
      15::ms => now;
    }
  }

} spork ~ stage1_drum_pattern();

while (true) {
  gt.GetXZPlaneHandDist() => float handDist;
  // <<< "handDist: ", handDist >>>;
  Util.clamp01(gt.invLerp(0, maxDist, handDist)) => float percentage;

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

  // scale params for all voices
  for (0 => int i; i < numVoices; i++) {
    // voice gain
    percentage * maxGain => gains[i].gain;

    // pwm
    percentage * .40 => pwmDepth;

    // drum gain mod
    percentage * 0.6 => drumGain.gain;

    // lp freq mod
    percentage * (5400) + 400 => fcBase;
    ((1.0 - percentage) * .75) + .10 => fcDepth;  // inverse scale fc mod depth

    // effects mod
    percentage * .30 => rev.mix;
    percentage * .75 => chorus.mix;
  }

  // chord stage scaling
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
      <<< stage2consecutiveHold >>>;
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
    for (0 => int i; i < numVoices; i++) {
      Util.remap(
        startStage3, enterStage3,
        stage2chord[i], stage3chord[i], 
        now
      ) => voices[i].freq;
    }

    Util.printLerpProgress(Util.invLerp(startStage3, enterStage3, now));
  } else {
    if (!inStage3) {
      true => inStage3;
      gt.GetCombinedZ() => maxZHeight;
      <<< "entered stage3" >>>;
    }
    // gt.print();
    // lerp height to volume
    maxGain * Util.clamp01(Util.invLerp(.1, maxZHeight, gt.GetCombinedZ())) => float newGain;
    for (0 => int i; i < numVoices; i++) {
      newGain => gains[i].gain;
    }
  }
  15::ms => now;
}
