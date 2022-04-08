public class TaikoDrummer {

  // helper class for structuring playback data
  class DrumHit {
      int sample_idx;
      int num_beats;
  }

  fun dur bpm_to_qt_note(float bpm) {
    return (60. / (bpm))::second;
  }

  fun void load_and_patch_taiko_samps(LiSa lisas[], string prefix, UGen @ out) {
    for (int i; i < lisas.cap(); i++) {
        SndBuf buffy;
        me.dir() + "Samples/Taiko/" + prefix + i + ".wav" => buffy.read;

        this.load_lisa(buffy) @=> lisas[i];
        lisas[i].chan(0) => PoleZero p => out;
        .99 => p.blockZero;

    }
  }

  fun LiSa load_lisa(SndBuf @ sndbuf) {
    LiSa lisa;
    sndbuf.samples()::samp => lisa.duration;
    for (0 => int i; i < sndbuf.samples(); i++) {
      lisa.valueAt(sndbuf.valueAt(i  * sndbuf.channels()), i::samp );
    }
    lisa.play(false);
    lisa.loop(false);
    lisa.maxVoices(25);

    return lisa;
  }

  /*
  Generates a drum pattern in the format:
  [ (stored in assoc part of array)
      "0": [sample#, num_beats],
      "1": [sample#, num_beats],
      ...
  ]
  */
  fun int[][] generate_drum_pattern(
        int num_beats,
        int num_samples,  // number of samples are there to choose from
        float prob_sample_switch, // probably to switch sample between beats
        float prob_double_time // probability of double time
  ) {
      int pattern[1][1];
      int assoc_idx;
      Math.random2(0, num_samples - 1) => int sample_num;
      for (int beat_num; beat_num < num_beats; beat_num++) {
          // switch sample?
          if (num_samples > 1 && Math.randomf() < prob_sample_switch) {
              Math.random2(0, num_samples - 1) => sample_num;
          }
          if (Math.randomf() < prob_double_time) {
              // add a double time pattern
              [sample_num, 1] @=> pattern["" + assoc_idx++];
              [sample_num, 1] @=> pattern["" + assoc_idx++];
          } else {
              // single time pattern
              [sample_num, 2] @=> pattern["" + assoc_idx++];
          }
      }

      assoc_idx => pattern[0][0];  // store how long the pattern is
      return pattern;
  }
  
  // using sndbuf
  fun void play_drum_pattern(
        SndBuf samples[],
        int pattern[][],
        dur beat_dur, // length of fastest pulse
        int num_repeats
  ) {
      pattern[0][0] => int num_hits;
      repeat (num_repeats) {
        for (int i; i < num_hits; i++) {
            pattern["" + i] @=> int drum_hit[];
            drum_hit[0] => int sample_idx;
            drum_hit[1] => int num_beats;

            0 => samples[sample_idx].pos;
            1 => samples[sample_idx].rate;

            num_beats::beat_dur => now;
      }
    }
  }
  // using lisa
  fun void play_drum_pattern(
        LiSa samples[],
        int pattern[][],
        dur beat_dur, // length of fastest pulse
        int num_repeats
  ) {
    pattern[0][0] => int num_hits;
    repeat (num_repeats) {
      for (int i; i < num_hits; i++) {
          pattern["" + i] @=> int drum_hit[];
          drum_hit[0] => int sample_idx;
          drum_hit[1] => int num_beats;

          this.play_oneshot(samples[sample_idx]);

          num_beats::beat_dur => now;
      }
    }
  }

  // plays heart beat pattern .25d -> .75d a total of {n} times
  fun void play_heartbeat_pattern(dur d, SndBuf @ heart0, SndBuf @ heart1, int n) {
    repeat (n) {
      0 => heart0.pos;
      1 => heart0.rate;
      .25 * d => now;
      0 => heart1.pos;
      1 => heart1.rate;
      .75 * d => now;
    }
  }

  fun void play_heartbeat_pattern(dur d, LiSa @ heart0, LiSa @ heart1, int n) {
    repeat (n) {
      this.play_oneshot(heart0);
      .25*d => now;
      this.play_oneshot(heart1);
      .75*d => now;

    }
  }

  fun void play_oneshot(LiSa @ lisa) {
    lisa.getVoice() => int voice;
    if (voice < 0)
      return;

    lisa.loop(voice, false);
    lisa.playPos(voice, 0::ms);
    lisa.play(voice, true);
    // <<< voice >>>;
    /* lisa.rampUp(voice, 1::ms); */
  }

  fun void restart_sndbuf(SndBuf @ s) {
    0 => s.pos;
    1 => s.rate;
  }

  fun void play_oneshot(SndBuf @ s) {
    restart_sndbuf(s);
  }

  fun void test(dur d, SndBuf h, int n) {
    return;
  }
}

/* Unit Test */
TaikoDrummer td;
JCRev rev => Gain drummerGain => dac;
.05 => rev.mix;
.5 => drummerGain.gain;

LiSa A[9];
LiSa B[4];

td.load_and_patch_taiko_samps(A, "A", rev);
td.load_and_patch_taiko_samps(B, "B", rev);

// <<< "heartbeat" >>>;
// td.play_heartbeat_pattern(1::second, A[0], 4);

6 => int BEATS_PER_CYCLE;
td.bpm_to_qt_note(86) => dur qt_note;
2 => int REPEATS_PER_CYCLE;

<<< "generative pattern" >>>;
repeat (10) {

spork ~ td.play_drum_pattern(
  A,
  td.generate_drum_pattern(
    BEATS_PER_CYCLE, // num beats
    A.size(), // num of samples in bank
    .25, // probability of sample switch
    .5 // probability of double time
  ),
  .5 * qt_note,  // shortest hit duration
  REPEATS_PER_CYCLE // num repeats
);

spork ~ td.play_drum_pattern(
  B,
  td.generate_drum_pattern(
    (1.5 * BEATS_PER_CYCLE) $ int,  // for triplet rhythm
    B.size(), // num of samples in bank
    .25, // probability of sample switch
    .5 // probability of double time
  ),
  (1.0/3.0) * qt_note,  // shortest hit duration
  REPEATS_PER_CYCLE // num repeats
);

BEATS_PER_CYCLE * qt_note * REPEATS_PER_CYCLE => now;
}