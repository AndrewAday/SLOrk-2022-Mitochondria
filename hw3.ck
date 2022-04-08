/*
BPM: 188
TODO: add kick on every repeat of sequence
TODO:
- drone voice mode
  - add pitch interpolation?
- All Voice modes
  - <D> to delete selected voice

Scale Modifier Mode
- SCALE SWITCHER/ constructor mode
- cycle through presets OR
- EXTRA: manually construct scale


End mode: press enter, set all gains to 0

TODO: e.c. sibelius outro
*/

"sequencer" => string SEQ_TYPE;
"drone" => string DRONE_TYPE;

/* [1., 2/3., 3/4., 9/8., 6/5., 4/3., 3/2.] @=> float scale[]; // allowed notes */

[
[1., 2/3., 3/4., 9/10., 9/8., 6/5., 4/3., 3/2.],
[5/6., 3/4., 1., 9/8., 5/4., 3/2., 5/3.]  // penta min
]@=> float SCALES[][];

[
"aeolian hexa",
"penta minor"
] @=> string SCALE_NAMES[];
int scale_idx;  // for browsing

SCALES[scale_idx] @=> float scale[];
scale_idx => int cur_scale_idx;
[3/4., 1., 9/8., 6/5., 4/3.] @=> float init_seq[];

int REHEARSAL;

188. => float BPM;
(60. / (BPM))::second => dur qt_note;  // seconds per quarter note

[
"basal-0.wav",
"basal-1.wav",
"energy-lead.wav",
"energy-drone.wav",  // 3
"wtx-0.wav",
"wtx-1.wav",
"wtx+1.wav",
"einstein.wav",  // 7
// TODO: retune the below 3
"lamonte.wav",
"tanpura.wav",
"tuvan.wav",  // 10
"female-choir.wav",
"male-choir.wav"  // 12
] @=> string drone_paths[];

/* SndBuf @ BUFFS[0]; */

// pre-load sndbufs to prevent clipping
for (int i; i < drone_paths.cap(); i++) {
  /* drone_paths[i] => string fp;
  SndBuf b @=> BUFFS[fp];
  "drones/" + fp => BUFFS[fp].read; */

  //TODO: remove this it doesn't actually prevent clipping.
}


// SEQUENCE Manipulator
SeqMan seqman;
seqman.init(init_seq, scale);

// Sequencer state params
Granulator @ seq_grans[1];
0 => int seq_idx;  // which sequencer voice are we looking at?

// lead granulator
add_seq(drone_paths[0], 0, 1., 1., 1.);
add_seq(drone_paths[6], 1, 0., 0, 1.);
add_seq(drone_paths[2], 2, 0., 0, 1.);
add_seq(drone_paths[0], 3, 0., 0, 1.);

// connect sequencer to granulators
spork ~ step_seq(seqman);


fun void add_seq(string filepath, int idx, float gain, float off, float deg) {
  // initialize new sequencer
  Granulator seq_gran;
  seq_gran.init(filepath, SEQ_TYPE);
  off => seq_gran.GRAIN_PLAY_RATE_OFF;
  gain => seq_gran.lisa.gain;
  deg => seq_gran.GRAIN_SCALE_DEG;
  qt_note / 4. => seq_gran.GRAIN_LENGTH;
  // TODO: lfo cycle release or expose param to control attack shape
  seq_gran.adsr.set(
    qt_note / 6.,
    qt_note / 6.,
    .6,
    qt_note / 2.
  );
  spork ~ seq_gran.cycle_pos();
  spork ~ seq_gran.granulate();

  // add sequencer to global sequencers array
  if (idx > seq_grans.cap()-1) {
    Granulator @ n_seq_grans[idx+1];  // allocate new sequencers array
    for (int i; i < seq_grans.cap(); i++) {
      seq_grans[i] @=> n_seq_grans[i];
    }
    seq_gran @=> n_seq_grans[idx];  // add new granulator
    n_seq_grans @=> seq_grans;  // reassign global sequencers pointer
  } else {
    seq_gran @=> seq_grans[idx];
  }
}


// Drone state params
Granulator @ drone_grans[2];
0 => int drone_idx;

// init drone
add_drone(drone_paths[10], 0, 0, 0, 1.);
add_drone(drone_paths[7], 1, 0, 0, 1.);
add_drone(drone_paths[3], 2, 0, 0, 1.);
add_drone(drone_paths[11], 3, 0, 0, 1.);
add_drone(drone_paths[0], 4, 0, 0, 1.);
add_drone(drone_paths[12], 5, 0, 0, 1.);
add_drone(drone_paths[8], 6, 0, 0, 1.);

fun void add_drone(string filepath, int idx, float gain, float off, float deg) {
  if (idx >= drone_grans.cap()) {
    Granulator @ n_drone_grans[idx+1];
    for (int i; i < drone_grans.cap(); i++) {
      drone_grans[i] @=> n_drone_grans[i];
    }
    n_drone_grans @=> drone_grans;
  }
  Granulator drone;
  drone @=> drone_grans[idx];
  /* drone.init(filepath, DRONE_TYPE, BUFFS[filepath]); */
  drone.init(filepath, DRONE_TYPE);
  gain => drone.lisa.gain;
  off => drone.GRAIN_PLAY_RATE_OFF;
  deg => drone.GRAIN_SCALE_DEG;
  spork ~ drone.cycle_pos();
  spork ~ drone.granulate();
  //TODO: add pitch interpolation?
  //TODO: add gain interpolation spork.
}


/* ==== Drone and Sequencer Helper Fns ==== */

fun void step_seq(SeqMan @ seqman) {
  while (true) {
    seqman.seq @=> float seq[];
    for (int i; i < seq.cap(); i++) {
      // TODO: interp/slew this for drones?
      for (int j; j < seq_grans.cap(); j++) {
        seq[i] => seq_grans[j].GRAIN_PLAY_RATE;
        seq_grans[j].adsr.keyOn();
      }
      qt_note/4. => now;
      for (int j; j < seq_grans.cap(); j++) {
        seq_grans[j].adsr.keyOff();
      }
      qt_note/4. => now;
    }
  }
}

fun void print_voices(string type) {
  Granulator @ grans[];
  int idx;
  if (type == SEQ_TYPE) {
    seq_grans @=> grans;
    seq_idx => idx;
  } else if (type == DRONE_TYPE) {
    drone_grans @=> grans;
    drone_idx => idx;
  }
  "" => string ret;
  for (int i; i < grans.cap(); i++) {
    grans[i] @=> Granulator @ g;
    if (i == idx) {
      "[--->" +=> ret;
    }

    g.sample + ": " +=> ret;
    // TODO: add some kind of volume control?
    // maybe have another idx variable
    // when idx is on that drone voice, put a box [~ ... ~]
    // and use arrow keys to live-adjust volume/granular params/register?/etc.
    if (g.MUTED) {
      "MUT" +=> ret;
    } else {
      g.lisa.gain() +=> ret;
    }

    "~" +=> ret;
    g.GRAIN_PLAY_RATE_OFF $ int +=> ret;

    "~" +=> ret;
    g.GRAIN_SCALE_DEG +=> ret;

    if (i == idx) {
      "<---] " +=> ret;
    }

    " | " +=> ret;
  }
  <<< ret >>>;
  <<< "                                 |                                 " >>>;
  <<< "                                 |                                 " >>>;
}


/* ===Vars and Fns for voice adder mode === */
/*
Voice adder
- voice type
- voice register
- source sample name
- entrance volume (default 0)
- press <enter> to add
  - DOES increment rehearsal
  - print: |Entering New Player: DRONE/SEQUENCER <sample name> |
 */
0 => int voice_bank_idx;
DRONE_TYPE => string voice_type;
0 => int voice_off;
0 => int voice_deg_idx;
0 => float voice_gain;

fun void print_voice_mode() {
  <<<
  " voice type: ", voice_type, " | ",
  " sample: ", drone_paths[voice_bank_idx], " | ",
  " off: ", voice_off, " | ",
  " deg: ", scale[voice_deg_idx], " | ",
  " gain: ", voice_gain, " | ">>>;
}

fun void add_voice() {
  if (voice_type == DRONE_TYPE) {

    add_drone(drone_paths[voice_bank_idx], drone_grans.cap(), voice_gain, voice_off, scale[voice_deg_idx]);
  } else if (voice_type == SEQ_TYPE) {
    add_seq(drone_paths[voice_bank_idx], seq_grans.cap(), voice_gain, voice_off, scale[voice_deg_idx]);
  }

  <<< "--------------------------------------------" >>>;
  <<< "|                                          |" >>>;
  <<< "|            ENTERING NEW PLAYER           |" >>>;
  <<< " |       ", voice_type, drone_paths[voice_bank_idx], "                   |" >>>;
  <<< "--------------------------------------------" >>>;

  reset_voice_mode();
}

fun void reset_voice_mode() {
  0 => voice_bank_idx;
  0 => voice_off;
  0 => voice_deg_idx;
  0 => voice_gain;
}

fun void print_scales() {
  "current: " + SCALE_NAMES[cur_scale_idx] + " | " => string ret;
  "select: " + SCALE_NAMES[scale_idx] +=> ret;
  <<< ret >>>;
}

fun void equip_scale(int idx) {
  idx => cur_scale_idx;
  SCALES[idx] @=> seqman.scale;
  SCALES[idx] @=> scale;
  <<< "--------------------------------------------" >>>;
  <<< "|                                          |" >>>;
  <<< "|            EQUIPPING NEW SCALE           |" >>>;
  <<< " |               ", SCALE_NAMES[idx], "              |" >>>;
  <<< "--------------------------------------------" >>>;
}

/* seqman.manipulate();
seqman.reset(); */



// HID objects
Hid hi;
HidMsg msg;


// which joystick
// 2 => int device;
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open joystick 0, exit on fail
if( !hi.openKeyboard( device ) ) me.exit();
// log
<<< "keyboard '" + hi.name() + "' ready", "" >>>;


// keyboard modes
30 => int VOICE_MODE;
31 => int DRONE_MODE;
32 => int SEQ_MODE;
33 => int SEQ_VOICE_MODE;
34 => int SCALE_MODE;

SEQ_MODE => int ACTIVE_MODE;

// keys
45 => int KEY_DASH;
46 => int KEY_EQUAL;
54 => int KEY_COMMA;
55 => int KEY_PERIOD;
79 => int KEY_RIGHT;
80 => int KEY_LEFT;
81 => int KEY_DOWN;
82 => int KEY_UP;
47 => int KEY_LB;
48 => int KEY_RB;
56 => int KEY_SLASH;

29 => int KEY_Z;
22 => int KEY_S;
27 => int KEY_X;
7 => int KEY_D;
6 => int KEY_C;
9 => int KEY_F;
25 => int KEY_V;
10 => int KEY_G;
5 => int KEY_B;
11 => int KEY_H;
24 => int KEY_U;
21 => int KEY_R;
16 => int KEY_M;

40 => int KEY_ENTER;



kb();

// keyboard
fun void kb()
{
    // infinite event loop
    while( true )
    {
        // wait on HidIn as event
        hi => now;

        // messages received
        while( hi.recv( msg ) )
        {
            // button donw
            /* <<< msg.which >>>; */
            if( msg.isButtonDown() )
            {
                // selecting keyboard mode
                if (msg.which >= 30 && msg.which <= 35) {
                  msg.which => ACTIVE_MODE;
                  if (ACTIVE_MODE == SEQ_MODE) {
                    <<< "<<<<<<<<<=======Sequence Mode========>>>>>>>>>>>" >>>;
                    seqman.print_state();
                  } else if (ACTIVE_MODE == DRONE_MODE) {
                    <<< "<<<<<<<<<=======Active Droners========>>>>>>>>>>>" >>>;
                    print_voices(DRONE_TYPE);
                  } else if (ACTIVE_MODE == VOICE_MODE) {
                    <<< "<<<<<<<<<=======Voice Mode========>>>>>>>>>>>" >>>;
                    print_voice_mode();
                  } else if (ACTIVE_MODE == SEQ_VOICE_MODE) {
                    <<< "<<<<<<<<<=======Active Sequencers========>>>>>>>>>>>" >>>;
                    print_voices(SEQ_TYPE);
                  } else if (ACTIVE_MODE == SCALE_MODE) {
                    <<< "<<<<<<<<<=======Select Scale========>>>>>>>>>>>" >>>;
                    print_scales();
                  } else {
                    <<< "huh" >>>;
                    <<< "active", ACTIVE_MODE >>>;
                  }
                  //TODO: add sequencer voice viewer mode.
                  // params: volume, (octave register)
                  continue;
                }

                if (ACTIVE_MODE == SEQ_MODE) {
                  // these are all banked, discrete rehearsal-based changes
                  if( msg.which == KEY_LEFT )
                  {
                    if (seqman.idx > 0) {seqman.idx--;}
                    else if (seqman.idx == 0) { seqman.seq.cap() => seqman.idx; }
                  }
                  else if( msg.which == KEY_RIGHT )
                  {
                    if (seqman.idx < seqman.seq.cap()) {seqman.idx++;}
                    else if (seqman.idx == seqman.seq.cap()) {0 => seqman.idx; }
                  }
                  else if (msg.which == KEY_Z) { seqman.repl_n--; }
                  else if (msg.which == KEY_S) { seqman.repl_n++; }
                  else if (msg.which == KEY_X) { seqman.copy_n--; }
                  else if (msg.which == KEY_D) { seqman.copy_n++; }
                  else if (msg.which == KEY_C) { seqman.sub_n--; }
                  else if (msg.which == KEY_F) { seqman.sub_n++; }
                  else if (msg.which == KEY_V) { seqman.add_n--; }
                  else if (msg.which == KEY_G) { seqman.add_n++; }
                  else if (msg.which == KEY_B) { seqman.extr_n--; }
                  else if (msg.which == KEY_H) { seqman.extr_n++; }
                  else if (msg.which == KEY_R) {
                    if (seqman.should_rev) { 0 => seqman.should_rev; }
                    else { 1 => seqman.should_rev; }
                  }
                  // Apply all changes to new rehearsal
                  if (msg.which == KEY_ENTER) {  // TODO: have enter localized to specific keyboard mode
                    REHEARSAL++;

                    // apply changes from all keyboard modes
                    seqman.manipulate();

                    // reset state
                    seqman.reset();

                    <<< "--------------------------------------------" >>>;
                    <<< "|                                          |" >>>;
                    <<< " |                REHEARSAL", REHEARSAL, "              |" >>>;
                    <<< "|                                          |" >>>;
                    <<< "--------------------------------------------" >>>;
                  }
                  seqman.print_state();
                } else if (ACTIVE_MODE == DRONE_MODE) {
                  if (msg.which == KEY_LEFT) {
                    if (drone_idx > 0) {drone_idx--;}
                    else if (drone_idx == 0) { drone_grans.cap()-1 => drone_idx; }
                  } else if (msg.which == KEY_RIGHT) {
                    if (drone_idx < drone_grans.cap() - 1) {drone_idx++;}
                    else if (drone_idx == drone_grans.cap()-1) {0 => drone_idx;}
                  }

                  drone_grans[drone_idx] @=> Granulator @ g;
                  if (msg.which == KEY_UP) {
                    if (g.MUTED) { continue; }
                    .1 + g.lisa.gain() => drone_grans[drone_idx].lisa.gain;
                  } else if (msg.which == KEY_DOWN) {
                    if (g.MUTED) { continue; }
                    if (g.lisa.gain() < .11){
                      0 => g.lisa.gain;
                    } else {
                      g.lisa.gain() - .1 => g.lisa.gain;
                    }
                  } else if (msg.which == KEY_LB) {
                    1 -=> g.GRAIN_PLAY_RATE_OFF;
                  } else if (msg.which == KEY_RB) {
                    1 +=> g.GRAIN_PLAY_RATE_OFF;
                  } else if (msg.which == KEY_R) { // randomize pitch
                    seqman.scale[Math.random2(0, seqman.scale.cap()-1)] => float sd;
                    while (Std.fabs(sd - g.GRAIN_SCALE_DEG) < .001) {  // gaurantee new note
                      seqman.scale[Math.random2(0, seqman.scale.cap()-1)] => sd;
                    }
                    sd => g.GRAIN_SCALE_DEG;
                  } else if (msg.which == KEY_M) {
                    // mute
                    if (g.MUTED) {
                      spork ~ g.unmute(2::second);  //TODO: spork these?
                    } else {
                      spork ~ g.mute(2::second);
                    }
                  }
                  // TODO: [ / ] to change register
                  // TODO: R to randomize pitch
                  print_voices(DRONE_TYPE);
                } else if (ACTIVE_MODE == SEQ_VOICE_MODE) {
                  // TODO: these will be continuous/real time changes
                  if (msg.which == KEY_LEFT) {
                    if (seq_idx > 0) {seq_idx--;}
                    else if (seq_idx == 0) { seq_grans.cap()-1 => seq_idx; }
                  } else if (msg.which == KEY_RIGHT) {
                    if (seq_idx < seq_grans.cap() - 1) {seq_idx++;}
                    else if (seq_idx == seq_grans.cap()-1) {0 => seq_idx;}
                  }

                  seq_grans[seq_idx] @=> Granulator @ g;
                  if (msg.which == KEY_UP) {
                    if (g.MUTED) { continue; }
                    .1 + g.lisa.gain() => g.lisa.gain;
                  } else if (msg.which == KEY_DOWN) {
                    if (g.MUTED) { 0 => g.lisa.gain; continue; }
                    if (g.lisa.gain() < .11){
                      0 => g.lisa.gain;
                    } else {
                      g.lisa.gain() - .1 => g.lisa.gain;
                    }
                  } else if (msg.which == KEY_LB) {
                    1 -=> g.GRAIN_PLAY_RATE_OFF;
                  } else if (msg.which == KEY_RB) {
                    1 +=> g.GRAIN_PLAY_RATE_OFF;
                  } else if (msg.which == KEY_COMMA) {
                    if (g.seq_off_idx > 0) {g.seq_off_idx--;}
                    g.SEQ_OFFSETS[g.seq_off_idx] => g.GRAIN_SCALE_DEG;
                  } else if (msg.which == KEY_PERIOD) {
                    if (g.seq_off_idx < g.SEQ_OFFSETS.cap()-1) {g.seq_off_idx++;}
                    g.SEQ_OFFSETS[g.seq_off_idx] => g.GRAIN_SCALE_DEG;
                  } else if (msg.which == KEY_M) {
                    // mute
                    if (g.MUTED) {
                      spork ~ g.unmute(2::second);
                    } else {
                      spork ~ g.mute(2::second);
                    }
                  }
                  print_voices(SEQ_TYPE);
                } else if (ACTIVE_MODE == VOICE_MODE) {
                    if (msg.which == KEY_Z) {
                      if (voice_type == SEQ_TYPE) {
                        DRONE_TYPE => voice_type;
                      } else {
                        SEQ_TYPE => voice_type;
                      }
                    } else if (msg.which == KEY_X || msg.which == KEY_DOWN) {
                      if (voice_bank_idx == 0) {
                        drone_paths.cap()-1 => voice_bank_idx;
                      } else {
                        voice_bank_idx--;
                      }
                    } else if (msg.which == KEY_D || msg.which == KEY_UP) {
                      if (voice_bank_idx == drone_paths.cap()-1) {
                        0 => voice_bank_idx;
                      } else { voice_bank_idx++; }
                    } else if (msg.which == KEY_C || msg.which == KEY_LB) { voice_off--; }
                    else if (msg.which == KEY_F || msg.which == KEY_RB) { voice_off++; }
                    else if (msg.which == KEY_V) {
                      if (voice_deg_idx > 0) {
                        voice_deg_idx--;
                      }
                    } else if (msg.which == KEY_G) {
                      if (voice_deg_idx < seqman.scale.cap()-1) {
                        voice_deg_idx++;
                      }
                    } else if (msg.which == KEY_B) {
                      if (voice_gain < .21){
                        0 => voice_gain;
                      } else {
                        .2 -=> voice_gain;
                      }
                    } else if (msg.which == KEY_H) {
                      .2 +=> voice_gain;
                    }

                    if (msg.which == KEY_ENTER) { add_voice(); }
                    print_voice_mode();
                  } else if (ACTIVE_MODE == SCALE_MODE) {
                    if (msg.which == KEY_UP) {
                      if (scale_idx == SCALES.cap()-1) {
                        0 => scale_idx;
                      } else {
                        scale_idx++;
                      }
                    } else if (msg.which == KEY_DOWN) {
                      if (scale_idx == 0) {
                        SCALES.cap() - 1 => scale_idx;
                      } else {
                        scale_idx--;
                      }
                    }
                    if (msg.which == KEY_ENTER) {
                      equip_scale(scale_idx);
                    }
                    print_scales();
                  }

              }
          }
      }
  }
