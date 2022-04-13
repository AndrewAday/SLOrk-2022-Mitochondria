/*
// keyboard control (also see kb() below):
//       <-- z axis --> = grain position
//       <--- y axis ---> = grain rate / tuning
//       <---x axis---> = grain size
*/

// gametrack
GameTrack gt;
gt.init(0);

// signal flow
Gain main_gain => dac;
Gain l_field_gain; Gain l_voice_gain;
Gain r_field_gain; Gain r_voice_gain;

Chorus chorus => NRev rev => main_gain;
// rev settings
.3 => rev.mix;

// chorus settings
.75 => chorus.mix;
.2 => chorus.modFreq;
.08 => chorus.modDepth;

l_field_gain => main_gain;
r_field_gain => main_gain;

l_voice_gain => chorus;
r_voice_gain => chorus;



.0 => l_field_gain.gain; .0 => l_voice_gain.gain;
.0 => r_field_gain.gain; .0 => r_voice_gain.gain;

// left joystick
create_granulator("./Samples/Field/thunder.wav", "field", l_field_gain) @=> Granulator l_granulator;
create_granulator("./Samples/Drones/male-choir.wav", "drone", l_voice_gain) @=> Granulator l_voice;

// right joystick
create_granulator("./Samples/Field/beach-with-people.wav", "field", r_field_gain) @=> Granulator r_granulator;
create_granulator("./Samples/Drones/female-choir.wav", "drone", r_voice_gain) @=> Granulator r_voice;

// granulator config
10::ms => r_voice.GRAIN_LENGTH;
3/2.0 => r_voice.GRAIN_SCALE_DEG;
10::ms => l_voice.GRAIN_LENGTH;
1.0 => l_voice.GRAIN_SCALE_DEG;

10::ms => l_granulator.GRAIN_LENGTH;
10::ms => r_granulator.GRAIN_LENGTH;


fun Granulator create_granulator(string filepath, string type, UGen @ out) {
  Granulator drone;
  drone.init(filepath, out);

//   gain => drone.lisa.gain;
//   off => drone.GRAIN_PLAY_RATE_OFF;
//   deg => drone.GRAIN_SCALE_DEG;

  // spork ~ drone.cycle_pos();
  spork ~ drone.granulate();

  return drone;
}


/*========== Gametrack granulation control fns ========*/
.025 => float GT_Z_DEADZONE;
1.0 => float GT_Z_COMPRESSION;
fun float get_grain_pos(float z) {  // maps z to [0,1]
  return z;
  // ( z - GT_Z_DEADZONE ) * GT_Z_COMPRESSION + Math.random2f(0,.0001) => float pos;
}

fun dur get_field_grain_size(float x) {
  return Util.remap(-1., 1., 5, 15, x)::ms; 
}

fun dur get_voice_grain_size(float z) {
  return Util.remap(0, .5, 10, 500, z)::ms;
}

fun float get_grain_rate(float y) {
  return Util.remap(-1., 1., .01, 2.0, y);
}

fun float get_grain_gain(float z) {
  return Util.clamp01(Util.remap(0, .5, 1, 0, z));
}

// controls granular synthesis mapping to gametrak, + cross fade to voice
.025 => float Z_DEADZONE_CUTOFF;
.35 => float Z_BEGIN_VOICE;
fun void field_voice_crossfader( 
  int x, int y, int z, 
  Granulator @ granulator, Gain @ field_gain,
  Granulator @ voice, Gain @ voice_gain
) {
  while (true) {
    // update granulator positions
    get_grain_pos(gt.curAxis[z]) => granulator.GRAIN_POSITION;
    get_grain_rate(gt.curAxis[y]) => granulator.GRAIN_PLAY_RATE;
    get_field_grain_size(gt.curAxis[x]) => granulator.GRAIN_LENGTH;


    // lerp gain between field recording and voice
    // z axis silent deadzone
    if (gt.curAxis[z] < Z_DEADZONE_CUTOFF) {
      0 => voice_gain.gain;
      Util.clamp01(Util.remap(.0, Z_DEADZONE_CUTOFF, 0, 1, gt.curAxis[z])) => field_gain.gain;
    } else if (gt.curAxis[z] >= Z_DEADZONE_CUTOFF && gt.curAxis[z] < Z_BEGIN_VOICE) {
      // hold field sample at gain = 1, voice at gain = 0
    } else { 
      // at z = 0, r_field_gain = 1, r_voice_gain = 0
      // at z = .5, r_field_gain = 0, r_voice_gain = 1
      Util.clamp01(Util.remap(Z_BEGIN_VOICE, .5, 1, 0, gt.curAxis[z])) => field_gain.gain;
      (1 - field_gain.gain()) * 3.0 => voice_gain.gain;
    }
    
    // lerp voice grain length from 10::ms --> 500::ms
    get_voice_grain_size(gt.curAxis[z]) => voice.GRAIN_LENGTH;
    
    // gt.print();
    10::ms => now;
  }
}

// right joy controls
spork ~ field_voice_crossfader(gt.RX, gt.RY, gt.RZ, r_granulator, r_field_gain, r_voice, r_voice_gain);
// left joy controls
spork ~ field_voice_crossfader(gt.LX, gt.LY, gt.LZ, l_granulator, l_field_gain, l_voice, l_voice_gain);

while (true) {
  10::ms => now;
}